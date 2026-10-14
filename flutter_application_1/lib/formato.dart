String fmtNum(double v) {
  final partes = v.toStringAsFixed(2).split('.');
  final entero = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$entero.${partes[1]}';
}

String fmtMoney(double v) => 'S/ ${fmtNum(v)}';

String fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';