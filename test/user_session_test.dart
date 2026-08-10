// Pruebas del modelo UserSession alrededor de "horas de conexión".
//
// Importan porque una pestaña cerrada sin `signOut()` nunca llena
// `endedAt`: si `duration` no cubriera ese caso con el último heartbeat
// (`lastSeenAt`), una sesión abandonada contaría como "conectado" para
// siempre y el medidor de horas quedaría inflado sin límite.

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';

void main() {
  group('UserSession', () {
    test('toMap/fromMap conserva los campos', () {
      final original = UserSession(
        id: 'session-1',
        userId: 'uid-1',
        userName: 'Ana',
        startedAt: DateTime(2026, 3, 10, 9),
        lastSeenAt: DateTime(2026, 3, 10, 9, 30),
        endedAt: DateTime(2026, 3, 10, 10),
      );

      final restored = UserSession.fromMap(original.id, original.toMap());

      expect(restored.userId, 'uid-1');
      expect(restored.userName, 'Ana');
      expect(restored.startedAt, DateTime(2026, 3, 10, 9));
      expect(restored.lastSeenAt, DateTime(2026, 3, 10, 9, 30));
      expect(restored.endedAt, DateTime(2026, 3, 10, 10));
    });

    test('endedAt ausente se lee como sesión abierta', () {
      final session = UserSession.fromMap('session-2', {
        'userId': 'uid-1',
        'userName': 'Ana',
        'startedAt': DateTime(2026, 3, 10, 9).millisecondsSinceEpoch,
        'lastSeenAt': DateTime(2026, 3, 10, 9, 45).millisecondsSinceEpoch,
        'endedAt': null,
      });

      expect(session.endedAt, isNull);
    });

    test('lastSeenAt ausente (documento viejo) cae en startedAt', () {
      final session = UserSession.fromMap('session-3', {
        'userId': 'uid-1',
        'userName': 'Ana',
        'startedAt': DateTime(2026, 3, 10, 9).millisecondsSinceEpoch,
      });

      expect(session.lastSeenAt, DateTime(2026, 3, 10, 9));
    });

    test('effectiveEnd usa endedAt cuando cerró sesión limpio', () {
      final session = UserSession(
        id: 's',
        userId: 'uid-1',
        userName: 'Ana',
        startedAt: DateTime(2026, 3, 10, 9),
        lastSeenAt: DateTime(2026, 3, 10, 9, 50),
        endedAt: DateTime(2026, 3, 10, 10),
      );

      expect(session.effectiveEnd, DateTime(2026, 3, 10, 10));
      expect(session.duration, const Duration(hours: 1));
    });

    test(
      'effectiveEnd cae en el último heartbeat si nunca cerró sesión',
      () {
        final session = UserSession(
          id: 's',
          userId: 'uid-1',
          userName: 'Ana',
          startedAt: DateTime(2026, 3, 10, 9),
          lastSeenAt: DateTime(2026, 3, 10, 9, 12),
        );

        expect(session.effectiveEnd, DateTime(2026, 3, 10, 9, 12));
        expect(session.duration, const Duration(minutes: 12));
      },
    );
  });
}
