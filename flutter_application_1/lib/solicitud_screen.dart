import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cronograma.dart';
import 'formato.dart';
import 'navegacion_cliente.dart';

class SolicitudScreen extends StatefulWidget {
  final double monto;
  final double tasa;
  final bool tasaAnual;
  final int plazo;
  final DateTime fechaInicio;

  const SolicitudScreen({
    super.key,
    required this.monto,
    required this.tasa,
    required this.tasaAnual,
    required this.plazo,
    required this.fechaInicio,
  });

  @override
  State<SolicitudScreen> createState() => _SolicitudScreenState();
}

class _SolicitudScreenState extends State<SolicitudScreen> {
  static const Color azul = Color(0xFF1E88E5);

  final TextEditingController _destinoCtrl = TextEditingController();
  late final List<CuotaCalc> _cuotas;
  bool _acepto = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cuotas = generarCronograma(
      monto: widget.monto,
      tasa: widget.tasa,
      tasaAnual: widget.tasaAnual,
      plazo: widget.plazo,
      fechaInicio: widget.fechaInicio,
    );
  }

  @override
  void dispose() {
    _destinoCtrl.dispose();
    super.dispose();
  }

  double get _total => _cuotas.fold(0.0, (s, c) => s + c.cuota);
  double get _intereses => _cuotas.fold(0.0, (s, c) => s + c.interes);

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _enviar() async {
    if (!_acepto) {
      _msg('Confirma que los datos son correctos para continuar');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final db = FirebaseFirestore.instance;

      final pendientes = await db
          .collection('prestamos')
          .where('clienteId', isEqualTo: user.uid)
          .where('estado', isEqualTo: 'Pendiente')
          .limit(1)
          .get();
      if (pendientes.docs.isNotEmpty) {
        _msg('Ya tienes una solicitud en revisión. Espera su respuesta.');
        return;
      }

      final perfil = await db.collection('usuarios').doc(user.uid).get();
      final nombre = (perfil.data()?['nombre'] ?? user.email ?? '').toString();

      final ref = db.collection('prestamos').doc();
      final batch = db.batch();

      batch.set(ref, {
        'clienteId': user.uid,
        'clienteNombre': nombre,
        'clienteEmail': user.email,
        'monto': widget.monto,
        'tasa': widget.tasa,
        'tasaAnual': widget.tasaAnual,
        'plazoMeses': widget.plazo,
        'fechaDesembolso': Timestamp.fromDate(widget.fechaInicio),
        'cuotaMensual': _cuotas.first.cuota,
        'totalAPagar': _total,
        'totalIntereses': _intereses,
        'saldoPendiente': _total,
        'destino': _destinoCtrl.text.trim(),
        'estado': 'Pendiente',
        'fechaSolicitud': FieldValue.serverTimestamp(),
      });

      for (final c in _cuotas) {
        batch.set(ref.collection('cuotas').doc(c.numero.toString().padLeft(3, '0')), {
          'numero': c.numero,
          'fecha': Timestamp.fromDate(c.fecha),
          'cuota': c.cuota,
          'interes': c.interes,
          'amortizacion': c.amortizacion,
          'saldo': c.saldo,
          'estado': 'Pendiente',
        });
      }

      await batch.commit();

      if (!mounted) return;
      tabCliente.value = 1; // ir a "Mis préstamos"
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Un administrador la revisará pronto.')),
      );
    } catch (e) {
      _msg('No se pudo enviar la solicitud: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar préstamo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: azul.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                _fila('Monto solicitado', fmtMoney(widget.monto), destacado: true),
                _fila('Tasa', '${widget.tasa}% ${widget.tasaAnual ? 'anual (TEA)' : 'mensual'}'),
                _fila('Plazo', '${widget.plazo} meses'),
                _fila('Cuota mensual', fmtMoney(_cuotas.first.cuota)),
                _fila('Intereses totales', fmtMoney(_intereses)),
                _fila('Total a pagar', fmtMoney(_total), destacado: true),
                _fila('Primera cuota vence', fmtFecha(_cuotas.first.fecha)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _destinoCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '¿Para qué usarás el préstamo? (opcional)',
              prefixIcon: Icon(Icons.edit_note_rounded, color: azul),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
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
                      'Confirmo que los datos son correctos y entiendo que el préstamo está sujeto a aprobación.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                    )
                  : const Text('Enviar solicitud'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(String titulo, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
          Text(
            valor,
            style: TextStyle(
              fontSize: destacado ? 17 : 15,
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              color: destacado ? azul : null,
            ),
          ),
        ],
      ),
    );
  }
}