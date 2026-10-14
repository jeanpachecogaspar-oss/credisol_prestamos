import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmarPasswordController = TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;
  bool _acepto = false;

  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _registrarUsuario() async {
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmar = _confirmarPasswordController.text.trim();

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      _mensaje('Completa todos los campos');
      return;
    }

    if (password != confirmar) {
      _mensaje('Las contraseñas no coinciden');
      return;
    }

    if (password.length < 6) {
      _mensaje('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (!_acepto) {
      _mensaje('Debes aceptar el uso de tu ubicación para registrarte');
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. GPS obligatorio: sin ubicación no se crea la cuenta
      final gps = await LocationService.solicitar();
      if (gps != EstadoUbicacion.ok) {
        switch (gps) {
          case EstadoUbicacion.servicioApagado:
            _mensaje('Enciende el GPS del celular para registrarte');
            await Geolocator.openLocationSettings();
            break;
          case EstadoUbicacion.denegadoPermanente:
            _mensaje('Permite la ubicación para esta app desde los ajustes');
            await Geolocator.openAppSettings();
            break;
          default:
            _mensaje('Necesitamos el permiso de ubicación para registrarte');
        }
        return;
      }

      Position posicion;
      try {
        posicion = await LocationService.posicionActual();
      } catch (_) {
        _mensaje('No pudimos obtener tu ubicación. Verifica que el GPS esté activo e inténtalo de nuevo');
        return;
      }

      // 2. Crear cuenta
      final credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 3. Datos del usuario. Todo el que se registra es cliente.
      await FirebaseFirestore.instance.collection('usuarios').doc(credencial.user!.uid).set({
        'nombre': nombre,
        'email': email,
        'rol': 'cliente',
        'aceptoUbicacion': true,
        'ubicacion': LocationService.mapa(posicion),
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _mensaje('Cuenta creada correctamente');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _mensaje('Ya existe una cuenta con ese correo');
          break;
        case 'invalid-email':
          _mensaje('El correo no es válido');
          break;
        case 'weak-password':
          _mensaje('La contraseña es muy débil');
          break;
        case 'network-request-failed':
          _mensaje('Sin conexión a internet');
          break;
        default:
          _mensaje('Error al registrar: ${e.message}');
      }
    } catch (e) {
      _mensaje('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
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
          Positioned(top: -60, right: -40, child: _circulo(170, azul.withValues(alpha: 0.15))),
          Positioned(top: 120, left: -60, child: _circulo(120, rojo.withValues(alpha: 0.1))),
          Positioned(bottom: -70, left: -30, child: _circulo(190, amarillo.withValues(alpha: 0.2))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    Image.asset('assets/logo.png', height: 80, fit: BoxFit.contain),
                    const SizedBox(height: 20),
                    Container(
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
                            'Crear cuenta',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Regístrate para simular tu préstamo',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 24),
                          _campo(
                            controller: _nombreController,
                            label: 'Nombre completo',
                            icono: Icons.person_outline,
                            capitalizar: TextCapitalization.words,
                          ),
                          const SizedBox(height: 14),
                          _campo(
                            controller: _emailController,
                            label: 'Correo electrónico',
                            icono: Icons.email_outlined,
                            teclado: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _campo(
                            controller: _passwordController,
                            label: 'Contraseña',
                            icono: Icons.lock_outline,
                            esPassword: true,
                          ),
                          const SizedBox(height: 14),
                          _campo(
                            controller: _confirmarPasswordController,
                            label: 'Confirmar contraseña',
                            icono: Icons.lock_reset_outlined,
                            esPassword: true,
                          ),
                          const SizedBox(height: 14),
                          _consentimiento(),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _cargando ? null : _registrarUsuario,
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
                                          'Registrarme',
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
                        ],
                      ),
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

  Widget _consentimiento() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _acepto = !_acepto),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acepto,
            activeColor: azul,
            onChanged: (v) => setState(() => _acepto = v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Acepto que la app use mi ubicación (GPS) mientras esté abierta, para evaluar y dar seguimiento a mi préstamo. No se accede a mis contactos ni fotos.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.35),
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

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    TextInputType? teclado,
    TextCapitalization capitalizar = TextCapitalization.none,
    bool esPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      textCapitalization: capitalizar,
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