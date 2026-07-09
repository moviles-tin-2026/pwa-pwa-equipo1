import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';

/// Módulo 4 — Terminal de Venta (POS, Ambos roles).
///
/// Interfaz fluida para añadir productos con buscador (o lector de
/// códigos escribiendo el SKU), cálculo del total en tiempo real,
/// selección de método de pago y "Finalizar venta" que ejecuta la
/// transacción atómica que descuenta inventario.
///
/// Layout responsive:
/// - Móvil: catálogo arriba + barra de carrito fija abajo que abre el
///   detalle en bottom sheet.
/// - Web/escritorio: catálogo a la izquierda y carrito fijo a la derecha.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  /// Carrito: productId -> cantidad.
  final Map<String, int> _cart = {};
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _processing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SaleItem> _cartItems(InventoryRepository repo) => [
        for (final entry in _cart.entries)
          if (repo.productById(entry.key) case final product?)
            SaleItem(
              productId: product.id,
              productName: product.name,
              unitPrice: product.salePrice,
              quantity: entry.value,
            ),
      ];

  double _total(InventoryRepository repo) =>
      _cartItems(repo).fold(0, (sum, item) => sum + item.subtotal);

  int _cartCount() => _cart.values.fold(0, (sum, qty) => sum + qty);

  void _addToCart(Product product) {
    final current = _cart[product.id] ?? 0;
    if (current >= product.stock) {
      showErrorSnackBar(
        context,
        'No hay más stock de "${product.name}" (disponible: ${product.stock})',
      );
      return;
    }
    setState(() => _cart[product.id] = current + 1);
  }

  void _changeQuantity(String productId, int delta,
      {StateSetter? sheetSetState}) {
    void apply() {
      final current = _cart[productId] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _cart.remove(productId);
      } else {
        final repo = context.read<InventoryRepository>();
        final product = repo.productById(productId);
        if (product != null && next > product.stock) return;
        _cart[productId] = next;
      }
    }

    setState(apply);
    sheetSetState?.call(() {});
  }

  Future<void> _checkout() async {
    final repo = context.read<InventoryRepository>();
    final user = context.read<AuthService>().currentUser!;
    final items = _cartItems(repo);

    setState(() => _processing = true);
    final result = await repo.checkoutSale(
      items: items,
      paymentMethod: _paymentMethod,
      userName: user.name,
    );
    if (!mounted) return;
    setState(() => _processing = false);

    if (result.error != null) {
      showErrorSnackBar(context, result.error!);
      return;
    }

    setState(() => _cart.clear());
    final sale = result.sale!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppTheme.success,
          size: 48,
        ),
        title: Text('Venta ${sale.folio} completada'),
        content: Text(
          'Total: ${formatCurrency(sale.total)}\n'
          'Pago: ${sale.paymentMethod.label}\n'
          'El inventario se actualizó automáticamente.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final isMobile = context.isMobile;

    final query = _search.trim().toLowerCase();
    final products = repo.products.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query);
    }).toList();

    final catalog = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            16,
            context.pagePadding,
            8,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Buscar producto o escanear código…',
              prefixIcon: const Icon(Icons.qr_code_scanner),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    8,
                    context.pagePadding,
                    isMobile ? 96 : 24,
                  ),
                  gridDelegate:
                      SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isMobile ? 220 : 240,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final inCart = _cart[product.id] ?? 0;
                    final available = product.stock - inCart;
                    return _PosProductCard(
                      product: product,
                      inCart: inCart,
                      available: available,
                      onTap: available > 0
                          ? () => _addToCart(product)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );

    if (!isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: catalog),
          SizedBox(
            width: 360,
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 16, 24, 24),
              child: _buildCartPanel(repo),
            ),
          ),
        ],
      );
    }

    final count = _cartCount();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: catalog,
      bottomNavigationBar: count == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () => _openCartSheet(repo),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ver carrito ($count)'),
                      Text(
                        formatCurrency(_total(repo)),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _openCartSheet(InventoryRepository repo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: _buildCartPanel(
            context.read<InventoryRepository>(),
            sheetContext: sheetContext,
            sheetSetState: sheetSetState,
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel(
    InventoryRepository repo, {
    BuildContext? sheetContext,
    StateSetter? sheetSetState,
  }) {
    final items = _cartItems(repo);
    final total = _total(repo);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined,
                  color: AppTheme.brandNavy),
              const SizedBox(width: 8),
              Text(
                'Carrito (${_cartCount()})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _cart.clear());
                    sheetSetState?.call(() {});
                    if (sheetContext != null) Navigator.pop(sheetContext);
                  },
                  child: const Text('Vaciar'),
                ),
            ],
          ),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Carrito vacío',
                    message: 'Toca un producto del catálogo para agregarlo.',
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${formatCurrency(item.unitPrice)} c/u',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                  Icons.remove_circle_outline),
                              onPressed: () => _changeQuantity(
                                item.productId,
                                -1,
                                sheetSetState: sheetSetState,
                              ),
                            ),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _changeQuantity(
                                item.productId,
                                1,
                                sheetSetState: sheetSetState,
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                formatCurrency(item.subtotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(
                value: PaymentMethod.cash,
                icon: Icon(Icons.payments_outlined, size: 16),
                label: Text('Efectivo'),
              ),
              ButtonSegment(
                value: PaymentMethod.card,
                icon: Icon(Icons.credit_card, size: 16),
                label: Text('Tarjeta'),
              ),
              ButtonSegment(
                value: PaymentMethod.transfer,
                icon: Icon(Icons.swap_horiz, size: 16),
                label: Text('Transf.'),
              ),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (selection) {
              setState(() => _paymentMethod = selection.first);
              sheetSetState?.call(() {});
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                formatCurrency(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: items.isEmpty || _processing
                ? null
                : () async {
                    if (sheetContext != null) Navigator.pop(sheetContext);
                    await _checkout();
                  },
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text(
              'Finalizar venta',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosProductCard extends StatelessWidget {
  const _PosProductCard({
    required this.product,
    required this.inCart,
    required this.available,
    required this.onTap,
  });

  final Product product;
  final int inCart;
  final int available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (inCart > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$inCart',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  formatCurrency(product.salePrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.brandNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disabled ? 'Sin stock disponible' : 'Disp: $available',
                  style: TextStyle(
                    fontSize: 11,
                    color: disabled ? AppTheme.danger : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
