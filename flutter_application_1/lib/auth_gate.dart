import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'cliente_shell.dart';
import 'ubicacion_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Cargando();
        }

        final user = authSnap.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
          builder: (context, docSnap) {
            if (docSnap.connectionState == ConnectionState.waiting) {
              return const _Cargando();
            }
            if (docSnap.hasError) {
              debugPrint('AuthGate: error leyendo el rol: ${docSnap.error}');
            }

            final rol = (docSnap.data?.data()?['rol'] ?? 'cliente').toString().toLowerCase().trim();
            debugPrint('AuthGate -> uid: ${user.uid} | rol: "$rol"');

            final esAdmin = rol == 'admin' || rol == 'administrador';
            if (esAdmin) return const HomeScreen();

            // Cliente: GPS obligatorio mientras usa la app
            return const UbicacionGate(child: ClienteShell());
          },
        );
      },
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}