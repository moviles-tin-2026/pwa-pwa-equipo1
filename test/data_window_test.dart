// Pruebas de la ventana de datos que sincroniza el repositorio.
//
// Ventas y movimientos se traen acotados por fecha, no por número de
// documentos: con `limit(300)` el dashboard reportaba de menos en cuanto
// el negocio crecía, y sin avisar. Lo que estas pruebas fijan es que la
// ventana cubra de verdad lo que las métricas prometen —el mes en curso y
// el gráfico de 6 meses— y que las métricas ignoren las canceladas.

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';
import 'package:login_app/services/inventory_repository.dart';

import 'fake_repository.dart';

void main() {
  group('ventana de datos', () {
    test('la de ventas cubre el gráfico de 6 meses y el mes en curso', () {
      final repo = FakeRepository();
      final now = DateTime.now();

      // El gráfico dibuja 6 meses hacia atrás; el más viejo debe caer
      // dentro de la ventana o el dashboard mostraría barras incompletas.
      final oldestChartMonth = DateTime(now.year, now.month - 5);
      expect(
        repo.salesWindowStart.isAfter(oldestChartMonth),
        isFalse,
        reason: 'la ventana empieza después del mes más viejo del gráfico',
      );

      // Y arranca en el día 1 de su mes: si empezara a media semana, el
      // total de ese mes saldría recortado.
      expect(repo.salesWindowStart.day, 1);
    });

    test('la de movimientos cubre el filtro más amplio del módulo', () {
      final repo = FakeRepository();
      final now = DateTime.now();
      final last30 = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 29));

      expect(repo.movementsWindowStart.isAfter(last30), isFalse);
      expect(InventoryRepository.movementsWindowDays, greaterThanOrEqualTo(30));
    });

    test('la ventana no se mueve entre consultas', () {
      final repo = FakeRepository();
      expect(repo.salesWindowStart, repo.salesWindowStart);
      expect(repo.movementsWindowStart, repo.movementsWindowStart);
    });
  });

  group('métricas sobre la ventana', () {
    test('el total del mes suma solo ventas activas del mes en curso', () {
      final now = DateTime.now();
      final repo = FakeRepository()
        ..seedSales([
          _sale('v1', DateTime(now.year, now.month, 1), 100),
          _sale('v2', DateTime(now.year, now.month, 2), 250),
          _sale('v3', DateTime(now.year, now.month, 3), 999, cancelled: true),
          // Mes anterior: fuera del total del mes.
          _sale('v4', DateTime(now.year, now.month - 1, 15), 500),
        ]);

      expect(repo.monthSalesTotal, 350);
    });

    test('el top de productos ignora las ventas canceladas', () {
      final now = DateTime.now();
      final repo = FakeRepository()
        ..seedSales([
          _sale('v1', now, 100, productId: 'p1', productName: 'Serum'),
          _sale('v2', now, 100, productId: 'p2', productName: 'Bloqueador'),
          _sale('v3', now, 100,
              productId: 'p2', productName: 'Bloqueador', cancelled: true),
        ]);

      final top = repo.topSellingProducts();
      expect(top.first.name, 'Serum');
      expect(top.firstWhere((t) => t.name == 'Bloqueador').units, 1);
    });
  });
}

Sale _sale(
  String id,
  DateTime date,
  double amount, {
  bool cancelled = false,
  String productId = 'p1',
  String productName = 'Producto',
}) =>
    Sale(
      id: id,
      folio: id,
      items: [
        SaleItem(
          productId: productId,
          productName: productName,
          unitPrice: amount,
          quantity: 1,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      userName: 'Cajero',
      date: date,
      cancelled: cancelled,
    );
