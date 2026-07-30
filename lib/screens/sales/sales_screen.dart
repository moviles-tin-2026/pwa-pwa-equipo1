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
              // indicatorSize.tab + padding cero: el fondo rosa cubre la
              // celda completa de la pestaña, no solo el ícono/texto.
              // splashBorderRadius y overlayColor evitan que el hover/
              // splash por defecto de Material dibuje una forma distinta
              // (rectangular) encima del indicador redondeado.
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.zero,
              dividerColor: Colors.transparent,
              splashBorderRadius: const BorderRadius.all(Radius.circular(14)),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return AppTheme.peony.withValues(alpha: 0.55);
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppTheme.peony.withValues(alpha: 0.3);
                }
                return Colors.transparent;
              }),
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
