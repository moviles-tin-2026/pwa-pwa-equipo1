import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

/// Módulo 4 — Historial de Ventas.
///
/// - Vista Admin: listado completo con detalles financieros y opción de
///   cancelación de folios (restaura el inventario).
/// - Vista Operador: ventas del día actual para el arqueo de caja.
class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final isAdmin = context.watch<AuthService>().isAdmin;
    final padding = context.pagePadding;

    final sales = isAdmin ? repo.sales : repo.salesOfToday();
    final activeSales = sales.where((s) => !s.cancelled).toList();
    final total =
        activeSales.fold<double>(0, (sum, s) => sum + s.total);

    return PageContainer(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdmin
                                ? 'Ingresos totales (histórico)'
                                : 'Total del turno (hoy)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(total),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${activeSales.length} venta(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isAdmin)
                          Text(
                            '${sales.where((s) => s.cancelled).length} cancelada(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: sales.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: isAdmin
                        ? 'Sin ventas registradas'
                        : 'Aún no hay ventas hoy',
                    message: 'Las ventas del POS aparecerán aquí.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
                    itemCount: sales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SaleCard(
                      sale: sales[index],
                      isAdmin: isAdmin,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.isAdmin});

  final Sale sale;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final methodIcon = switch (sale.paymentMethod) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.card => Icons.credit_card,
      PaymentMethod.transfer => Icons.swap_horiz,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSaleDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (sale.cancelled ? AppTheme.danger : AppTheme.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  sale.cancelled ? Icons.cancel_outlined : Icons.receipt,
                  color: sale.cancelled ? AppTheme.danger : AppTheme.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sale.folio,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            decoration: sale.cancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (sale.cancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Cancelada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sale.itemCount} artículo(s) · ${formatDateTime(sale.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Atendió: ${sale.userName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(sale.total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: sale.cancelled
                          ? Colors.grey
                          : AppTheme.brandNavy,
                      decoration: sale.cancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(methodIcon, size: 18, color: Colors.grey.shade500),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Desplazable y con altura máxima: ventas con muchas líneas hacen
      // scroll en lugar de desbordar en pantallas bajas.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Venta ${sale.folio}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    formatDateTime(sale.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final item in sale.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}×',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(formatCurrency(item.subtotal)),
                    ],
                  ),
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pago: ${sale.paymentMethod.label}'),
                  Text(
                    'Total: ${formatCurrency(sale.total)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (isAdmin && !sale.cancelled) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _confirmCancel(context);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar folio'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    final repo = context.read<InventoryRepository>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancelar folio ${sale.folio}'),
        content: const Text(
          'La venta se marcará como cancelada y los productos '
          'regresarán al inventario. Esta acción queda auditada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await repo.cancelSale(sale.id);
              if (!context.mounted) return;
              showSuccessSnackBar(
                context,
                'Folio ${sale.folio} cancelado; stock restaurado',
              );
            },
            child: const Text('Cancelar venta'),
          ),
        ],
      ),
    );
  }
}
