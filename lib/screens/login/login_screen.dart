import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

/// Módulo 0 — Pantalla de Login.
///
/// Formulario con Firebase Authentication (Email/Password) y redirección
/// automática según el rol detectado (ver `AuthGate` en main.dart).
/// Fotografía de producto a pantalla completa con una tarjeta de vidrio
/// (glassmorphism) flotando encima — misma estética en móvil y escritorio.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const _backgroundAsset =
      'res/images/AuraVitae-Login-backgroundImg.webp';

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.centerLeft,
          ),
          // Oscurece hacia la derecha para separar la tarjeta de vidrio
          // del bodegón fotográfico y garantizar contraste de texto.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.25, 1],
                colors: [
                  Colors.transparent,
                  AppTheme.cocoa.withValues(alpha: 0.70),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.4, 1],
                colors: [
                  AppTheme.cocoa.withValues(alpha: 0.35),
                  Colors.transparent,
                  AppTheme.cocoa.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
          SafeArea(
            child: isWide
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: _WideLayout(),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: _CompactLayout(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Escritorio/tablet: panel de vidrio con la marca saliendo del borde
/// izquierdo (sobre el bodegón), tarjeta flotando a la derecha sobre el
/// muro despejado de la fotografía.
class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: _BrandGlassPanel(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 56),
            child: SizedBox(
              width: 420,
              child: SingleChildScrollView(child: _LoginForm()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placa de vidrio que ancla el texto de marca al borde izquierdo de la
/// pantalla — sin bordes redondeados en ese lado, como si emergiera de él.
class _BrandGlassPanel extends StatelessWidget {
  const _BrandGlassPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(40, 40, 32, 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
          child: const _BrandMark(),
        ),
      ),
    );
  }
}

/// Móvil: marca compacta arriba y tarjeta centrada verticalmente.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BrandMark(compact: true),
                SizedBox(height: 28),
                _LoginForm(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Marca sobre la fotografía: logo oficial + descripción en escritorio.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(height: compact ? 130 : 160),
        if (!compact) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: 320,
            child: Text(
              'Gestión inteligente de inventario, ventas y equipo '
              'para tu negocio de skincare.',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
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
  bool _isSendingReset = false;

  // ---- Estándar de seguridad de contraseña ----
  static const int _passwordMaxLength = 64;
  static final RegExp _whitespaceRegex = RegExp(r'\s');

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
    // Las credenciales son pre-asignadas: la verificación real de la
    // contraseña la hace Firebase Auth contra el usuario existente.
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _signIn(_emailController.text, _passwordController.text);
  }

  /// Envía el enlace de restablecimiento al correo escrito arriba.
  ///
  /// Valida el formato antes de llamar a Firebase y **espera** la
  /// respuesta: la versión anterior disparaba el envío sin esperarlo y
  /// anunciaba "enlace enviado" pasara lo que pasara, incluso con un texto
  /// que ni siquiera era un correo.
  Future<void> _sendPasswordReset() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final invalid = _validateEmail(email);
    if (invalid != null) {
      showErrorSnackBar(context, invalid);
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (!mounted) return;
      // Firebase puede tener activada la protección contra enumeración de
      // correos: en ese caso responde igual exista o no la cuenta, así que
      // el mensaje no puede afirmar que el correo salió.
      showSuccessSnackBar(
        context,
        'Si $email tiene una cuenta, el enlace llegará en unos minutos. '
        'Revisa también la carpeta de spam.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
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
    return GlassCard(
      borderRadius: 24,
      blur: 28,
      opacity: 0.80,
      frosted: true,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: _glassInputTheme(context),
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.cocoa,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu rol se detecta automáticamente al ingresar',
                style: TextStyle(fontSize: 13, color: AppTheme.mauve),
              ),
              const SizedBox(height: 28),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSendingReset ? null : _sendPasswordReset,
                  child: Text(
                    _isSendingReset
                        ? 'Enviando…'
                        : '¿Olvidaste tu contraseña?',
                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Campos translúcidos para que se lean como parte del vidrio en vez
  /// de cajas sólidas `almond` (relleno del tema global de la app).
  InputDecorationThemeData _glassInputTheme(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    );
    return Theme.of(context).inputDecorationTheme.copyWith(
      fillColor: Colors.white.withValues(alpha: 0.55),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.merlot, width: 2),
      ),
    );
  }
}
