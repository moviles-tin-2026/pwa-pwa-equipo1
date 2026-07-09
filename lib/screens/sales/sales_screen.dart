import 'package:flutter/material.dart';

import 'pos_screen.dart';
import 'sales_history_screen.dart';

/// Módulo 4 — Ventas y Facturación.
///
/// Dos pestañas: Terminal de Venta (POS) e Historial de Ventas.
/// El historial cambia según el rol (Admin: completo con cancelación de
/// folios; Operador: ventas del día para arqueo de caja).
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const ColoredBox(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.point_of_sale_outlined),
                  text: 'Terminal de venta',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_outlined),
                  text: 'Historial',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const PosScreen(),
                const SalesHistoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
