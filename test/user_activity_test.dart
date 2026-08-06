// Pruebas del historial de actividad del detalle de usuario.
//
// La pantalla mostraba seis entradas fabricadas con `List.generate`
// ("Inició sesión", "Cambio de rol"…) que parecían auditoría real. Lo que
// estas pruebas fijan es que cada entrada salga de una venta o un
// movimiento que existe de verdad, y que no se invente ninguna.

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';
import 'package:login_app/screens/users/users_helpers.dart';

void main() {
  group('historial de actividad del usuario', () {
    test('sin ventas ni movimientos propios el historial queda vacío', () {
      final history = userActivityHistory(
        sales: [_sale('V-0001', 'Otra cajera', DateTime(2026, 8, 1))],
        movements: [_movement('Otra cajera', DateTime(2026, 8, 1))],
        userName: 'Ana',
      );

      expect(history, isEmpty);
    });

    test('solo aparece lo registrado a nombre del usuario', () {
      final history = userActivityHistory(
        sales: [
          _sale('V-0001', 'Ana', DateTime(2026, 8, 1)),
          _sale('V-0002', 'Beto', DateTime(2026, 8, 2)),
        ],
        movements: [
          _movement('Ana', DateTime(2026, 8, 3), reason: 'Ajuste de conteo'),
          _movement('Beto', DateTime(2026, 8, 4), reason: 'Merma'),
        ],
        userName: 'Ana',
      );

      expect(history.length, 2);
      expect(history.every((e) => !e.label.contains('V-0002')), isTrue);
      expect(history.any((e) => e.label.contains('V-0001')), isTrue);
      expect(history.any((e) => e.label.contains('Ajuste de conteo')), isTrue);
    });

    test('la venta no se repite una vez por cada línea de movimiento', () {
      // checkoutSale escribe un movimiento de salida por producto: si se
      // listaran, una venta de tres artículos saldría cuatro veces.
      final history = userActivityHistory(
        sales: [_sale('V-0007', 'Ana', DateTime(2026, 8, 5))],
        movements: [
          _movement('Ana', DateTime(2026, 8, 5), reason: 'Venta: V-0007'),
          _movement('Ana', DateTime(2026, 8, 5), reason: 'Venta: V-0007'),
        ],
        userName: 'Ana',
      );

      expect(history.length, 1);
      expect(history.single.label, contains('V-0007'));
    });

    test('lo más reciente va primero y el límite recorta la cola', () {
      final history = userActivityHistory(
        sales: [
          for (var day = 1; day <= 5; day++)
            _sale('V-000$day', 'Ana', DateTime(2026, 8, day)),
        ],
        movements: const [],
        userName: 'Ana',
        limit: 3,
      );

      expect(history.length, 3);
      expect(history.first.label, contains('V-0005'));
      expect(history.last.label, contains('V-0003'));
    });

    test('una venta cancelada se marca como tal y no como venta normal', () {
      final history = userActivityHistory(
        sales: [
          _sale('V-0009', 'Ana', DateTime(2026, 8, 6), cancelled: true),
        ],
        movements: const [],
        userName: 'Ana',
      );

      expect(history.single.label, 'Venta V-0009 cancelada');
      expect(history.single.isNegative, isTrue);
    });
  });
}

Sale _sale(
  String folio,
  String userName,
  DateTime date, {
  bool cancelled = false,
}) =>
    Sale(
      id: folio,
      folio: folio,
      items: const [
        SaleItem(
          productId: 'p1',
          productName: 'Serum',
          unitPrice: 100,
          quantity: 1,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      userName: userName,
      date: date,
      cancelled: cancelled,
    );

StockMovement _movement(
  String userName,
  DateTime date, {
  String reason = 'Ajuste',
  MovementType type = MovementType.exit,
}) =>
    StockMovement(
      id: '$userName-${date.millisecondsSinceEpoch}-$reason',
      productId: 'p1',
      productName: 'Serum',
      type: type,
      quantity: 2,
      reason: reason,
      userName: userName,
      date: date,
    );
