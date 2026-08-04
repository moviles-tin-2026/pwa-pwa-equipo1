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

  testWidgets('El login muestra el formulario de acceso',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildLogin());

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Valida correo y contraseña antes de enviar',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildLogin());

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  // El restablecimiento anunciaba "enlace enviado" con cualquier texto,
  // incluso uno que no era un correo, porque no validaba el formato ni
  // esperaba la respuesta de Firebase.
  testWidgets('El restablecimiento rechaza un correo sin formato válido',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildLogin());

    await tester.enterText(
      find.byType(TextFormField).first,
      'pamelaruiz',
    );
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();

    // Aparece dos veces: bajo el campo (autovalidación) y en el snackbar.
    expect(
      find.text('Ingresa un correo válido (ej. nombre@dominio.com)'),
      findsAtLeastNWidgets(1),
    );
    // Y sobre todo: no anuncia un envío que nunca ocurrió.
    expect(find.textContaining('llegará en unos minutos'), findsNothing);
  });

  testWidgets('El restablecimiento pide el correo cuando está vacío',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildLogin());

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    expect(find.textContaining('llegará en unos minutos'), findsNothing);
  });
}
