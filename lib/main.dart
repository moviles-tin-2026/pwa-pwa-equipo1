import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'screens/login/login_screen.dart';
import 'screens/shell/app_shell.dart';
import 'services/auth_service.dart';
import 'services/firestore_inventory_repository.dart';
import 'services/inventory_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PymeSyncApp());
}

/// PyME-Sync — Control de Inventarios y Ventas Multiplataforma.
///
/// Arquitectura (ver `context/Diseno_Modulos_PyME_Sync.pdf`):
/// - Módulo 0: Autenticación (Firebase Auth) y Gestión de Usuarios.
/// - Módulo 1: Dashboard con vistas por rol.
/// - Módulo 2: Catálogos e Inventario.
/// - Módulo 3: Movimientos de Almacén.
/// - Módulo 4: Punto de Venta e Historial.
///
/// Todos los datos viven en Cloud Firestore (proyecto PyME) con
/// sincronización reactiva mediante snapshots.
class PymeSyncApp extends StatelessWidget {
  const PymeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const _PymeSyncRoot(),
    );
  }
}

/// Redirige según el estado de sesión:
/// - Sin sesión: pantalla de Login.
/// - Con sesión: shell principal con el menú filtrado por rol, con el
///   repositorio conectado a Cloud Firestore.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final app = MaterialApp(
      title: 'AURA VITAE · PymeSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: auth.isLoggedIn ? const AppShell() : const LoginScreen(),
    );

    if (!auth.isLoggedIn) return app;

    return ChangeNotifierProvider<InventoryRepository>(
      // key fuerza un repositorio nuevo al cambiar de usuario/modo.
      key: ValueKey('${auth.currentUser!.id}-${auth.isDemoSession}'),
      create: (_) => auth.isDemoSession
          ? LocalInventoryRepository()
          : FirestoreInventoryRepository(),
      child: app,
    );
  }
}
