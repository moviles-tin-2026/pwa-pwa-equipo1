import 'package:cloud_firestore/cloud_firestore.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Sin `await` a propósito. En web, `initializeApp` dispara una cadena de
  // red encadenada (el iframe de Auth y luego `getProjectConfig`) que mide
  // ~2.5 s en Lighthouse; esperarla aquí retrasaba el primer frame de la
  // app por ese mismo tiempo y era lo que sostenía el Speed Index en ~10 s.
  //
  // Se arranca la inicialización y se pinta de inmediato. Quien necesita
  // Firebase espera este `Future` en el punto exacto donde lo usa
  // (ver `AuthService`), no antes de dibujar.
  final firebaseReady = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) => _enableOfflinePersistence());

  runApp(PymeSyncApp(firebaseReady: firebaseReady));
}

/// Enciende la caché local de Firestore.
///
/// En web viene apagada por defecto (en móvil y escritorio, encendida), y
/// sin ella la PWA arrancaba sin conexión pero con las pantallas vacías:
/// el service worker cachea la app, no los datos. Con la caché activa, lo
/// que ya se consultó se puede volver a consultar sin red.
///
/// Va encadenado a `initializeApp` porque los ajustes deben aplicarse
/// antes de la primera operación de Firestore, y todo lo que toca
/// Firestore espera este mismo `Future` (ver `AuthService`).
///
/// Ojo: esto habilita **lecturas** sin conexión. Las escrituras del POS y
/// de movimientos usan transacciones, que Firestore no puede resolver sin
/// red porque necesita leer el stock del servidor para descontarlo de
/// forma atómica.
Future<void> _enableOfflinePersistence() async {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {
    // Con varias pestañas abiertas, solo una puede tomar la persistencia
    // en web. La app funciona igual, sin caché local en esa pestaña.
  }
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
  const PymeSyncApp({super.key, required this.firebaseReady});

  /// Inicialización de Firebase en curso, arrancada por `main` sin esperar.
  final Future<void> firebaseReady;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(ready: firebaseReady),
      child: const AuthGate(),
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

    final home = auth.isLoading
        ? const _AuthLoadingScreen()
        : auth.isLoggedIn
            ? const AppShell()
            : const LoginScreen();

    final app = MaterialApp(
      title: 'AURA VITAE · PymeSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
    );

    if (!auth.isLoggedIn) return app;

    return ChangeNotifierProvider<InventoryRepository>(
      // key fuerza un repositorio nuevo al cambiar de usuario.
      key: ValueKey(auth.currentUser!.id),
      create: (_) => FirestoreInventoryRepository(),
      child: app,
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
