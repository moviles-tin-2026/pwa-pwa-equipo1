import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';
import 'movement_form_screen.dart';

/// Módulo 3 — Historial de Movimientos (Ambos roles).
///
/// Bitácora de entradas y salidas con fecha, usuario responsable, tipo de
/// movimiento y cantidad. El botón "Registrar" abre el formulario ágil de
/// entrada/salida con motivo obligatorio.
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  MovementType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final padding = context.pagePadding;
    final movements = _typeFilter == null
        ? repo.movements
        : repo.movements.where((m) => m.type == _typeFilter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MovementFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: PageContainer(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Row(
                children: [
                  SegmentedButton<MovementType?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('Todos')),
                      ButtonSegment(
                        value: MovementType.entry,
                        icon: Icon(Icons.arrow_downward, size: 16),
                        label: Text('Entradas'),
                      ),
                      ButtonSegment(
                        value: MovementType.exit,
                        icon: Icon(Icons.arrow_upward, size: 16),
                        label: Text('Salidas'),
                      ),
                    ],
                    selected: {_typeFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _typeFilter = selection.first),
                  ),
                ],
              ),
            ),
            Expanded(
              child: movements.isEmpty
                  ? const EmptyState(
                      icon: Icons.swap_vert,
                      title: 'Sin movimientos registrados',
                      message:
                          'Registra entradas de compra o salidas por merma.',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(padding, 16, padding, 96),
                      itemCount: movements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _MovementCard(movement: movements[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isEntry = movement.type == MovementType.entry;
    final color = isEntry ? AppTheme.success : AppTheme.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEntry ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movement.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDateTime(movement.date)} · ${movement.userName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isEntry ? '+' : '-'}${movement.quantity}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
