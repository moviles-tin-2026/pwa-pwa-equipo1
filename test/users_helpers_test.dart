// Pruebas de las reglas de contraseña del alta de usuarios.
//
// El alta crea la cuenta en Firebase Auth, así que la contraseña se valida
// antes de llamar al servidor: si no cumpliera, Firebase respondería con un
// `weak-password` genérico en vez de decir qué falta. Y la contraseña que
// genera el formulario tiene que cumplir siempre esas mismas reglas.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/screens/users/users_helpers.dart';

void main() {
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
