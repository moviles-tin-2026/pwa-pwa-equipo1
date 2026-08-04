import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

/// Configuración de la cuenta — disponible para ambos roles.
///
/// Reúne lo que cada persona puede cambiar de sí misma:
/// - **Perfil**: su nombre (el rol y el estado los administra el Admin).
/// - **Correo de recuperación**: su correo real de contacto.
/// - **Seguridad**: enlace para restablecer la contraseña y el cambio del
///   correo de la cuenta.
/// - **Preferencias**: sección con la que abre el sistema.
///
/// Sobre el correo de recuperación: Firebase solo manda el enlace de
/// restablecimiento al **correo de la cuenta**, nunca a una dirección
/// alterna guardada en Firestore. Por eso guardarlo no basta y esta
/// pantalla ofrece además promoverlo a correo de la cuenta, que es lo que
/// hace que el enlace llegue a una bandeja real.
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
  late final TextEditingController _nameController;
  late final TextEditingController _recoveryController;

  late String _startSection;
  bool _savingProfile = false;
  bool _savingRecovery = false;
  bool _sendingReset = false;
  bool _changingEmail = false;

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

  /// Promueve el correo de recuperación a correo de la cuenta. Es el paso
  /// que hace que el restablecimiento llegue a una bandeja real.
  Future<void> _useRecoveryAsAccountEmail() async {
    if (!_recoveryFormKey.currentState!.validate()) return;
    final target = _recoveryController.text.trim().toLowerCase();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usar como correo de la cuenta'),
        content: Text(
          'Te enviaremos un enlace de verificación a $target.\n\n'
          'Al abrirlo desde esa bandeja, ese correo pasa a ser el de tu '
          'cuenta: con él iniciarás sesión y a él llegará el enlace para '
          'restablecer tu contraseña. Mientras no lo confirmes, nada '
          'cambia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar verificación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _changingEmail = true);
    try {
      // Se guarda primero para no perder el dato si la persona cierra la
      // pantalla antes de confirmar el enlace.
      await _auth.updateOwnProfile(recoveryEmail: target);
      await _auth.startAccountEmailChange(target);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Verificación enviada a $target. Ábrela desde ese correo para '
        'completar el cambio.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _changingEmail = false);
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
    final busy = _savingRecovery || _changingEmail;

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
    final isAccountEmail = user.recoveryEmail.isNotEmpty &&
        user.recoveryEmail.toLowerCase() == user.email.toLowerCase();

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
              'Tu correo real de contacto. Guárdalo aquí para que el '
              'administrador pueda localizarte.',
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
                color: AppTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppTheme.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Guardarlo aquí no basta para recuperar tu '
                          'contraseña',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAccountEmail
                        ? 'Este ya es el correo de tu cuenta, así que el '
                            'enlace de restablecimiento te llega ahí.'
                        : 'Firebase solo envía el enlace de restablecimiento '
                            'al correo de la cuenta (${user.email}). Para '
                            'recibirlo en el correo de arriba, conviértelo en '
                            'el correo de tu cuenta.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _saveRecoveryEmail,
                  icon: _savingRecovery
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar'),
                ),
                if (!isAccountEmail)
                  FilledButton.icon(
                    onPressed: busy ? null : _useRecoveryAsAccountEmail,
                    icon: _changingEmail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Usar como correo de la cuenta'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Seguridad ──────────────────────────────────────────────────────

  Widget _securityCard(AppUser user) => GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Seguridad'),
            const SizedBox(height: 12),
            const Text(
              'Cambia tu contraseña con el enlace que envía Firebase.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Se enviará a ${user.email}',
              style: const TextStyle(fontSize: 12, color: AppTheme.mauve),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _sendingReset ? null : _sendReset,
                icon: _sendingReset
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset, size: 18),
                label: const Text('Enviar enlace de cambio de contraseña'),
              ),
            ),
          ],
        ),
      );

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
