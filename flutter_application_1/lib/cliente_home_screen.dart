import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _Cuota {
  final int numero;
  final DateTime fecha;
  final double cuota;
  final double interes;
  final double amortizacion;
  final double saldo;
  const _Cuota(this.numero, this.fecha, this.cuota, this.interes, this.amortizacion, this.saldo);
}

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  static const Color azul = Color(0xFF1E88E5);
  static const Color azulOscuro = Color(0xFF1565C0);
  static const Color dorado = Color(0xFFF2B705);

  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _tasaCtrl = TextEditingController();
  final TextEditingController _plazoCtrl = TextEditingController();

  bool _tasaAnual = true;
  DateTime _fechaInicio = DateTime.now();
  double _montoSolicitado = 0;
  List<_Cuota> _cronograma = [];

  @override
  void dispose() {
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _plazoCtrl.dispose();
    super.dispose();
  }

  // ---------- Cálculo ----------

  double _r(double v) => (v * 100).roundToDouble() / 100;

  DateTime _sumarMeses(DateTime f, int meses) {
    final total = f.month - 1 + meses;
    final anio = f.year + total ~/ 12;
    final mes = total % 12 + 1;
    final ultimoDia = DateTime(anio, mes + 1, 0).day;
    return DateTime(anio, mes, f.day > ultimoDia ? ultimoDia : f.day);
  }

  void _calcular() {
    FocusScope.of(context).unfocus();

    final monto = double.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
    final tasa = double.tryParse(_tasaCtrl.text.trim().replaceAll(',', '.'));
    final plazo = int.tryParse(_plazoCtrl.text.trim());

    if (monto == null || monto <= 0 || tasa == null || tasa < 0 || plazo == null || plazo < 1 || plazo > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los datos: monto y tasa válidos, plazo de 1 a 120 meses')),
      );
      return;
    }

    // Tasa mensual: si ingresó TEA se convierte, si ingresó mensual se usa directo
    final i = _tasaAnual ? math.pow(1 + tasa / 100, 1 / 12).toDouble() - 1 : tasa / 100;

    // Cuota fija (sistema francés)
    final cuotaFija = _r(
      i == 0 ? monto / plazo : monto * i / (1 - math.pow(1 + i, -plazo).toDouble()),
    );

    final lista = <_Cuota>[];
    var saldo = monto;
    for (var n = 1; n <= plazo; n++) {
      final interes = _r(saldo * i);
      final esUltima = n == plazo;
      final amort = esUltima ? saldo : _r(cuotaFija - interes);
      final cuota = _r(amort + interes);
      saldo = esUltima ? 0.0 : _r(saldo - amort);
      lista.add(_Cuota(n, _sumarMeses(_fechaInicio, n), cuota, interes, amort, saldo));
    }

    setState(() {
      _montoSolicitado = monto;
      _cronograma = lista;
    });
  }

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (f == null) return;
    setState(() => _fechaInicio = f);
    if (_cronograma.isNotEmpty) _calcular();
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  // ---------- Formato ----------

  String _fmt(double v) {
    final partes = v.toStringAsFixed(2).split('.');
    final entero = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '$entero.${partes[1]}';
  }

  String _money(double v) => 'S/ ${_fmt(v)}';

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  double get _totalInteres => _cronograma.fold(0.0, (s, c) => s + c.interes);
  double get _totalPagar => _cronograma.fold(0.0, (s, c) => s + c.cuota);

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _encabezado(email),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  _tarjetaFormulario(),
                  if (_cronograma.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _tarjetaResumen(),
                    const SizedBox(height: 20),
                    _tarjetaCronograma(),
                    const SizedBox(height: 12),
                    Text(
                      'Cálculo referencial con cuotas fijas (sistema francés). No incluye seguros ni comisiones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(String email) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [azul, azulOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/logo.png', height: 30, fit: BoxFit.contain),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Simula tu préstamo',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: azul.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _deco(String label, IconData icono, {String? prefijo}) {
    return InputDecoration(
      prefixIcon: Icon(icono, color: azul, size: 20),
      prefixText: prefijo,
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: azul, width: 1.5),
      ),
    );
  }

  Widget _campo(TextEditingController c, String label, IconData icono, {String? prefijo, bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
      decoration: _deco(label, icono, prefijo: prefijo),
    );
  }

  Widget _tarjetaFormulario() {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos del préstamo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _campo(_montoCtrl, 'Monto del préstamo', Icons.payments_outlined, prefijo: 'S/ ', decimal: true),
          const SizedBox(height: 16),
          _campo(_tasaCtrl, 'Tasa de interés (%)', Icons.percent_rounded, decimal: true),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Anual (TEA)')),
                ButtonSegment(value: false, label: Text('Mensual')),
              ],
              selected: {_tasaAnual},
              onSelectionChanged: (s) => setState(() => _tasaAnual = s.first),
            ),
          ),
          const SizedBox(height: 16),
          _campo(_plazoCtrl, 'Plazo (meses)', Icons.calendar_month_outlined),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _elegirFecha,
            child: InputDecorator(
              decoration: _deco('Fecha de desembolso', Icons.event_outlined),
              child: Text(_fecha(_fechaInicio), style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _calcular,
              style: ElevatedButton.styleFrom(
                backgroundColor: azul,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Calcular cronograma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [azul, azulOscuro]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cuota mensual', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                _money(_cronograma.first.cuota),
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_cronograma.length} cuotas',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _mini('Monto', _money(_montoSolicitado), azul)),
            const SizedBox(width: 10),
            Expanded(child: _mini('Intereses', _money(_totalInteres), const Color(0xFFE53935))),
            const SizedBox(width: 10),
            Expanded(child: _mini('Total a pagar', _money(_totalPagar), dorado)),
          ],
        ),
      ],
    );
  }

  Widget _mini(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCronograma() {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cronograma de pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 22,
              headingRowHeight: 44,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF2FD)),
              columns: const [
                DataColumn(label: Text('N°', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Cuota', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Interés', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Amortiz.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: [
                ..._cronograma.map(
                  (c) => DataRow(cells: [
                    DataCell(Text('${c.numero}')),
                    DataCell(Text(_fecha(c.fecha))),
                    DataCell(Text(_fmt(c.cuota))),
                    DataCell(Text(_fmt(c.interes))),
                    DataCell(Text(_fmt(c.amortizacion))),
                    DataCell(Text(_fmt(c.saldo))),
                  ]),
                ),
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xFFFFF8E1)),
                  cells: [
                    const DataCell(Text('')),
                    const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(_fmt(_totalPagar), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(_fmt(_totalInteres), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(_fmt(_montoSolicitado), style: const TextStyle(fontWeight: FontWeight.bold))),
                    const DataCell(Text('')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}