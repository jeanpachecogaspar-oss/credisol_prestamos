import 'dart:math' as math;

class CuotaCalc {
  final int numero;
  final DateTime fecha;
  final double cuota;
  final double interes;
  final double amortizacion;
  final double saldo;
  const CuotaCalc(this.numero, this.fecha, this.cuota, this.interes, this.amortizacion, this.saldo);
}

double _r(double v) => (v * 100).roundToDouble() / 100;

DateTime sumarMeses(DateTime f, int meses) {
  final total = f.month - 1 + meses;
  final anio = f.year + total ~/ 12;
  final mes = total % 12 + 1;
  final ultimoDia = DateTime(anio, mes + 1, 0).day;
  return DateTime(anio, mes, f.day > ultimoDia ? ultimoDia : f.day);
}

List<CuotaCalc> generarCronograma({
  required double monto,
  required double tasa,
  required bool tasaAnual,
  required int plazo,
  required DateTime fechaInicio,
}) {
  final i = tasaAnual ? math.pow(1 + tasa / 100, 1 / 12).toDouble() - 1 : tasa / 100;

  final cuotaFija = _r(
    i == 0 ? monto / plazo : monto * i / (1 - math.pow(1 + i, -plazo).toDouble()),
  );

  final lista = <CuotaCalc>[];
  var saldo = monto;
  for (var n = 1; n <= plazo; n++) {
    final interes = _r(saldo * i);
    final esUltima = n == plazo;
    final amort = esUltima ? saldo : _r(cuotaFija - interes);
    final cuota = _r(amort + interes);
    saldo = esUltima ? 0.0 : _r(saldo - amort);
    lista.add(CuotaCalc(n, sumarMeses(fechaInicio, n), cuota, interes, amort, saldo));
  }
  return lista;
}