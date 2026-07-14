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
/// Los datos viven en Cloud Firestore con sincronización reactiva
/// (snapshots). Las cuentas demo usan un repositorio local en memoria
/// para previsualizar la UI sin depender de la consola de Firebase.
class PymeSyncApp extends StatelessWidget {
  const PymeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'AURA VITAE · PymeSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Redirige según el estado de sesión:
/// - Sin sesión: pantalla de Login.
/// - Con sesión: shell principal con el menú filtrado por rol, inyectando
///   el repositorio adecuado (Firestore para cuentas reales, local para
///   las cuentas demo).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isLoggedIn) return const LoginScreen();

    return ChangeNotifierProvider<InventoryRepository>(
      // key fuerza un repositorio nuevo al cambiar de usuario/modo.
      key: ValueKey('${auth.currentUser!.id}-${auth.isDemoSession}'),
      create: (_) => auth.isDemoSession
          ? LocalInventoryRepository()
          : FirestoreInventoryRepository(),
      child: const AppShell(),
    );
  }
}
