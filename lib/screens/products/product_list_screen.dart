import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';
import 'categories_screen.dart';
import 'product_form_screen.dart';

/// Módulo 2 — Lista de Productos (Ambos roles).
///
/// Buscador reactivo, filtros por categoría y estado de stock.
/// Ambos roles pueden dar de alta productos nuevos. Solo el Admin edita,
/// elimina y gestiona categorías (matriz RBAC).
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.initialQuery});

  /// Búsqueda inicial prellenada (la fija la búsqueda global del topbar).
  final String? initialQuery;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _categoryId;
  StockStatus? _stockStatus;

  @override
  void initState() {
    super.initState();
    _search = widget.initialQuery ?? '';
    _searchController.text = _search;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filter(InventoryRepository repo) {
    final query = _search.trim().toLowerCase();
    return repo.products.where((p) {
      if (_categoryId != null && p.categoryId != _categoryId) return false;
      if (_stockStatus != null && p.stockStatus != _stockStatus) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final isAdmin = context.watch<AuthService>().isAdmin;
    final padding = context.pagePadding;
    final products = _filter(repo);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ProductFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: PageContainer(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _search = value),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o SKU…',
                            prefixIcon: const Icon(Icons.search),
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
                      if (isAdmin) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CategoriesScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.category_outlined),
                          label: Text(
                            context.isMobile ? 'Cat.' : 'Categorías',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: const Text('Todas las categorías'),
                          selected: _categoryId == null,
                          onSelected: (_) =>
                              setState(() => _categoryId = null),
                        ),
                        for (final category in repo.categories) ...[
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(category.name),
                            selected: _categoryId == category.id,
                            onSelected: (selected) => setState(
                              () => _categoryId =
                                  selected ? category.id : null,
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                        FilterChip(
                          avatar: const Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: AppTheme.warning,
                          ),
                          label: const Text('Stock bajo'),
                          selected: _stockStatus == StockStatus.low,
                          onSelected: (selected) => setState(
                            () => _stockStatus =
                                selected ? StockStatus.low : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppTheme.danger,
                          ),
                          label: const Text('Agotados'),
                          selected: _stockStatus == StockStatus.out,
                          onSelected: (selected) => setState(
                            () => _stockStatus =
                                selected ? StockStatus.out : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin productos',
                      message:
                          'Ajusta los filtros o registra nuevos productos.',
                    )
                  : context.isMobile
                      ? ListView.separated(
                          padding:
                              EdgeInsets.fromLTRB(padding, 16, padding, 96),
                          itemCount: products.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _ProductCard(
                            product: products[index],
                            isAdmin: isAdmin,
                          ),
                        )
                      : _ProductTable(products: products, isAdmin: isAdmin),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de producto para móvil.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.isAdmin});

  final Product product;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<InventoryRepository>();
    final category = repo.categoryById(product.categoryId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showProductDetail(context, product, isAdmin),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProductImage(imageUrl: product.imageUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU ${product.sku} · ${category?.name ?? 'Sin categoría'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatCurrency(product.salePrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Stock: ${product.stock}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StockStatusChip(status: product.stockStatus),
                  if (isAdmin) _AdminProductMenu(product: product),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tabla de productos para tablet/web.
class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.products, required this.isAdmin});

  final List<Product> products;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<InventoryRepository>();
    final padding = context.pagePadding;

    return ListView(
      padding: EdgeInsets.fromLTRB(padding, 16, padding, 96),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width -
                    padding * 2 -
                    (context.isDesktop ? 220 : 80),
              ),
              child: DataTable(
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.brandNavy,
                ),
                columns: [
                  const DataColumn(label: Text('Producto')),
                  const DataColumn(label: Text('SKU')),
                  const DataColumn(label: Text('Categoría')),
                  if (isAdmin) const DataColumn(label: Text('Costo')),
                  const DataColumn(label: Text('Precio')),
                  const DataColumn(label: Text('Stock')),
                  const DataColumn(label: Text('Estado')),
                  if (isAdmin) const DataColumn(label: Text('')),
                ],
                rows: [
                  for (final product in products)
                    DataRow(
                      onSelectChanged: (_) =>
                          _showProductDetail(context, product, isAdmin),
                      cells: [
                        DataCell(Row(
                          children: [
                            ProductImage(
                              imageUrl: product.imageUrl,
                              size: 34,
                              borderRadius: 8,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                product.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )),
                        DataCell(Text(product.sku)),
                        DataCell(Text(
                          repo.categoryById(product.categoryId)?.name ??
                              'Sin categoría',
                        )),
                        if (isAdmin)
                          DataCell(Text(formatCurrency(product.costPrice))),
                        DataCell(Text(
                          formatCurrency(product.salePrice),
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        )),
                        DataCell(Text('${product.stock}')),
                        DataCell(StockStatusChip(status: product.stockStatus)),
                        if (isAdmin)
                          DataCell(_AdminProductMenu(product: product)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Menú contextual de acciones de Admin sobre un producto.
class _AdminProductMenu extends StatelessWidget {
  const _AdminProductMenu({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<InventoryRepository>();

    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      iconSize: 20,
      onSelected: (action) {
        switch (action) {
          case 'edit':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductFormScreen(product: product),
              ),
            );
          case 'delete':
            showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Eliminar producto'),
                content: Text('¿Eliminar "${product.name}" del catálogo?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                    ),
                    onPressed: () {
                      repo.deleteProduct(product.id);
                      Navigator.pop(dialogContext);
                      showSuccessSnackBar(context, 'Producto eliminado');
                    },
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppTheme.danger),
            title: Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ),
      ],
    );
  }
}

/// Detalle de producto en bottom sheet (móvil) — solo consulta para el
/// Operador; el Admin además puede saltar a editar.
void _showProductDetail(BuildContext context, Product product, bool isAdmin) {
  final repo = context.read<InventoryRepository>();
  final category = repo.categoryById(product.categoryId);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductImage(
                  imageUrl: product.imageUrl,
                  size: 64,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StockStatusChip(status: product.stockStatus),
              ],
            ),
            if (product.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                product.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _DetailRow(label: 'SKU / Código', value: product.sku),
            _DetailRow(
              label: 'Categoría',
              value: category?.name ?? 'Sin categoría',
            ),
            _DetailRow(
              label: 'Precio de venta',
              value: formatCurrency(product.salePrice),
            ),
            if (isAdmin) ...[
              _DetailRow(
                label: 'Precio de costo',
                value: formatCurrency(product.costPrice),
              ),
              _DetailRow(
                label: 'Margen',
                value: '${product.margin.toStringAsFixed(1)}%',
              ),
            ],
            _DetailRow(
              label: 'Stock actual',
              value:
                  '${product.stock} (mín. ${product.minStock} / máx. ${product.maxStock})',
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductFormScreen(product: product),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar producto'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
