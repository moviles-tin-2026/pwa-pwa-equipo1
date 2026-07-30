// Pruebas de AuthService alrededor de la inicialización diferida de
// Firebase.
//
// `main` arranca `Firebase.initializeApp` sin esperarlo para no retrasar el
// primer frame, y le pasa el `Future` a AuthService. Estas pruebas cubren
// que ese contrato se respete: que las operaciones esperen a que Firebase
// esté listo, y que un fallo de arranque llegue a la UI como un mensaje
// legible en vez de un error crudo.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/services/auth_service.dart';

void main() {
  test('un fallo al inicializar Firebase llega como AuthException', () async {
    final failed = Completer<void>()..completeError(StateError('sin red'));
    final auth = AuthService(ready: failed.future);

    await expectLater(
      auth.signIn('admin@aura.com', 'secreto'),
      throwsA(isA<AuthException>()),
    );
  });

  test('signIn no avanza mientras Firebase siga inicializando', () async {
    final pending = Completer<void>();
    final auth = AuthService(ready: pending.future);

    var settled = false;
    unawaited(auth.signIn('admin@aura.com', 'secreto').then(
          (_) => settled = true,
          onError: (_) => settled = true,
        ));

    // Sin resolver `pending`, signIn debe seguir esperando: si no esperara,
    // ya habría tocado FirebaseAuth.instance y fallado.
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);
  });

  test('sendPasswordReset también espera a que Firebase esté listo',
      () async {
    final failed = Completer<void>()..completeError(StateError('sin red'));
    final auth = AuthService(ready: failed.future);

    await expectLater(
      auth.sendPasswordReset('admin@aura.com'),
      throwsA(isA<AuthException>()),
    );
  });
}
