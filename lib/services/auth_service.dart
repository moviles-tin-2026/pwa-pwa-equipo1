import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/models.dart';

/// Servicio de autenticación y sesión.
///
/// 1. Autentica con Firebase Authentication (Email/Password).
/// 2. Lee el rol desde Cloud Firestore en `users/{uid}`. Sin documento
///    de perfil no hay acceso: el alta la hace el Admin con
///    [createUserAccount].
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

  /// Id del documento en `sessions/` de la conexión actual, o `null` si no
  /// hay ninguna abierta.
  String? _activeSessionId;
  Timer? _heartbeatTimer;

  /// Cada cuánto se refresca `lastSeenAt` mientras la app sigue abierta.
  /// Acota el error de "horas conectadas" si alguien cierra la pestaña sin
  /// cerrar sesión: como máximo se cuentan de más estos minutos.
  static const Duration _heartbeatInterval = Duration(minutes: 3);

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
      // Cubre el cierre de sesión desde otra pestaña o un token revocado:
      // signOut() ya cierra la sesión por su cuenta, así que esto es un
      // no-op cuando pasa por ahí (`_activeSessionId` ya es null).
      await _endSession();
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
      final profile = await _loadProfile(firebaseUser.uid);

      if (!profile.active) {
        await FirebaseAuth.instance.signOut();
        await _endSession();
        _currentUser = null;
      } else {
        _currentUser = await _syncAccountEmail(profile, email);
        await _startSession(_currentUser!);
      }
    } catch (_) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      await _endSession();
      _currentUser = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---------------- Horas de conexión ----------------
  //
  // `AuthService` escribe directo en `sessions/` (igual que ya hace con
  // `users/{uid}` en altas y sincronización de correo) en vez de pasar por
  // `InventoryRepository`: ese repositorio solo existe DESPUÉS de haber
  // iniciado sesión (lo crea `AuthGate` una vez que hay `currentUser`), así
  // que no está disponible en el momento exacto en que hay que abrir la
  // sesión. `InventoryRepository` sí la lee, para mostrarla en Usuarios.

  /// Abre una sesión y arranca el heartbeat. Nunca lanza: sin esto no hay
  /// horas de conexión, pero el login no debe fallar por un problema de
  /// tracking secundario.
  Future<void> _startSession(AppUser user) async {
    try {
      final now = DateTime.now();
      final ref = await FirebaseFirestore.instance.collection('sessions').add(
        UserSession(
          id: '',
          userId: user.id,
          userName: user.name,
          startedAt: now,
          lastSeenAt: now,
        ).toMap(),
      );
      _activeSessionId = ref.id;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        _heartbeatInterval,
        (_) => _heartbeat(),
      );
    } catch (_) {}
  }

  Future<void> _heartbeat() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    try {
      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
        'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Cierra la sesión activa (si hay una) y para el heartbeat.
  Future<void> _endSession() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final sessionId = _activeSessionId;
    _activeSessionId = null;
    if (sessionId == null) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
        'endedAt': now,
        'lastSeenAt': now,
      });
    } catch (_) {}
  }

  /// Alinea `users/{uid}.email` con el correo real de Firebase Auth.
  ///
  /// El sistema no cambia correos de usuario: el correo es la identidad de
  /// la persona en el CRM. Pero si alguien lo cambia desde la consola de
  /// Firebase, el perfil de Firestore se quedaría con el anterior y tanto
  /// Configuración como la lista de usuarios mostrarían un correo que ya
  /// no sirve para iniciar sesión. Esto lo corrige al cargar el perfil.
  Future<AppUser> _syncAccountEmail(AppUser profile, String authEmail) async {
    if (authEmail.isEmpty || profile.email.toLowerCase() == authEmail) {
      return profile;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.id)
          .update({'email': authEmail});
    } catch (_) {
      // Si las reglas o la red lo impiden, seguir con el correo de Auth en
      // memoria: es el bueno, y el documento se corregirá en otro arranque.
    }
    return profile.copyWith(email: authEmail);
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _heartbeatTimer?.cancel();
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
      final profile = await _loadProfile(user.uid);

      if (!profile.active) {
        await FirebaseAuth.instance.signOut();
        throw const AuthException(
          'Tu cuenta está desactivada. Contacta al administrador.',
        );
      }

      _currentUser = profile;
      await _startSession(profile);
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

  /// Obtiene el perfil en `users/{uid}`. Sin documento o sin permiso de
  /// lectura no hay sesión: evita inventar roles ni saltarse `active`.
  Future<AppUser> _loadProfile(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) {
        throw const AuthException(
          'No tienes un perfil en el sistema. Contacta al administrador.',
        );
      }
      return AppUser.fromMap(snap.id, snap.data()!);
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AuthException(_firestoreMessage(e, action: 'cargar tu perfil'));
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
    } catch (e) {
      // La cuenta se creó pero el perfil no: sin documento en `users` el
      // rol quedaría indefinido, así que se deshace el alta en vez de
      // dejar una cuenta huérfana.
      try {
        await created?.delete();
      } catch (_) {}
      throw AuthException(
        e is FirebaseException
            ? _firestoreMessage(e, action: 'registrar el perfil del usuario')
            : 'La cuenta no se pudo registrar en la base de datos ($e).',
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

  // ---------------- Perfil propio (Configuración) ----------------

  /// Guarda los campos que cada quien puede editar de su propio perfil.
  ///
  /// Las reglas de Firestore solo dejan tocar `name`, `recoveryEmail` y
  /// `startSection`: el rol y la baja son del administrador.
  Future<AppUser> updateOwnProfile({
    String? name,
    String? recoveryEmail,
    String? startSection,
  }) async {
    await _ensureReady();
    final current = _currentUser;
    if (current == null) {
      throw const AuthException('Tu sesión expiró. Vuelve a iniciar sesión.');
    }

    final updated = current.copyWith(
      name: name?.trim(),
      recoveryEmail: recoveryEmail?.trim().toLowerCase(),
      startSection: startSection,
    );

    try {
      // `update` y no `set(merge)` a propósito: si el documento no existe,
      // `set` sería una creación y las reglas la rechazarían por no traer
      // el rol, dando un `permission-denied` que despista. Con `update` el
      // error es `not-found`, que dice exactamente qué pasa.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(current.id)
          .update({
        'name': updated.name,
        'recoveryEmail': updated.recoveryEmail,
        'startSection': updated.startSection,
      });
    } on FirebaseException catch (e) {
      throw AuthException(_firestoreMessage(e, action: 'guardar tu perfil'));
    } catch (e) {
      throw AuthException(
        'No se pudieron guardar los cambios ($e). Revisa tu conexión '
        'e intenta de nuevo.',
      );
    }

    _currentUser = updated;
    notifyListeners();
    return updated;
  }

  /// Traduce un error de Firestore a un mensaje que diga qué pasó.
  ///
  /// El `permission-denied` importa especialmente: casi siempre significa
  /// que las reglas de `firestore.rules` no están publicadas en el
  /// proyecto (viajan en el repo, pero el deploy de Pages no las sube).
  /// Un mensaje genérico de "revisa tu conexión" manda a buscar el
  /// problema al lado equivocado.
  String _firestoreMessage(FirebaseException e, {required String action}) =>
      switch (e.code) {
        'permission-denied' =>
          'Tu cuenta no tiene permiso para $action. Si el problema '
              'persiste, revisa que las reglas de Firestore estén '
              'publicadas en el proyecto.',
        'unauthenticated' =>
          'Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.',
        'unavailable' || 'deadline-exceeded' =>
          'No se pudo contactar a la base de datos. Revisa tu conexión '
              'e intenta de nuevo.',
        'not-found' =>
          'No se encontró tu perfil en la base de datos. Contacta al '
              'administrador.',
        _ => 'No se pudo $action (${e.code}).',
      };

  /// Envía el enlace de restablecimiento al correo **de la cuenta**.
  ///
  /// Firebase no permite mandarlo a otra dirección: el correo de
  /// recuperación del perfil no recibe nada mientras no sea el correo de la
  /// cuenta (ver [startAccountEmailChange]).
  Future<String> sendPasswordResetToAccountEmail() async {
    final current = _currentUser;
    if (current == null || current.email.isEmpty) {
      throw const AuthException('Tu sesión expiró. Vuelve a iniciar sesión.');
    }
    // `sendPasswordReset` ya traduce el fallo a AuthException.
    await sendPasswordReset(current.email);
    return current.email;
  }

  /// Cambia la contraseña de la sesión actual sin pasar por el correo.
  ///
  /// Primero reautentica con la contraseña actual: Firebase exige
  /// autenticación reciente para `updatePassword`, y pedirla evita que
  /// alguien cambie la contraseña en una sesión ajena que quedó abierta.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _ensureReady();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email;
    if (firebaseUser == null || email == null || email.isEmpty) {
      throw const AuthException('Tu sesión expiró. Vuelve a iniciar sesión.');
    }
    if (currentPassword == newPassword) {
      throw const AuthException(
        'La contraseña nueva debe ser distinta de la actual.',
      );
    }

    try {
      await firebaseUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          'La contraseña actual es incorrecta',
        'too-many-requests' =>
          'Demasiados intentos seguidos. Espera unos minutos e intenta '
              'de nuevo.',
        'user-mismatch' || 'user-not-found' =>
          'Tu sesión ya no corresponde a esta cuenta. Vuelve a iniciar '
              'sesión.',
        'network-request-failed' =>
          'Sin conexión a internet. Intenta de nuevo.',
        _ => 'No se pudo verificar tu contraseña actual (${e.code})',
      });
    }

    try {
      await firebaseUser.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'weak-password' =>
          'Firebase rechazó la contraseña por débil. Usa una más larga.',
        'requires-recent-login' =>
          'Por seguridad, vuelve a iniciar sesión e intenta de nuevo.',
        'network-request-failed' =>
          'Sin conexión a internet. Intenta de nuevo.',
        _ => 'No se pudo cambiar la contraseña (${e.code})',
      });
    }
  }

  /// Pide a Firebase el enlace de restablecimiento para [email].
  ///
  /// Traduce el fallo a [AuthException] igual que [signIn]: antes lanzaba
  /// la excepción cruda de Firebase y quien llamaba no la esperaba, así que
  /// un correo inexistente o mal escrito se anunciaba como enviado.
  Future<void> sendPasswordReset(String email) async {
    await _ensureReady();
    final normalized = email.trim().toLowerCase();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: normalized);
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'invalid-email' || 'missing-email' =>
          'Escribe un correo válido (ej. nombre@dominio.com)',
        'user-not-found' => 'No existe una cuenta con ese correo',
        'too-many-requests' =>
          'Demasiados intentos seguidos. Espera unos minutos e intenta '
              'de nuevo.',
        'network-request-failed' =>
          'Sin conexión a internet. Intenta de nuevo.',
        _ => 'No se pudo enviar el enlace (${e.code})',
      });
    }
  }

  Future<void> signOut() async {
    await _ensureReady();
    await _endSession();
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
