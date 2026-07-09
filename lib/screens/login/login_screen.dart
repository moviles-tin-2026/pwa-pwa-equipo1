import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

/// Módulo 0 — Pantalla de Login.
///
/// Formulario con Firebase Authentication (Email/Password) y redirección
/// automática según el rol detectado. En pantallas anchas (web/escritorio)
/// muestra un panel de marca a la izquierda; en móvil, formulario a
/// pantalla completa (mobile-first).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: isWide
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: const _LoginForm(),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: const Column(
                    children: [
                      _BrandHeader(),
                      SizedBox(height: 32),
                      _LoginForm(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Panel lateral de marca (solo web/escritorio).
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandNavy, Color(0xFF2C5282)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'PyME-Sync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Control de inventarios y ventas\nsincronizado en la nube.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              for (final feature in const [
                'Inventario en tiempo real con Cloud Firestore',
                'Punto de venta con transacciones atómicas',
                'Roles diferenciados: Administrador y Operador',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado compacto de marca (móvil).
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.brandNavy.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 44,
            color: AppTheme.brandNavy,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bienvenido a PyME-Sync',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.brandNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gestión de Inventario y Ventas',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Regex de email según el estándar HTML5 (WHATWG)
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String _passwordValue = '';

  // ---- Estándar de seguridad de contraseña ----
  static const int _passwordMinLength = 8;
  static const int _passwordMaxLength = 64;
  static final RegExp _whitespaceRegex = RegExp(r'\s');

  static final List<_PasswordRule> _passwordRules = [
    _PasswordRule(
      'Al menos $_passwordMinLength caracteres',
      (p) => p.length >= _passwordMinLength,
    ),
    _PasswordRule(
      'Una letra mayúscula (A-Z)',
      (p) => RegExp(r'[A-Z]').hasMatch(p),
    ),
    _PasswordRule(
      'Una letra minúscula (a-z)',
      (p) => RegExp(r'[a-z]').hasMatch(p),
    ),
    _PasswordRule('Un número (0-9)', (p) => RegExp(r'[0-9]').hasMatch(p)),
    _PasswordRule(
      'Un carácter especial (!@#\$%&* ...)',
      (p) =>
          RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]/;]''').hasMatch(p),
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico';
    if (!_emailRegex.hasMatch(email)) {
      return 'Ingresa un correo válido (ej. nombre@dominio.com)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Ingresa tu contraseña';
    if (password.length > _passwordMaxLength) {
      return 'No debe exceder $_passwordMaxLength caracteres';
    }
    if (_whitespaceRegex.hasMatch(password)) {
      return 'No debe contener espacios en blanco';
    }
    for (final rule in _passwordRules) {
      if (!rule.isMet(password)) return 'Falta: ${rule.label}';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _signIn(_emailController.text, _passwordController.text);
  }

  Future<void> _signIn(String email, String password) async {
    setState(() => _isSubmitting = true);
    try {
      final user = await context.read<AuthService>().signIn(email, password);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Bienvenido, ${user.name} (${user.role.label})',
      );
      // La redirección la hace el AuthGate de main.dart al detectar sesión.
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Ocurrió un error inesperado');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Iniciar sesión',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Tu rol se detecta automáticamente al ingresar',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _validateEmail,
                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                validator: _validatePassword,
                onFieldSubmitted: (_) => _submit(),
                onChanged: (value) =>
                    setState(() => _passwordValue = value),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
              if (_passwordValue.isNotEmpty) ...[
                const SizedBox(height: 10),
                _PasswordStrengthMeter(
                  password: _passwordValue,
                  rules: _passwordRules,
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      showErrorSnackBar(
                        context,
                        'Escribe tu correo para enviarte el enlace',
                      );
                      return;
                    }
                    context.read<AuthService>().sendPasswordReset(email);
                    showSuccessSnackBar(
                      context,
                      'Enlace de restablecimiento enviado a $email',
                    );
                  },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Entrar', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Cuentas demo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _signIn('admin@pymesync.com', 'Admin123!'),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Admin'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _signIn(
                                'operador@pymesync.com',
                                'Operador123!',
                              ),
                      icon: const Icon(Icons.point_of_sale_outlined),
                      label: const Text('Operador'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRule {
  const _PasswordRule(this.label, this.isMet);
  final String label;
  final bool Function(String password) isMet;
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({
    required this.password,
    required this.rules,
  });

  final String password;
  final List<_PasswordRule> rules;

  @override
  Widget build(BuildContext context) {
    final metCount = rules.where((rule) => rule.isMet(password)).length;
    final ratio = metCount / rules.length;

    late final Color color;
    late final String label;
    if (ratio < 0.5) {
      color = AppTheme.danger;
      label = 'Débil';
    } else if (ratio < 1.0) {
      color = AppTheme.warning;
      label = 'Media';
    } else {
      color = AppTheme.success;
      label = 'Fuerte';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: rules.map((rule) {
            final met = rule.isMet(password);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  met ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: met ? AppTheme.success : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  rule.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: met ? Colors.grey[700] : Colors.grey,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
