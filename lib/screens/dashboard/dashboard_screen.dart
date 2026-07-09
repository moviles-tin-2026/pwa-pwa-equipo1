import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

/// Módulo 1 — Panel de Control.
///
/// - Vista Admin: métricas globales (ventas del mes, valor del inventario
///   a costo y a precio de venta, margen de utilidad), gráfico de ventas
///   mensuales, productos más vendidos y alertas críticas de stock.
/// - Vista Operador: accesos rápidos a Nueva Venta y Registrar Entrada,
///   resumen operativo del día y alertas de stock bajo.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final void Function(AppSection section) onNavigate;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;
    return isAdmin
        ? _AdminDashboard(onNavigate: onNavigate)
        : _OperatorDashboard(onNavigate: onNavigate);
  }
}

// ---------------------------------------------------------------------------
// Vista Administrador
// ---------------------------------------------------------------------------

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.onNavigate});

  final void Function(AppSection section) onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final padding = context.pagePadding;
    final isMobile = context.isMobile;

    final kpis = [
      KpiCard(
        title: 'Ventas del mes',
        value: formatCurrency(repo.monthSalesTotal),
        icon: Icons.trending_up,
        color: AppTheme.success,
      ),
      KpiCard(
        title: 'Inventario a costo',
        value: formatCurrency(repo.inventoryValueAtCost),
        icon: Icons.warehouse_outlined,
        color: AppTheme.brandNavy,
      ),
      KpiCard(
        title: 'Inventario a precio de venta',
        value: formatCurrency(repo.inventoryValueAtSale),
        icon: Icons.sell_outlined,
        color: AppTheme.brandBlue,
      ),
      KpiCard(
        title: 'Margen de utilidad',
        value: '${repo.profitMarginPercent.toStringAsFixed(1)}%',
        icon: Icons.percent,
        color: AppTheme.warning,
      ),
    ];

    return PageContainer(
      child: ListView(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
        children: [
          GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 1.35 : 1.6,
            children: kpis,
          ),
          const SizedBox(height: 20),
          if (context.isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _SalesChartCard(repo: repo)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _TopProductsCard(repo: repo)),
              ],
            )
          else ...[
            _SalesChartCard(repo: repo),
            const SizedBox(height: 16),
            _TopProductsCard(repo: repo),
          ],
          const SizedBox(height: 16),
          _LowStockCard(
            repo: repo,
            onSeeInventory: () => onNavigate(AppSection.inventory),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de barras de ventas mensuales (sin dependencias externas).
class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.repo});

  final InventoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final data = repo.monthlySales();
    final maxTotal = data.fold<double>(
      0,
      (max, d) => d.total > max ? d.total : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Ventas mensuales'),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final month in data)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Tooltip(
                              message:
                                  '${month.label}: ${formatCurrency(month.total)}',
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                height: maxTotal == 0
                                    ? 4
                                    : 4 + 130 * (month.total / maxTotal),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.brandBlue,
                                      AppTheme.brandNavy,
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              month.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.repo});

  final InventoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final top = repo.topSellingProducts();
    final maxUnits = top.isEmpty ? 0 : top.first.units;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Productos más vendidos'),
            const SizedBox(height: 16),
            if (top.isEmpty)
              const EmptyState(
                icon: Icons.leaderboard_outlined,
                title: 'Aún no hay ventas registradas',
              )
            else
              for (final (index, product) in top.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxUnits == 0
                                  ? 0
                                  : product.units / maxUnits,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              color: AppTheme.brandBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${product.units} u.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.repo, required this.onSeeInventory});

  final InventoryRepository repo;
  final VoidCallback onSeeInventory;

  @override
  Widget build(BuildContext context) {
    final lowStock = repo.lowStockProducts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Alertas de stock',
              action: TextButton(
                onPressed: onSeeInventory,
                child: const Text('Ver inventario'),
              ),
            ),
            if (lowStock.isEmpty)
              const EmptyState(
                icon: Icons.verified_outlined,
                title: 'Todo en orden',
                message: 'Ningún producto por debajo de su stock mínimo.',
              )
            else
              for (final product in lowStock.take(6))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        product.stockStatus == StockStatus.out
                            ? Icons.error_outline
                            : Icons.warning_amber_outlined,
                        color: product.stockStatus == StockStatus.out
                            ? AppTheme.danger
                            : AppTheme.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${product.stock} / mín. ${product.minStock}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      StockStatusChip(status: product.stockStatus),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vista Operador
// ---------------------------------------------------------------------------

class _OperatorDashboard extends StatelessWidget {
  const _OperatorDashboard({required this.onNavigate});

  final void Function(AppSection section) onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final user = context.watch<AuthService>().currentUser!;
    final padding = context.pagePadding;
    final todaySales = repo.salesOfToday().where((s) => !s.cancelled).toList();
    final todayTotal =
        todaySales.fold<double>(0, (sum, s) => sum + s.total);

    return PageContainer(
      child: ListView(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
        children: [
          Text(
            'Hola, ${user.name.split(' ').first} 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Resumen operativo de hoy',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          // Accesos rápidos
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.point_of_sale,
                  label: 'Nueva venta',
                  color: AppTheme.success,
                  onTap: () => onNavigate(AppSection.sales),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_box_outlined,
                  label: 'Registrar entrada',
                  color: AppTheme.brandBlue,
                  onTap: () => onNavigate(AppSection.movements),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: context.isMobile ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: context.isMobile ? 1.35 : 1.6,
            children: [
              KpiCard(
                title: 'Ventas de hoy',
                value: '${todaySales.length}',
                icon: Icons.receipt_long_outlined,
                color: AppTheme.brandNavy,
              ),
              KpiCard(
                title: 'Total cobrado hoy',
                value: formatCurrency(todayTotal),
                icon: Icons.payments_outlined,
                color: AppTheme.success,
              ),
              KpiCard(
                title: 'Productos con stock bajo',
                value: '${repo.lowStockProducts.length}',
                icon: Icons.warning_amber_outlined,
                color: AppTheme.warning,
              ),
              KpiCard(
                title: 'Productos en catálogo',
                value: '${repo.products.length}',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.brandBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LowStockCard(
            repo: repo,
            onSeeInventory: () => onNavigate(AppSection.inventory),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
