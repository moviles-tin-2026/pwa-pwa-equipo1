import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login PyMe-Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ---- Paleta de colores ----
  static const Color _primaryColor = Color(0xFF54582F);
  static const Color _backgroundColor = Color(0xFFF8FBCA);

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
    _PasswordRule('Una letra mayúscula (A-Z)', (p) => RegExp(r'[A-Z]').hasMatch(p)),
    _PasswordRule('Una letra minúscula (a-z)', (p) => RegExp(r'[a-z]').hasMatch(p)),
    _PasswordRule('Un número (0-9)', (p) => RegExp(r'[0-9]').hasMatch(p)),
    _PasswordRule(
      'Un carácter especial (!@#\$%&* ...)',
      (p) => RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]/;]''').hasMatch(p),
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
    if (!_emailRegex.hasMatch(email)) return 'Ingresa un correo válido (ej. nombre@dominio.com)';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Ingresa tu contraseña';
    if (password.length > _passwordMaxLength) return 'No debe exceder $_passwordMaxLength caracteres';
    if (_whitespaceRegex.hasMatch(password)) return 'No debe contener espacios en blanco';
    for (final rule in _passwordRules) {
      if (!rule.isMet(password)) return 'Falta: ${rule.label}';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    
    try {
      // Autenticación Real con Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Inicio de sesión exitoso')),
            ],
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      String message = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') {
        message = 'No existe un usuario con ese correo';
      } else if (e.code == 'wrong-password') {
        message = 'La contraseña es incorrecta';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es válido';
      } else if (e.code == 'invalid-credential') {
        message = 'Las credenciales proporcionadas son incorrectas o expiraron';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Ocurrió un error inesperado')),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 100, color: _primaryColor),
              const SizedBox(height: 16),
              Text(
                'Bienvenido a PyMe-Sync',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryColor),
              ),
              const Text(
                'Gestión de Inventario y Ventas',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primaryColor, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                      onChanged: (value) => setState(() => _passwordValue = value),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primaryColor, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (_passwordValue.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _PasswordStrengthMeter(password: _passwordValue, rules: _passwordRules),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Opcional: Lógica para restablecer contraseña con Firebase
                          if (_emailController.text.isNotEmpty) {
                            FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
                          }
                        },
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Entrar',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
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

class _PasswordRule {
  const _PasswordRule(this.label, this.isMet);
  final String label;
  final bool Function(String password) isMet;
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password, required this.rules});

  final String password;
  final List<_PasswordRule> rules;

  @override
  Widget build(BuildContext context) {
    final metCount = rules.where((rule) => rule.isMet(password)).length;
    final ratio = metCount / rules.length;

    late final Color color;
    late final String label;
    if (ratio < 0.5) {
      color = Colors.redAccent;
      label = 'Débil';
    } else if (ratio < 1.0) {
      color = Colors.orange;
      label = 'Media';
    } else {
      color = Colors.green;
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
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
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
                  color: met ? Colors.green : Colors.grey,
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