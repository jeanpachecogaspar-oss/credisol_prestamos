import 'package:flutter/material.dart';
import 'cliente_home_screen.dart';
import 'mis_prestamos_screen.dart';
import 'navegacion_cliente.dart';

class ClienteShell extends StatefulWidget {
  const ClienteShell({super.key});

  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> {
  static const Color azul = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    tabCliente.value = 0;
    tabCliente.addListener(_cambio);
  }

  void _cambio() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tabCliente.removeListener(_cambio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tabCliente.value,
        children: const [
          ClienteHomeScreen(),
          MisPrestamosScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabCliente.value,
        onDestinationSelected: (i) => tabCliente.value = i,
        backgroundColor: Colors.white,
        indicatorColor: azul.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded, color: azul),
            label: 'Simular',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: azul),
            label: 'Mis préstamos',
          ),
        ],
      ),
    );
  }
}