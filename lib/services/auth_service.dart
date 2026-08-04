import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
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
  AuthService({Future<void>? ready}) : _ready = ready ?? Future<void>.value();

  final Future<void> _ready;

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

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

  /// Da de alta un usuario completo: cuenta en Firebase Authentication
  /// **y** documento de rol en `users/{uid}`. Solo lo usa el Admin desde
  /// Gestión de Usuarios.
  ///
  /// Antes el alta solo escribía en Firestore, así que la cuenta no existía
  /// en Auth y el usuario creado no podía iniciar sesión hasta darlo de
  /// alta a mano en la consola de Firebase.
  ///
  /// El documento va con el uid como id porque de eso dependen las reglas
  /// (`users/{userId}` con `request.auth.uid == userId`) y la carga de
  /// perfil al iniciar sesión.
  Future<AppUser> createUserAccount({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _ensureReady();
    final normalized = email.trim().toLowerCase();

    // La cuenta se crea en una instancia secundaria de Firebase a
    // propósito: `createUserWithEmailAndPassword` deja firmado al usuario
    // recién creado, y hacerlo sobre la app principal sacaría de su sesión
    // al administrador que está dando el alta.
    final auth = FirebaseAuth.instanceFor(app: await _provisioningApp());
    User? created;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      created = credential.user;
      final profile = AppUser(
        id: created!.uid,
        name: name.trim(),
        email: normalized,
        role: role,
      );
      // Se escribe con la app principal, es decir con la sesión del
      // administrador: las reglas exigen rol admin para crear perfiles
      // ajenos.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.id)
          .set(profile.toMap());
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'email-already-in-use' => 'Ya existe una cuenta con ese correo',
        'invalid-email' => 'El correo no es válido',
        'weak-password' =>
          'Firebase rechazó la contraseña por débil. Usa una más larga '
              'o genera una desde el formulario.',
        'operation-not-allowed' =>
          'El acceso con correo y contraseña está deshabilitado en la '
              'consola de Firebase.',
        'network-request-failed' =>
          'Sin conexión a internet. Intenta de nuevo.',
        _ => 'No se pudo crear la cuenta (${e.code})',
      });
    } catch (_) {
      // La cuenta se creó pero el perfil no: sin documento en `users` el
      // rol quedaría indefinido, así que se deshace el alta en vez de
      // dejar una cuenta huérfana.
      try {
        await created?.delete();
      } catch (_) {}
      throw const AuthException(
        'La cuenta no se pudo registrar en la base de datos. Verifica tu '
        'conexión y que tu sesión siga activa.',
      );
    } finally {
      // Cerrar la sesión que quedó abierta en la app secundaria. La del
      // administrador vive en la app principal y no se toca.
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  /// Instancia secundaria de Firebase reservada para las altas.
  Future<FirebaseApp> _provisioningApp() async {
    try {
      return Firebase.app(_provisioningAppName);
    } catch (_) {
      return Firebase.initializeApp(
        name: _provisioningAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static const String _provisioningAppName = 'pymesync-user-provisioning';

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
