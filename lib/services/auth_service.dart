import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Servicio de autenticación y sesión.
///
/// Flujo real (Firebase):
/// 1. Autentica con Firebase Authentication (Email/Password).
/// 2. Lee el rol desde Cloud Firestore, colección `users`:
///    primero busca el documento `users/{uid}`; si no existe, busca por
///    campo `email`. Si tampoco existe, crea el documento con rol
///    Operador (el Admin puede cambiarlo después en Gestión de Usuarios).
/// 3. Redirige según el rol detectado (lo hace el AuthGate de main.dart).
///
/// Cuentas demo (para previsualizar en Android Studio sin usuarios ni
/// datos reales; usan el repositorio local en memoria):
/// - admin@pymesync.com    / Admin123!    -> Administrador
/// - operador@pymesync.com / Operador123! -> Operador
class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isDemoSession = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// `true` cuando la sesión usa una cuenta demo (sin Firebase);
  /// main.dart lo usa para elegir el repositorio local en vez de Firestore.
  bool get isDemoSession => _isDemoSession;

  static const _demoAccounts = {
    'admin@pymesync.com': (
      password: 'Admin123!',
      name: 'Ana Martínez',
      role: UserRole.admin,
    ),
    'operador@pymesync.com': (
      password: 'Operador123!',
      name: 'Luis Herrera',
      role: UserRole.operator,
    ),
  };

  /// Inicia sesión. Lanza [AuthException] con un mensaje listo para UI.
  Future<AppUser> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();

    final demo = _demoAccounts[normalized];
    if (demo != null) {
      if (demo.password != password) {
        throw const AuthException('La contraseña es incorrecta');
      }
      _currentUser = AppUser(
        id: 'demo-$normalized',
        name: demo.name,
        email: normalized,
        role: demo.role,
      );
      _isDemoSession = true;
      notifyListeners();
      return _currentUser!;
    }

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: normalized, password: password);
      final user = credential.user!;
      final profile = await _loadProfile(user.uid, normalized,
          displayName: user.displayName);

      if (!profile.active) {
        await FirebaseAuth.instance.signOut();
        throw const AuthException(
          'Tu cuenta está desactivada. Contacta al administrador.',
        );
      }

      _currentUser = profile;
      _isDemoSession = false;
      notifyListeners();
      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'user-not-found' => 'No existe un usuario con ese correo',
        'wrong-password' => 'La contraseña es incorrecta',
        'invalid-email' => 'El correo no es válido',
        'invalid-credential' =>
          'Las credenciales son incorrectas o expiraron',
        'network-request-failed' =>
          'Sin conexión. Usa las cuentas demo para probar sin red.',
        _ => 'Error al iniciar sesión (${e.code})',
      });
    }
  }

  /// Obtiene (o crea) el perfil con rol desde la colección `users`.
  Future<AppUser> _loadProfile(String uid, String email,
      {String? displayName}) async {
    final users = FirebaseFirestore.instance.collection('users');

    try {
      final byUid = await users.doc(uid).get();
      if (byUid.exists) {
        return AppUser.fromMap(byUid.id, byUid.data()!);
      }

      final byEmail =
          await users.where('email', isEqualTo: email).limit(1).get();
      if (byEmail.docs.isNotEmpty) {
        final doc = byEmail.docs.first;
        return AppUser.fromMap(doc.id, doc.data());
      }

      // Primer inicio de sesión sin perfil: crear como Operador.
      final profile = AppUser(
        id: uid,
        name: displayName ?? email.split('@').first,
        email: email,
        role: UserRole.operator,
      );
      await users.doc(uid).set(profile.toMap());
      return profile;
    } catch (_) {
      // Firestore no disponible (p. ej. sin conexión): degradar con la
      // heurística por correo para no bloquear el acceso.
      return AppUser(
        id: uid,
        name: displayName ?? email.split('@').first,
        email: email,
        role: email.startsWith('admin') ? UserRole.admin : UserRole.operator,
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Sesiones demo no existen en Firebase; ignorar.
    }
    _currentUser = null;
    _isDemoSession = false;
    notifyListeners();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
