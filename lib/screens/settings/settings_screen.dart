import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
// Las reglas de contraseña se comparten con el alta de usuarios para que
// el sistema exija lo mismo en los dos lugares.
import '../users/users_helpers.dart';

/// Configuración de la cuenta — disponible para ambos roles.
///
/// Reúne lo que cada persona puede cambiar de sí misma:
/// - **Perfil**: su nombre (el rol y el estado los administra el Admin).
/// - **Correo de recuperación**: correo secundario para recuperar el
///   acceso.
/// - **Seguridad**: cambio de contraseña con la contraseña actual.
/// - **Preferencias**: sección con la que abre el sistema.
///
/// El correo del usuario NO se cambia desde aquí y no debería cambiarse:
/// en un CRM es su identidad, y de él cuelgan las ventas y movimientos que
/// registró. Todo lo de esta pantalla toca contraseñas, nunca identidades.
///
/// Límite conocido: Firebase solo envía el enlace de restablecimiento al
/// correo de la cuenta, así que el correo de recuperación queda registrado
/// para que el administrador recupere el acceso de esa persona. Entregarle
/// el enlace directo a ese correo secundario exige un backend propio
/// (Cloud Function con `generatePasswordResetLink` + servicio de correo).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.availableSections = const []});

  /// Secciones que el rol puede abrir, para la preferencia de inicio.
  /// Cada una es (valor guardado, etiqueta visible).
  final List<({String value, String label})> availableSections;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _recoveryFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _recoveryController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late String _startSection;
  bool _savingProfile = false;
  bool _savingRecovery = false;
  bool _sendingReset = false;
  bool _changingPassword = false;
  bool _obscurePasswords = true;

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
    r'[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _recoveryController = TextEditingController(text: user?.recoveryEmail ?? '');
    _startSection = user?.startSection ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _recoveryController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  AuthService get _auth => context.read<AuthService>();

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      await _auth.updateOwnProfile(
        name: _nameController.text,
        startSection: _startSection,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Perfil actualizado');
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveRecoveryEmail() async {
    if (!_recoveryFormKey.currentState!.validate()) return;
    setState(() => _savingRecovery = true);
    try {
      await _auth.updateOwnProfile(recoveryEmail: _recoveryController.text);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Correo de recuperación guardado');
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _savingRecovery = false);
    }
  }

  Future<void> _sendReset() async {
    setState(() => _sendingReset = true);
    try {
      final email = await _auth.sendPasswordResetToAccountEmail();
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Enlace enviado a $email. Revisa también la carpeta de spam.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _changingPassword = true);
    try {
      await _auth.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      showSuccessSnackBar(
        context,
        'Contraseña actualizada. Úsala la próxima vez que inicies sesión.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  String? _validateRecoveryEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Escribe un correo de recuperación';
    if (!_emailRegex.hasMatch(email)) {
      return 'Correo no válido (ej. nombre@dominio.com)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final padding = context.pagePadding;
    final busy = _savingRecovery;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.transparent,
      ),
      body: AuraBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 40),
              children: [
                _profileCard(user),
                const SizedBox(height: 16),
                _recoveryCard(user, busy: busy),
                const SizedBox(height: 16),
                _securityCard(user),
                const SizedBox(height: 16),
                _preferencesCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Perfil ─────────────────────────────────────────────────────────

  Widget _profileCard(AppUser user) => GlassCard(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Mi perfil'),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.peony,
                    child: Text(
                      user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppTheme.merlot,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            RoleBadge(role: user.role),
                            const SizedBox(width: 8),
                            Text(
                              user.active ? 'Cuenta activa' : 'Cuenta inactiva',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.mauve,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'El rol y el estado de la cuenta los administra el '
                'Administrador.',
                style: TextStyle(fontSize: 11, color: AppTheme.mauve),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _savingProfile ? null : _saveProfile,
                  icon: _savingProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar perfil'),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Correo de recuperación ─────────────────────────────────────────

  Widget _recoveryCard(AppUser user, {required bool busy}) {
    final registered = user.recoveryEmail.isNotEmpty;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _recoveryFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Correo de recuperación'),
            const SizedBox(height: 12),
            const Text(
              'Regístralo ahora, mientras recuerdas tu contraseña. Es el '
              'correo al que pedirás ayuda si la pierdes; tu usuario del '
              'sistema no cambia.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _recoveryController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo de recuperación',
                hintText: 'nombre@dominio.com',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: _validateRecoveryEmail,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (registered ? AppTheme.success : AppTheme.warning)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    registered
                        ? Icons.verified_outlined
                        : Icons.info_outline,
                    size: 16,
                    color: registered ? AppTheme.success : AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      registered
                          ? 'Registrado. Tu usuario sigue siendo '
                              '${user.email}: el correo de recuperación no '
                              'lo reemplaza, solo sirve para recuperar el '
                              'acceso.'
                          : 'Aún no tienes correo de recuperación. Si '
                              'pierdes tu contraseña sin haberlo '
                              'registrado, solo el administrador podrá '
                              'ayudarte.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : _saveRecoveryEmail,
                icon: _savingRecovery
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seguridad ──────────────────────────────────────────────────────

  Widget _securityCard(AppUser user) {
    final busy = _changingPassword || _sendingReset;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Seguridad'),
            const SizedBox(height: 12),
            const Text(
              'Cambia tu contraseña aquí mismo. Se te pide la actual para '
              'confirmar que eres tú.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscurePasswords,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePasswords ? 'Mostrar' : 'Ocultar',
                  icon: Icon(
                    _obscurePasswords
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscurePasswords = !_obscurePasswords,
                  ),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Escribe tu contraseña actual'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscurePasswords,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Contraseña nueva',
                helperText: 'Mínimo 8, con mayúscula, minúscula, número y '
                    'carácter especial',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.key_outlined),
              ),
              validator: validateNewPassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePasswords,
              decoration: const InputDecoration(
                labelText: 'Repetir contraseña nueva',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              validator: (v) => validatePasswordConfirmation(
                v,
                _newPasswordController.text,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : _changePassword,
                icon: _changingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_reset, size: 18),
                label: const Text('Cambiar contraseña'),
              ),
            ),
            const Divider(height: 28),
            const Text(
              '¿No recuerdas tu contraseña actual?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Te enviamos un enlace a ${user.email} para restablecerla.',
              style: const TextStyle(fontSize: 12, color: AppTheme.mauve),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _sendReset,
                icon: _sendingReset
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mail_outline, size: 18),
                label: const Text('Enviarme el enlace por correo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preferencias ───────────────────────────────────────────────────

  Widget _preferencesCard() => GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Preferencias'),
            const SizedBox(height: 12),
            const Text(
              'Sección con la que abre el sistema al iniciar sesión.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _startSection.isEmpty ? '' : _startSection,
              decoration: const InputDecoration(
                labelText: 'Sección de inicio',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Dashboard (predeterminado)'),
                ),
                for (final section in widget.availableSections)
                  DropdownMenuItem(
                    value: section.value,
                    child: Text(section.label),
                  ),
              ],
              onChanged: _savingProfile
                  ? null
                  : (value) => setState(() => _startSection = value ?? ''),
            ),
            const SizedBox(height: 8),
            const Text(
              'Se guarda con el botón "Guardar perfil".',
              style: TextStyle(fontSize: 11, color: AppTheme.mauve),
            ),
          ],
        ),
      );
}
