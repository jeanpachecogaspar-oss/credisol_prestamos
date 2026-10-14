import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'formato.dart';
import 'ui_comun.dart';

class CobranzasScreen extends StatefulWidget {
  const CobranzasScreen({super.key});

  @override
  State<CobranzasScreen> createState() => _CobranzasScreenState();
}

class _CobranzasScreenState extends State<CobranzasScreen> {
  static const List<(String, String)> _filtros = [
    ('Por verificar', 'Por verificar'),
    ('Confirmado', 'Confirmados'),
    ('Rechazado', 'Rechazados'),
  ];

  String _estado = 'Por verificar';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _crearStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _crearStream() => FirebaseFirestore.instance
      .collection('pagos')
      .where('estado', isEqualTo: _estado)
      .snapshots();

  void _cambiar(String estado) {
    setState(() {
      _estado = estado;
      _stream = _crearStream();
    });
  }

  Future<void> _confirmar(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final p = doc.data();

    final ok = await confirmar(
      context,
      'Confirmar pago',
      'Verifica en tu Yape o banco que llegó ${fmtMoney(aNum(p['monto']))} con la operación ${p['numeroOperacion']}.',
      'Confirmar',
    );
    if (!ok) return;

    try {
      final db = FirebaseFirestore.instance;
      final prestamoRef = db.collection('prestamos').doc(p['prestamoId'].toString());
      final cuotaRef = prestamoRef.collection('cuotas').doc(p['cuotaId'].toString());
      final monto = aNum(p['monto']);

      // ¿Quedan otras cuotas sin pagar en este préstamo?
      final noPagadas = await prestamoRef.collection('cuotas').where('estado', isNotEqualTo: 'Pagada').get();
      final quedan = noPagadas.docs.where((d) => d.id != cuotaRef.id).length;

      final batch = db.batch();
      batch.update(doc.reference, {
        'estado': 'Confirmado',
        'fechaConfirmacion': FieldValue.serverTimestamp(),
        'confirmadoPor': FirebaseAuth.instance.currentUser?.uid,
      });
      batch.update(cuotaRef, {'estado': 'Pagada'});
      batch.update(
        prestamoRef,
        quedan == 0
            ? {'saldoPendiente': 0, 'estado': 'Pagado'}
            : {'saldoPendiente': FieldValue.increment(-monto)},
      );
      await batch.commit();

      messenger.showSnackBar(SnackBar(
        content: Text(quedan == 0 ? 'Pago confirmado. ¡Préstamo pagado por completo!' : 'Pago confirmado'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo confirmar: $e')));
    }
  }

  Future<void> _rechazar(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final motivo = await pedirMotivo(context, 'Rechazar pago');
    if (motivo == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final p = doc.data();
      final cuotaRef = db
          .collection('prestamos')
          .doc(p['prestamoId'].toString())
          .collection('cuotas')
          .doc(p['cuotaId'].toString());

      final batch = db.batch();
      batch.update(doc.reference, {
        'estado': 'Rechazado',
        'motivoRechazo': motivo,
        'fechaRechazo': FieldValue.serverTimestamp(),
        'rechazadoPor': FirebaseAuth.instance.currentUser?.uid,
      });
      // La cuota vuelve a quedar pendiente para que el cliente pague de nuevo
      batch.update(cuotaRef, {'estado': 'Pendiente', 'motivoRechazoPago': motivo});
      await batch.commit();

      messenger.showSnackBar(const SnackBar(content: Text('Pago rechazado. La cuota volvió a pendiente.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo rechazar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobranzas')),
      body: Column(
        children: [
          filtroChips(opciones: _filtros, actual: _estado, onChanged: _cambiar),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return mensajeVacio(Icons.error_outline_rounded, 'No se pudieron cargar los pagos', '${snap.error}');
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs.toList()
                  ..sort((a, b) => (aFecha(b.data()['fechaReporte']) ?? DateTime.now())
                      .compareTo(aFecha(a.data()['fechaReporte']) ?? DateTime.now()));

                if (docs.isEmpty) {
                  return mensajeVacio(Icons.payments_outlined, 'No hay pagos en este estado', 'Cuando un cliente reporte un pago, aparecerá aquí.');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _tarjeta(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final p = doc.data();
    final estado = (p['estado'] ?? '').toString();
    final fecha = aFecha(p['fechaReporte']);
    final operacion = (p['numeroOperacion'] ?? '').toString();

    return tarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((p['clienteNombre'] ?? 'Sin nombre').toString(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              chipEstado(estado),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cuota ${p['numeroCuota']} · ${fmtMoney(aNum(p['monto']))}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azul),
          ),
          const SizedBox(height: 8),
          filaDato('Medio', (p['medio'] ?? '—').toString()),
          Row(
            children: [
              Expanded(child: filaDato('N° operación', operacion.isEmpty ? '—' : operacion)),
              if (operacion.isNotEmpty)
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.azul),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: operacion));
                    messenger.showSnackBar(const SnackBar(content: Text('Operación copiada')));
                  },
                ),
            ],
          ),
          if (fecha != null) filaDato('Reportado', fechaHora(fecha)),
          if (estado == 'Rechazado' && (p['motivoRechazo'] ?? '').toString().isNotEmpty)
            filaDato('Motivo', p['motivoRechazo'].toString()),
          if (estado == 'Por verificar') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rechazar(doc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rojo,
                      side: const BorderSide(color: AppColors.rojo),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmar(doc),
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}