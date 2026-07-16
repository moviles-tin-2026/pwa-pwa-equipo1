import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TabBar(
              labelColor: AppTheme.merlot,
              unselectedLabelColor: AppTheme.mauve,
              indicator: BoxDecoration(
                color: AppTheme.peony,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.point_of_sale_outlined),
                  text: 'Terminal de venta',
                ),
                Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Historial'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [const PosScreen(), const SalesHistoryScreen()],
            ),
          ),
        ],
      ),
    );
  }
}
