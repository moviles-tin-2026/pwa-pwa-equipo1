// Pruebas de las reglas de contraseña del alta de usuarios.
//
// El alta crea la cuenta en Firebase Auth, así que la contraseña se valida
// antes de llamar al servidor: si no cumpliera, Firebase respondería con un
// `weak-password` genérico en vez de decir qué falta. Y la contraseña que
// genera el formulario tiene que cumplir siempre esas mismas reglas.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';
import 'package:login_app/screens/users/users_helpers.dart';

Sale _sale(
  String id,
  DateTime date, {
  required String userName,
  double amount = 100,
  bool cancelled = false,
}) =>
    Sale(
      id: id,
      folio: id,
      items: [
        SaleItem(
          productId: 'p1',
          productName: 'Producto',
          unitPrice: amount,
          quantity: 1,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      userName: userName,
      date: date,
      cancelled: cancelled,
    );

StockMovement _movement(
  String id,
  DateTime date, {
  required String userName,
  MovementType type = MovementType.entry,
  String reason = 'Ajuste manual',
}) =>
    StockMovement(
      id: id,
      productId: 'p1',
      productName: 'Producto',
      type: type,
      quantity: 1,
      reason: reason,
      userName: userName,
      date: date,
    );

UserSession _session(
  String id, {
  required String userName,
  required DateTime startedAt,
  DateTime? lastSeenAt,
  DateTime? endedAt,
}) =>
    UserSession(
      id: id,
      userId: 'uid-$userName',
      userName: userName,
      startedAt: startedAt,
      lastSeenAt: lastSeenAt ?? startedAt,
      endedAt: endedAt,
    );

void main() {
  group('lastActivityAt', () {
    test('toma la fecha más reciente entre ventas y movimientos', () {
      final sales = [
        _sale('v1', DateTime(2026, 3, 1), userName: 'Ana'),
        _sale('v2', DateTime(2026, 3, 5), userName: 'Ana'),
      ];
      final movements = [
        _movement('m1', DateTime(2026, 3, 3), userName: 'Ana'),
      ];
      expect(
        lastActivityAt(sales: sales, movements: movements, userName: 'Ana'),
        DateTime(2026, 3, 5),
      );
    });

    test('ignora actividad de otros usuarios', () {
      final sales = [_sale('v1', DateTime(2026, 3, 5), userName: 'Beto')];
      expect(
        lastActivityAt(sales: sales, movements: const [], userName: 'Ana'),
        isNull,
      );
    });

    test('sin ventas ni movimientos da null', () {
      expect(
        lastActivityAt(sales: const [], movements: const [], userName: 'Ana'),
        isNull,
      );
    });
  });

  group('activityStatusFor', () {
    final now = DateTime(2026, 3, 10);

    test('sin actividad nunca es stale', () {
      expect(activityStatusFor(null, now: now), ActivityStatus.stale);
    });

    test('hoy mismo es today', () {
      expect(
        activityStatusFor(DateTime(2026, 3, 10, 8), now: now),
        ActivityStatus.today,
      );
    });

    test('hasta 7 días atrás es thisWeek', () {
      expect(
        activityStatusFor(DateTime(2026, 3, 3), now: now),
        ActivityStatus.thisWeek,
      );
    });

    test('de 8 a 30 días atrás es thisMonth', () {
      expect(
        activityStatusFor(DateTime(2026, 3, 2), now: now),
        ActivityStatus.thisMonth,
      );
      expect(
        activityStatusFor(DateTime(2026, 2, 8), now: now),
        ActivityStatus.thisMonth,
      );
    });

    test('más de 30 días atrás es stale', () {
      expect(
        activityStatusFor(DateTime(2026, 2, 7), now: now),
        ActivityStatus.stale,
      );
    });
  });

  group('userPerformance', () {
    test('sin ventas nunca, cancellationRate es null', () {
      final perf = userPerformance(
        sales: const [],
        movements: const [],
        userName: 'Ana',
      );
      expect(perf.saleCount, 0);
      expect(perf.cancelledCount, 0);
      expect(perf.cancellationRate, isNull);
    });

    test('calcula la tasa de cancelaciones sobre el total de ventas', () {
      final sales = [
        _sale('v1', DateTime(2026, 3, 1), userName: 'Ana'),
        _sale('v2', DateTime(2026, 3, 2), userName: 'Ana', cancelled: true),
        _sale('v3', DateTime(2026, 3, 3), userName: 'Ana', cancelled: true),
        _sale('v4', DateTime(2026, 3, 4), userName: 'Ana'),
        _sale('v5', DateTime(2026, 3, 5), userName: 'Beto', cancelled: true),
      ];
      final perf = userPerformance(
        sales: sales,
        movements: const [],
        userName: 'Ana',
      );
      expect(perf.saleCount, 2);
      expect(perf.cancelledCount, 2);
      expect(perf.cancellationRate, 0.5);
    });

    test('no cuenta movimientos generados por ventas o cancelaciones', () {
      final movements = [
        _movement(
          'm1',
          DateTime(2026, 3, 1),
          userName: 'Ana',
          reason: 'Venta: V-0001',
        ),
        _movement(
          'm2',
          DateTime(2026, 3, 2),
          userName: 'Ana',
          reason: 'Devolución por cancelación: V-0001',
        ),
        _movement(
          'm3',
          DateTime(2026, 3, 3),
          userName: 'Ana',
          reason: 'Conteo físico',
        ),
      ];
      final perf = userPerformance(
        sales: const [],
        movements: movements,
        userName: 'Ana',
      );
      expect(perf.movementCount, 1);
    });
  });

  group('connectedHours', () {
    test('suma la duración de las sesiones del usuario', () {
      final sessions = [
        _session(
          's1',
          userName: 'Ana',
          startedAt: DateTime(2026, 3, 1, 9),
          endedAt: DateTime(2026, 3, 1, 11),
        ),
        _session(
          's2',
          userName: 'Ana',
          startedAt: DateTime(2026, 3, 2, 9),
          endedAt: DateTime(2026, 3, 2, 9, 30),
        ),
        _session(
          's3',
          userName: 'Beto',
          startedAt: DateTime(2026, 3, 1, 9),
          endedAt: DateTime(2026, 3, 1, 20),
        ),
      ];
      expect(
        connectedHours(sessions: sessions, userName: 'Ana'),
        closeTo(2.5, 0.001),
      );
    });

    test('una sesión sin endedAt cuenta hasta el último heartbeat, no hasta '
        'ahora', () {
      final sessions = [
        _session(
          's1',
          userName: 'Ana',
          startedAt: DateTime(2026, 3, 1, 9),
          lastSeenAt: DateTime(2026, 3, 1, 9, 12),
        ),
      ];
      expect(
        connectedHours(sessions: sessions, userName: 'Ana'),
        closeTo(0.2, 0.001),
      );
    });

    test('ignora sesiones que empezaron antes de "since"', () {
      final sessions = [
        _session(
          's1',
          userName: 'Ana',
          startedAt: DateTime(2026, 3, 1, 9),
          endedAt: DateTime(2026, 3, 1, 10),
        ),
        _session(
          's2',
          userName: 'Ana',
          startedAt: DateTime(2026, 3, 10, 9),
          endedAt: DateTime(2026, 3, 10, 10),
        ),
      ];
      expect(
        connectedHours(
          sessions: sessions,
          userName: 'Ana',
          since: DateTime(2026, 3, 5),
        ),
        1.0,
      );
    });
  });

  group('monthlySalesGoalProgress', () {
    test('meta en 0 da ratio null (sin meta definida)', () {
      final result = monthlySalesGoalProgress(
        sales: const [],
        userName: 'Ana',
        goal: 0,
      );
      expect(result.ratio, isNull);
    });

    test('suma solo ventas activas de Ana en el mes en curso', () {
      final now = DateTime(2026, 3, 15);
      final sales = [
        _sale('v1', DateTime(2026, 3, 1), userName: 'Ana', amount: 100),
        _sale(
          'v2',
          DateTime(2026, 3, 10),
          userName: 'Ana',
          amount: 200,
          cancelled: true,
        ),
        _sale('v3', DateTime(2026, 2, 20), userName: 'Ana', amount: 500),
        _sale('v4', DateTime(2026, 3, 12), userName: 'Beto', amount: 300),
      ];
      final result = monthlySalesGoalProgress(
        sales: sales,
        userName: 'Ana',
        goal: 200,
        now: now,
      );
      expect(result.revenue, 100);
      expect(result.ratio, 0.5);
    });
  });

  group('validateNewPassword', () {
    test('acepta una contraseña que cumple todos los requisitos', () {
      expect(validateNewPassword('AuraVita2026!'), isNull);
    });

    test('rechaza vacía, corta o demasiado larga', () {
      expect(validateNewPassword(''), 'Ingresa una contraseña');
      expect(validateNewPassword(null), 'Ingresa una contraseña');
      expect(validateNewPassword('Aa1!'), contains('al menos'));
      expect(
        validateNewPassword('Aa1!${'x' * kPasswordMaxLength}'),
        contains('No debe exceder'),
      );
    });

    test('rechaza espacios en blanco', () {
      expect(validateNewPassword('Aura Vita2026!'), contains('espacios'));
    });

    test('exige mayúscula, minúscula, número y carácter especial', () {
      expect(validateNewPassword('auravita2026!'), 'Falta una mayúscula');
      expect(validateNewPassword('AURAVITA2026!'), 'Falta una minúscula');
      expect(validateNewPassword('AuraVitaeSkin!'), 'Falta un número');
      expect(
        validateNewPassword('AuraVitae2026'),
        contains('carácter especial'),
      );
    });
  });

  group('validatePasswordConfirmation', () {
    test('acepta cuando coincide', () {
      expect(
        validatePasswordConfirmation('AuraVita2026!', 'AuraVita2026!'),
        isNull,
      );
    });

    test('rechaza vacía o distinta', () {
      expect(
        validatePasswordConfirmation('', 'AuraVita2026!'),
        'Repite la contraseña nueva',
      );
      expect(
        validatePasswordConfirmation(null, 'AuraVita2026!'),
        'Repite la contraseña nueva',
      );
      expect(
        validatePasswordConfirmation('AuraVita2026', 'AuraVita2026!'),
        'Las contraseñas no coinciden',
      );
    });
  });

  group('generateTemporaryPassword', () {
    test('lo que genera siempre pasa la validación', () {
      // Semillas fijas: la prueba no debe depender del azar de un día.
      for (var seed = 0; seed < 200; seed++) {
        final password = generateTemporaryPassword(random: Random(seed));
        expect(
          validateNewPassword(password),
          isNull,
          reason: 'semilla $seed generó "$password"',
        );
      }
    });

    test('no repite la misma contraseña entre altas', () {
      final generated = {
        for (var i = 0; i < 50; i++) generateTemporaryPassword(),
      };
      expect(generated.length, greaterThan(45));
    });
  });
}
