import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Servicio de autenticación y sesión.
///
/// 1. Autentica con Firebase Authentication (Email/Password).
/// 2. Lee el rol desde Cloud Firestore, colección `users`:
///    primero busca el documento `users/{uid}`; si no existe, busca por
///    campo `email`. Si tampoco existe, crea el documento con rol
///    Operador (el Admin puede cambiarlo después en Gestión de Usuarios).
/// 3. Redirige según el rol detectado (lo hace el AuthGate de main.dart).
class AuthService extends ChangeNotifier {
  /// [ready] es el `Future` de `Firebase.initializeApp`, que `main` arranca
  /// sin esperar para no retrasar el primer frame. Cada operación que toca
  /// Firebase lo espera antes de usarlo. En la práctica ya está resuelto
  /// mucho antes de que alguien termine de escribir sus credenciales.
  ///
  /// Omitirlo (los tests lo hacen) equivale a "Firebase ya está listo".
  AuthService({Future<void>? ready}) : _ready = ready ?? Future<void>.value() {
    _initAuthState();
  }

  final Future<void> _ready;

  AppUser? _currentUser;
  bool _loading = true;
  StreamSubscription<User?>? _authStateSubscription;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isLoading => _loading;

  /// Espera a que Firebase esté inicializado, traduciendo un fallo de
  /// arranque a un mensaje de UI en lugar de un error crudo.
  Future<void> _ensureReady() async {
    try {
      await _ready;
    } catch (_) {
      throw const AuthException(
        'No se pudo conectar con el servidor. Revisa tu conexión '
        'e intenta de nuevo.',
      );
    }
  }

  Future<void> _initAuthState() async {
    try {
      await _ensureReady();
      final auth = FirebaseAuth.instance;

      try {
        await auth.setPersistence(Persistence.LOCAL);
      } catch (_) {
        // Ignorar si la plataforma no soporta esta persistencia o si ya
        // está configurada. En la web/PWA esto garantiza sesión tras F5.
      }

      _authStateSubscription =
          auth.idTokenChanges().listen(_handleAuthState, onError: (_) {
        _loading = false;
        notifyListeners();
      });

      final currentUser = auth.currentUser;
      if (currentUser != null) {
        await _handleAuthState(currentUser);
      }
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _handleAuthState(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _loading = false;
      notifyListeners();
      return;
    }

    if (_currentUser?.id == firebaseUser.uid && !_loading) {
      return;
    }

    try {
      final email = firebaseUser.email?.trim().toLowerCase() ?? '';
      final profile = await _loadProfile(
        firebaseUser.uid,
        email,
        displayName: firebaseUser.displayName,
      );

      if (!profile.active) {
        await FirebaseAuth.instance.signOut();
        _currentUser = null;
      } else {
        _currentUser = profile;
      }
    } catch (_) {
      _currentUser = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  /// Inicia sesión. Lanza [AuthException] con un mensaje listo para UI.
  Future<AppUser> signIn(String email, String password) async {
    await _ensureReady();
    final normalized = email.trim().toLowerCase();

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
          'Sin conexión a internet. Intenta de nuevo.',
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
    await _ensureReady();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _ensureReady();
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    notifyListeners();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
