// Pruebas del modelo AppUser alrededor de los campos de perfil que se
// editan desde Configuración.
//
// Importan porque los documentos de `users` creados antes de esta pantalla
// no tienen `recoveryEmail` ni `startSection`: leerlos no debe romper el
// inicio de sesión, y guardar el perfil no debe pisar el rol ni el estado.

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';

void main() {
  group('AppUser', () {
    test('un documento viejo sin los campos nuevos se lee con valores '
        'vacíos', () {
      final user = AppUser.fromMap('uid-1', {
        'name': 'Pamela Ruiz',
        'email': 'pamela@auravitae.com',
        'role': 'operator',
        'active': true,
      });

      expect(user.recoveryEmail, isEmpty);
      expect(user.startSection, isEmpty);
      expect(user.role, UserRole.operator);
      expect(user.active, isTrue);
    });

    test('toMap/fromMap conserva los campos de perfil', () {
      const original = AppUser(
        id: 'uid-2',
        name: 'Fernando Acuña',
        email: 'admin@auravitae.com',
        role: UserRole.admin,
        recoveryEmail: 'real@gmail.com',
        startSection: 'sales',
      );

      final restored = AppUser.fromMap(original.id, original.toMap());

      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.role, UserRole.admin);
      expect(restored.recoveryEmail, 'real@gmail.com');
      expect(restored.startSection, 'sales');
      expect(restored.active, isTrue);
    });

    test('copyWith de perfil no toca rol, estado ni correo de la cuenta', () {
      const user = AppUser(
        id: 'uid-3',
        name: 'Operador',
        email: 'operador@auravitae.com',
        role: UserRole.operator,
        active: false,
      );

      final updated = user.copyWith(
        name: 'Operador Editado',
        recoveryEmail: 'contacto@gmail.com',
        startSection: 'movements',
      );

      expect(updated.name, 'Operador Editado');
      expect(updated.recoveryEmail, 'contacto@gmail.com');
      expect(updated.startSection, 'movements');
      // Lo que las reglas de Firestore no dejan cambiar desde el perfil.
      expect(updated.email, user.email);
      expect(updated.role, UserRole.operator);
      expect(updated.active, isFalse);
    });
  });
}
