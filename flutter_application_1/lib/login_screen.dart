import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'registro_screen.dart';
import 'recuperar_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;

  late final AnimationController _controller;
  late final Animation<double> _curva;

  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);
  static const Color dorado = Color(0xFFF2B705);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _curva = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mensaje('Ingresa tu correo y contraseña');
      return;
    }

    setState(() => _cargando = true);

    try {
      // Al iniciar sesión, AuthGate detecta el cambio y abre la pantalla según el rol.
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _mensaje('No existe una cuenta con ese correo');
          break;
        case 'wrong-password':
          _mensaje('Contraseña incorrecta');
          break;
        case 'invalid-email':
          _mensaje('El correo no es válido');
          break;
        case 'invalid-credential':
          _mensaje('Correo o contraseña incorrectos');
          break;
        case 'network-request-failed':
          _mensaje('Sin conexión a internet');
          break;
        default:
          _mensaje('Error al iniciar sesión: ${e.message}');
      }
    } catch (e) {
      _mensaje('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE3F0FD), Colors.white],
              ),
            ),
          ),
          Positioned(top: -60, left: -40, child: _circulo(170, azul.withValues(alpha: 0.15))),
          Positioned(top: 50, right: -50, child: _circulo(130, rojo.withValues(alpha: 0.12))),
          Positioned(bottom: -70, right: -30, child: _circulo(190, amarillo.withValues(alpha: 0.2))),
          Positioned(bottom: 110, left: -60, child: _circulo(140, dorado.withValues(alpha: 0.12))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: AnimatedBuilder(
                  animation: _curva,
                  builder: (context, child) {
                    final t = _curva.value;
                    return Column(
                      children: [
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(math.pi * (1 - t)),
                            child: Image.asset('assets/logo.png', height: 110, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: _tarjeta()),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta() {
    return Container(
      padding: const EdgeInsets.all(28),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: azul.withValues(alpha: 0.1), blurRadius: 34, offset: const Offset(0, 14)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bienvenido',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          Text('Inicia sesión para continuar', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 26),
          _campoTexto(
            controller: _emailController,
            label: 'Correo electrónico',
            icono: Icons.email_outlined,
            teclado: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _campoTexto(
            controller: _passwordController,
            label: 'Contraseña',
            icono: Icons.lock_outline,
            esPassword: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cargando
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecuperarPasswordScreen(
                            emailInicial: _emailController.text.trim(),
                          ),
                        ),
                      );
                    },
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: azul, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _cargando ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [azul, azulOscuro]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _cargando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                        )
                      : const Text(
                          'Ingresar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _cargando
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegistroScreen()),
                      ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  children: const [
                    TextSpan(text: '¿No tienes cuenta? '),
                    TextSpan(
                      text: 'Regístrate',
                      style: TextStyle(color: azul, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circulo(double tamano, Color color) {
    return Container(width: tamano, height: tamano, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    TextInputType? teclado,
    bool esPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      obscureText: esPassword ? _ocultarPassword : false,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icono, color: azul, size: 20),
        suffixIcon: esPassword
            ? IconButton(
                icon: Icon(
                  _ocultarPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
              )
            : null,
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: azul, width: 1.5),
        ),
      ),
    );
  }
}