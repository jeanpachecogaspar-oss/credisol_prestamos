import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class UbicacionGate extends StatefulWidget {
  final Widget child;
  const UbicacionGate({super.key, required this.child});

  @override
  State<UbicacionGate> createState() => _UbicacionGateState();
}

class _UbicacionGateState extends State<UbicacionGate> with WidgetsBindingObserver {
  static const Color azul = Color(0xFF1E88E5);
  static const Duration _intervalo = Duration(minutes: 2);

  EstadoUbicacion? _estado;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<ServiceStatus>? _servicioSub;
  DateTime? _ultimoGuardado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _servicioSub = Geolocator.getServiceStatusStream().listen((_) => _verificar());
    _verificar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _servicioSub?.cancel();
    _detener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificar();
    } else if (state == AppLifecycleState.paused) {
      _detener(); // solo se rastrea mientras la app está en uso
    }
  }

  Future<void> _verificar() async {
    final estado = await LocationService.estado();
    if (!mounted) return;
    setState(() => _estado = estado);
    if (estado == EstadoUbicacion.ok) {
      _iniciar();
    } else {
      _detener();
    }
  }

  void _iniciar() {
    if (_posSub != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    LocationService.posicionActual().then((p) => _guardar(uid, p)).catchError((_) {});

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((p) => _guardar(uid, p), onError: (_) {});
  }

  void _detener() {
    _posSub?.cancel();
    _posSub = null;
  }

  void _guardar(String uid, Position p) {
    final ahora = DateTime.now();
    if (_ultimoGuardado != null && ahora.difference(_ultimoGuardado!) < _intervalo) return;
    _ultimoGuardado = ahora;
    LocationService.guardar(uid, p).catchError(
      (e) => debugPrint('No se pudo guardar la ubicación: $e'),
    );
  }

  Future<void> _accion(EstadoUbicacion estado) async {
    switch (estado) {
      case EstadoUbicacion.servicioApagado:
        await Geolocator.openLocationSettings();
        break;
      case EstadoUbicacion.denegado:
        await LocationService.solicitar();
        await _verificar();
        break;
      case EstadoUbicacion.denegadoPermanente:
        await Geolocator.openAppSettings();
        break;
      case EstadoUbicacion.ok:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_estado == EstadoUbicacion.ok) return widget.child;
    return _pantallaBloqueo(_estado!);
  }

  Widget _pantallaBloqueo(EstadoUbicacion estado) {
    late final String titulo;
    late final String texto;
    late final String boton;

    switch (estado) {
      case EstadoUbicacion.servicioApagado:
        titulo = 'GPS desactivado';
        texto = 'Necesitamos tu ubicación activa mientras usas la app. Enciende el GPS del celular para continuar.';
        boton = 'Activar GPS';
        break;
      case EstadoUbicacion.denegado:
        titulo = 'Permiso de ubicación';
        texto = 'Debes permitir el acceso a tu ubicación mientras usas la app para poder continuar.';
        boton = 'Permitir ubicación';
        break;
      case EstadoUbicacion.denegadoPermanente:
        titulo = 'Permiso bloqueado';
        texto = 'Activa la ubicación para esta app desde los ajustes del celular y vuelve aquí.';
        boton = 'Abrir ajustes';
        break;
      case EstadoUbicacion.ok:
        titulo = '';
        texto = '';
        boton = '';
        break;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F0FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: azul.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_off_rounded, size: 56, color: azul),
                ),
                const SizedBox(height: 28),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _accion(estado),
                    child: Text(boton),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Cerrar sesión'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Solo usamos tu ubicación mientras la app está abierta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}