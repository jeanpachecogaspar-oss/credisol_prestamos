import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'formato.dart';
import 'ui_comun.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _prestamos;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _clientes;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _porVerificar;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    _prestamos = db.collection('prestamos').snapshots();
    _clientes = db.collection('usuarios').where('rol', isEqualTo: 'cliente').snapshots();
    _porVerificar = db.collection('pagos').where('estado', isEqualTo: 'Por verificar').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _prestamos,
        builder: (context, sp) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _clientes,
            builder: (context, sc) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _porVerificar,
                builder: (context, sv) {
                  final error = sp.error ?? sc.error ?? sv.error;
                  if (error != null) {
                    return mensajeVacio(
                      Icons.lock_outline_rounded,
                      'Firestore no dejó cargar los datos',
                      '$error\n\nRevisa que tu usuario tenga rol "admin" y que las reglas estén publicadas.',
                    );
                  }

                  int pendientes = 0;
                  int activos = 0;
                  double capital = 0;
                  double porCobrar = 0;
                  for (final d in sp.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                    final p = d.data();
                    final e = p['estado'];
                    if (e == 'Pendiente') pendientes++;
                    if (e == 'Activo') {
                      activos++;
                      porCobrar += aNum(p['saldoPendiente']);
                    }
                    if (e == 'Activo' || e == 'Pagado') capital += aNum(p['monto']);
                  }
                  final totalClientes = sc.data?.docs.length ?? 0;
                  final pagosPorVerificar = sv.data?.docs.length ?? 0;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.azul, AppColors.azulOscuro]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _grande('Capital prestado', fmtMoney(capital))),
                            Expanded(child: _grande('Por cobrar', fmtMoney(porCobrar))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          _tile('Clientes', '$totalClientes', Icons.people_alt_rounded, AppColors.azul),
                          _tile('Solicitudes pendientes', '$pendientes', Icons.inbox_rounded, const Color(0xFFB38600)),
                          _tile('Préstamos activos', '$activos', Icons.account_balance_wallet_rounded, AppColors.verde),
                          _tile('Pagos por verificar', '$pagosPorVerificar', Icons.payments_rounded, AppColors.rojo),
                        ],
                      ),
                      if (!sp.hasData || !sc.hasData || !sv.hasData) ...[
                        const SizedBox(height: 20),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _grande(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _tile(String titulo, String valor, IconData icono, Color color) {
    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icono, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}