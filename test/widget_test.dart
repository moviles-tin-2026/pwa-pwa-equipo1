// Pruebas de humo de la UI de PyME-Sync.
//
// Se prueba la pantalla de Login de forma aislada (sin inicializar
// Firebase) proveyendo el AuthService con Provider, igual que en main.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:login_app/screens/login/login_screen.dart';
import 'package:login_app/services/auth_service.dart';

void main() {
  Widget buildLogin() => ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const MaterialApp(home: LoginScreen()),
      );

  testWidgets('El login muestra el formulario y las cuentas demo',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildLogin());

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    // Accesos rápidos con cuentas demo (Admin / Operador).
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Operador'), findsOneWidget);
  });

  testWidgets('Valida correo y contraseña antes de enviar',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildLogin());

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });
}
