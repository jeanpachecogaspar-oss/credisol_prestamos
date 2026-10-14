import 'package:flutter/foundation.dart';

/// Pestaña activa del cliente: 0 = Simular, 1 = Mis préstamos
final ValueNotifier<int> tabCliente = ValueNotifier<int>(0);