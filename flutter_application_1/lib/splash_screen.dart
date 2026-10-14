import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Entrada del logo (una sola vez, con rebote)
  late final AnimationController _controllerEntrada;
  late final Animation<double> _escalaLogo;
  late final Animation<double> _opacidadLogo;
  late final Animation<double> _giroLogo;

  // Monedas orbitando (en bucle continuo)
  late final AnimationController _controllerOrbita;

  // Texto del eslogan (aparece después del logo)
  late final AnimationController _controllerTexto;
  late final Animation<double> _opacidadTexto;
  late final Animation<Offset> _posicionTexto;

  // Barra de progreso inferior (dura lo mismo que el splash)
  late final AnimationController _controllerProgreso;

  static const Color azul = Color(0xFF1E88E5);
  static const Color rojo = Color(0xFFE53935);
  static const Color amarillo = Color(0xFFFDD835);
  static const Color dorado = Color(0xFFF2B705);

  static const Duration duracionSplash = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();

    _controllerEntrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _escalaLogo = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controllerEntrada, curve: Curves.elasticOut),
    );
    _opacidadLogo = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controllerEntrada, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _giroLogo = Tween<double>(begin: math.pi, end: 0).animate(
      CurvedAnimation(parent: _controllerEntrada, curve: Curves.easeOutCubic),
    );

    _controllerOrbita = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _controllerTexto = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacidadTexto = CurvedAnimation(parent: _controllerTexto, curve: Curves.easeIn);
    _posicionTexto = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controllerTexto, curve: Curves.easeOutCubic),
    );

    _controllerProgreso = AnimationController(
      vsync: this,
      duration: duracionSplash,
    )..forward();

    _controllerEntrada.forward().whenComplete(() {
      if (mounted) _controllerTexto.forward();
    });

    _navegarSiguientePantalla();
  }

  Future<void> _navegarSiguientePantalla() async {
    await Future.delayed(duracionSplash);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _controllerEntrada.dispose();
    _controllerOrbita.dispose();
    _controllerTexto.dispose();
    _controllerProgreso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo con degradado suave
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4F7FC), Colors.white],
              ),
            ),
          ),

          // Círculos decorativos de fondo, pulsando suavemente
          AnimatedBuilder(
            animation: _controllerOrbita,
            builder: (context, child) {
              final pulso = 1.0 + (math.sin(_controllerOrbita.value * 2 * math.pi) * 0.06);
              return Stack(
                children: [
                  Positioned(top: -50, left: -40, child: Transform.scale(scale: pulso, child: _circulo(150, azul.withOpacity(0.12)))),
                  Positioned(bottom: -60, right: -30, child: Transform.scale(scale: pulso, child: _circulo(170, amarillo.withOpacity(0.15)))),
                  Positioned(top: 80, right: -50, child: Transform.scale(scale: 2 - pulso, child: _circulo(110, rojo.withOpacity(0.1)))),
                  Positioned(bottom: 140, left: -60, child: Transform.scale(scale: 2 - pulso, child: _circulo(120, dorado.withOpacity(0.1)))),
                ],
              );
            },
          ),

          // Contenido central: logo + monedas orbitando + eslogan
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_controllerEntrada, _controllerOrbita]),
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Monedas orbitando alrededor del logo (tema: dinero, crecimiento)
                          if (_controllerEntrada.isCompleted) ..._construirMonedas(),

                          // El logo, con su entrada tipo flip 3D
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(_giroLogo.value)
                              ..scale(_escalaLogo.value),
                            child: Opacity(
                              opacity: _opacidadLogo.value.clamp(0.0, 1.0),
                              child: Image.asset('assets/logo.png', width: 190, fit: BoxFit.contain),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Eslogan animado
                SlideTransition(
                  position: _posicionTexto,
                  child: FadeTransition(
                    opacity: _opacidadTexto,
                    child: Text(
                      'Impulsando a crecer tu negocio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barra de progreso inferior, con degradado, llenándose durante el splash
          Positioned(
            left: 60,
            right: 60,
            bottom: 70,
            child: AnimatedBuilder(
              animation: _controllerProgreso,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 6,
                    color: Colors.grey.shade200,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _controllerProgreso.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [azul, dorado]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Dibuja 4 "moneditas" (ícono $ dentro de un círculo de color) que orbitan
  /// alrededor del logo en un círculo invisible, cada una a su propio ritmo.
  List<Widget> _construirMonedas() {
    final colores = [azul, rojo, amarillo, dorado];
    const radio = 120.0;

    return List.generate(4, (i) {
      final faseInicial = (i / 4) * 2 * math.pi;
      final angulo = faseInicial + (_controllerOrbita.value * 2 * math.pi);
      // Las monedas "respiran" en tamaño mientras orbitan, para que se sientan vivas
      final tamano = 26 + (math.sin(angulo * 2) * 4);

      final x = radio * math.cos(angulo);
      final y = radio * math.sin(angulo) * 0.55; // aplanado, órbita elíptica

      return Transform.translate(
        offset: Offset(x, y),
        child: Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colores[i],
            boxShadow: [BoxShadow(color: colores[i].withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Icon(Icons.attach_money_rounded, color: Colors.white, size: 16),
        ),
      );
    });
  }

  Widget _circulo(double tamano, Color color) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}