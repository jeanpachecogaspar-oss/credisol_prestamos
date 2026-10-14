import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'config_pagos.dart';
import 'formato.dart';

const Color _azul = Color(0xFF1E88E5);
const Color _rojo = Color(0xFFE53935);
const Color _verde = Color(0xFF2E9E6B);
const Color _ambar = Color(0xFFB38600);
const Color _gris = Color(0xFF6B7A90);

Color colorEstado(String e) {
  switch (e) {
    case 'Activo':
      return _azul;
    case 'Pagado':
    case 'Pagada':
      return _verde;
    case 'Rechazado':
    case 'Vencida':
      return _rojo;
    case 'Pendiente':
      return _ambar;
    case 'Por verificar':
      return _ambar;
    default:
      return _gris;
  }
}

DateTime _aFecha(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
double _aNum(dynamic v) => (v as num?)?.toDouble() ?? 0;

Widget _chip(String texto, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      texto,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

Widget _banner(String texto, Color color, IconData icono) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

// ==================== LISTA ====================
class MisPrestamosScreen extends StatelessWidget {
  const MisPrestamosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis préstamos')),
      body: uid == null
          ? const SizedBox()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('prestamos')
                  .where('clienteId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar tus préstamos.\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs.toList()
                  ..sort((a, b) => _aFecha(b.data()['fechaSolicitud'])
                      .compareTo(_aFecha(a.data()['fechaSolicitud'])));

                if (docs.isEmpty) return _vacio();

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _tarjeta(context, docs[i]),
                );
              },
            ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes préstamos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Simula tu préstamo en la pestaña Simular y envía tu solicitud.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final p = doc.data();
    final estado = (p['estado'] ?? 'Pendiente').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetallePrestamoCliente(prestamoId: doc.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _azul.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  fmtMoney(_aNum(p['monto'])),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _chip(estado, colorEstado(estado)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cuota ${fmtMoney(_aNum(p['cuotaMensual']))} • ${p['plazoMeses']} meses',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (estado == 'Activo') ...[
              const SizedBox(height: 4),
              Text(
                'Saldo pendiente: ${fmtMoney(_aNum(p['saldoPendiente']))}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Ver cronograma',
                    style: TextStyle(
                      color: _azul,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _azul,
                    size: 20,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== DETALLE + CRONOGRAMA ====================
class DetallePrestamoCliente extends StatelessWidget {
  final String prestamoId;
  const DetallePrestamoCliente({super.key, required this.prestamoId});

  @override
  Widget build(BuildContext context) {
    final ref =
        FirebaseFirestore.instance.collection('prestamos').doc(prestamoId);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del préstamo')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapP) {
          if (!snapP.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snapP.data!.data();
          if (p == null) {
            return const Center(child: Text('Préstamo no encontrado'));
          }
          final estado = (p['estado'] ?? 'Pendiente').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref.collection('cuotas').orderBy('numero').snapshots(),
            builder: (context, snapC) {
              final cuotas = snapC.data?.docs ?? [];
              final pagadas =
                  cuotas.where((d) => d.data()['estado'] == 'Pagada').length;
              final siguiente = cuotas.indexWhere(
                (d) => (d.data()['estado'] ?? 'Pendiente') == 'Pendiente',
              );

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _resumen(p, estado),
                  const SizedBox(height: 14),
                  if (estado == 'Pendiente')
                    _banner(
                      'Tu solicitud está en revisión. Este cronograma es referencial hasta que sea aprobada.',
                      _ambar,
                      Icons.hourglass_top_rounded,
                    ),
                  if (estado == 'Rechazado')
                    _banner(
                      'Tu solicitud fue rechazada. Puedes simular y enviar una nueva.',
                      _rojo,
                      Icons.cancel_outlined,
                    ),
                  if (estado == 'Pagado')
                    _banner(
                      '¡Pagaste este préstamo por completo!',
                      _verde,
                      Icons.check_circle_outline,
                    ),
                  if ((estado == 'Activo' || estado == 'Pagado') &&
                      cuotas.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '$pagadas de ${cuotas.length} cuotas pagadas',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: cuotas.isEmpty ? 0 : pagadas / cuotas.length,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: _verde,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Cronograma de pagos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (snapC.connectionState == ConnectionState.waiting &&
                      cuotas.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (var i = 0; i < cuotas.length; i++)
                      _filaCuota(
                        context,
                        cuotas[i],
                        puedePagar: estado == 'Activo' && i == siguiente,
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _resumen(Map<String, dynamic> p, String estado) {
    final tasaTxt =
        '${p['tasa']}% ${p['tasaAnual'] == true ? 'anual (TEA)' : 'mensual'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_azul, Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Monto del préstamo',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fmtMoney(_aNum(p['monto'])),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dato('Cuota', fmtMoney(_aNum(p['cuotaMensual']))),
              ),
              Expanded(
                child: _dato('Plazo', '${p['plazoMeses']} meses'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dato('Tasa', tasaTxt)),
              Expanded(
                child: _dato('Total a pagar', fmtMoney(_aNum(p['totalAPagar']))),
              ),
            ],
          ),
          if (estado == 'Activo') ...[
            const SizedBox(height: 12),
            _dato('Saldo pendiente', fmtMoney(_aNum(p['saldoPendiente']))),
          ],
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _filaCuota(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool puedePagar,
  }) {
    final c = doc.data();
    final fecha = _aFecha(c['fecha']);
    final hoy = DateTime.now();
    final base = (c['estado'] ?? 'Pendiente').toString();
    final vencida = base == 'Pendiente' &&
        DateTime(fecha.year, fecha.month, fecha.day).isBefore(
          DateTime(hoy.year, hoy.month, hoy.day),
        );
    final etiqueta = vencida ? 'Vencida' : base;
    final color = colorEstado(etiqueta);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              '${c['numero']}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmtMoney(_aNum(c['cuota'])),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vence ${fmtFecha(fecha)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                Text(
                  'Interés ${fmtNum(_aNum(c['interes']))} Capital ${fmtNum(_aNum(c['amortizacion']))}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _chip(etiqueta, color),
              if (puedePagar) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => mostrarPagar(context, doc),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    backgroundColor: _azul,
                  ),
                  child: const Text('Pagar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== PAGAR ====================
Future<void> mostrarPagar(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> cuotaDoc,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => PagarSheet(cuotaDoc: cuotaDoc),
  );
}

class PagarSheet extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> cuotaDoc;
  const PagarSheet({super.key, required this.cuotaDoc});

  @override
  State<PagarSheet> createState() => PagarSheetState();
}

class PagarSheetState extends State<PagarSheet> {
  final TextEditingController _opCtrl = TextEditingController();
  String _medio = 'Yape';
  bool enviando = false;

  @override
  void dispose() {
    _opCtrl.dispose();
    super.dispose();
  }

  Future<void> copiar(String texto, String que) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$que copiado')),
    );
  }

  Future<void> abrirYape() async {
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: 'com.bcp.innovacxion.yapeapp',
    );
    try {
      if (await intent.canResolveActivity() ?? false) {
        await intent.launch();
        return;
      }
    } catch (_) {}
    await launchUrl(
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.bcp.innovacxion.yapeapp',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> enviar() async {
    final op = _opCtrl.text.trim();
    if (op.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el número de operación de tu pago')),
      );
      return;
    }
    setState(() => enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final cuotaRef = widget.cuotaDoc.reference;
      final prestamoRef = cuotaRef.parent.parent!;
      final prestamo = await prestamoRef.get();
      final datos = prestamo.data() ?? {};
      final cuotaDatos = widget.cuotaDoc.data();
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.update(cuotaRef, {
        'estado': 'Por verificar',
        'medioPago': _medio,
        'numeroOperacion': op,
        'fechaPago': FieldValue.serverTimestamp(),
      });

      batch.set(db.collection('pagos').doc(), {
        'prestamoId': prestamoRef.id,
        'cuotaId': cuotaRef.id,
        'numeroCuota': cuotaDatos['numero'],
        'clienteId': datos['clienteId'],
        'clienteNombre': datos['clienteNombre'],
        'monto': cuotaDatos['cuota'],
        'medio': _medio,
        'numeroOperacion': op,
        'estado': 'Por verificar',
        'fechaReporte': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Constancia enviada. Verificaremos tu pago pronto.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Widget _dato(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: () => copiar(valor, titulo),
            icon: const Icon(Icons.copy_rounded, size: 20, color: _azul),
          ),
        ],
      ),
    );
  }

  Widget infoMedio() {
    switch (_medio) {
      case 'Yape':
        return Column(
          children: [
            _dato('Número Yape', ConfigPagos.yapeNumero),
            _dato('Titular', ConfigPagos.titular),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: abrirYape,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF742284),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Abrir Yape'),
              ),
            ),
          ],
        );
      case 'Plin':
        return Column(
          children: [
            _dato('Número Plin', ConfigPagos.plinNumero),
            _dato('Titular', ConfigPagos.titular),
            const SizedBox(height: 6),
            Text(
              'Abre la app de tu banco (BCP, Interbank, BBVA, Scotiabank), elige Plin y paga a este número.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        );
      default:
        return Column(
          children: [
            _dato('Banco', ConfigPagos.banco),
            _dato('Cuenta', ConfigPagos.cuenta),
            _dato('CCI', ConfigPagos.cci),
            _dato('Titular', ConfigPagos.titular),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cuotaDoc.data();
    final monto = _aNum(c['cuota']);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pagar cuota ${c['numero']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Vence ${fmtFecha(_aFecha(c['fecha']))}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  fmtMoney(monto),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _azul,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => copiar(monto.toStringAsFixed(2), 'Monto'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar monto'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['Yape', 'Plin', 'Transferencia']
                  .map(
                    (m) => ChoiceChip(
                      label: Text(m),
                      selected: _medio == m,
                      onSelected: (_) => setState(() => _medio = m),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: infoMedio(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Después de pagar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _opCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'N° de operación',
                prefixIcon: Icon(Icons.receipt_long_outlined, color: _azul),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: enviando ? null : enviar,
                child: enviando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text('Ya pagué, enviar constancia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}