import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';

/// Contrato del repositorio central de datos (productos, categorías,
/// movimientos, ventas y usuarios).
///
/// Hay dos implementaciones:
/// - [FirestoreInventoryRepository]: la real, conectada a Cloud Firestore
///   con snapshots reactivos (ver `firestore_inventory_repository.dart`).
/// - [LocalInventoryRepository]: en memoria con datos de demostración,
///   usada por las cuentas demo para previsualizar la UI sin conexión.
///
/// Las pantallas solo dependen de esta clase, por lo que el cambio de
/// backend es transparente para la UI.
abstract class InventoryRepository extends ChangeNotifier {
  @protected
  final List<Category> categoriesCache = [];
  @protected
  final List<Product> productsCache = [];
  @protected
  final List<StockMovement> movementsCache = [];
  @protected
  final List<Sale> salesCache = [];
  @protected
  final List<AppUser> usersCache = [];

  List<Category> get categories => List.unmodifiable(categoriesCache);
  List<Product> get products => List.unmodifiable(productsCache);
  List<StockMovement> get movements => List.unmodifiable(movementsCache);
  List<Sale> get sales => List.unmodifiable(salesCache);
  List<AppUser> get users => List.unmodifiable(usersCache);

  // ---------------- Lecturas auxiliares ----------------

  Category? categoryById(String id) {
    for (final c in categoriesCache) {
      if (c.id == id) return c;
    }
    return null;
  }

  Product? productById(String id) {
    for (final p in productsCache) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Product> get lowStockProducts => productsCache
      .where((p) => p.stockStatus != StockStatus.ok)
      .toList()
    ..sort((a, b) => a.stock.compareTo(b.stock));

  /// Ventas del día actual (arqueo de caja del operador).
  List<Sale> salesOfToday() {
    final now = DateTime.now();
    return salesCache
        .where((s) =>
            s.date.year == now.year &&
            s.date.month == now.month &&
            s.date.day == now.day)
        .toList();
  }

  // ---------------- Métricas del dashboard ----------------

  double get inventoryValueAtCost =>
      productsCache.fold(0, (sum, p) => sum + p.costPrice * p.stock);

  double get inventoryValueAtSale =>
      productsCache.fold(0, (sum, p) => sum + p.salePrice * p.stock);

  double get profitMarginPercent {
    final atSale = inventoryValueAtSale;
    if (atSale == 0) return 0;
    return (atSale - inventoryValueAtCost) / atSale * 100;
  }

  double get monthSalesTotal {
    final now = DateTime.now();
    return salesCache
        .where((s) =>
            !s.cancelled &&
            s.date.year == now.year &&
            s.date.month == now.month)
        .fold(0, (sum, s) => sum + s.total);
  }

  /// Total vendido por mes de los últimos [months] meses (para el gráfico).
  List<({String label, double total})> monthlySales({int months = 6}) {
    const names = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final now = DateTime.now();
    final result = <({String label, double total})>[];
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = salesCache
          .where((s) =>
              !s.cancelled &&
              s.date.year == month.year &&
              s.date.month == month.month)
          .fold<double>(0, (sum, s) => sum + s.total);
      result.add((label: names[month.month - 1], total: total));
    }
    return result;
  }

  /// Productos más vendidos (por unidades, ventas no canceladas).
  List<({String name, int units})> topSellingProducts({int limit = 5}) {
    final units = <String, ({String name, int units})>{};
    for (final sale in salesCache.where((s) => !s.cancelled)) {
      for (final item in sale.items) {
        final current = units[item.productId];
        units[item.productId] = (
          name: item.productName,
          units: (current?.units ?? 0) + item.quantity,
        );
      }
    }
    final list = units.values.toList()
      ..sort((a, b) => b.units.compareTo(a.units));
    return list.take(limit).toList();
  }

  // ---------------- Mutaciones (implementadas por backend) ----------------

  Future<void> addCategory(String name, String description);
  Future<void> updateCategory(String id, String name, String description);

  /// Elimina la categoría solo si ningún producto la usa.
  Future<bool> deleteCategory(String id);

  Future<void> createProduct({
    required String name,
    required String sku,
    required String categoryId,
    required double costPrice,
    required double salePrice,
    required int stock,
    required int minStock,
    required int maxStock,
    String imageUrl = '',
  });

  Future<void> updateProduct(Product updated);
  Future<void> deleteProduct(String id);

  /// Registra una entrada o salida de stock con motivo obligatorio.
  /// Devuelve un mensaje de error o `null` si tuvo éxito.
  Future<String?> registerMovement({
    required String productId,
    required MovementType type,
    required int quantity,
    required String reason,
    required String userName,
  });

  /// Finaliza una venta descontando inventario de forma atómica:
  /// valida el stock de TODAS las líneas y solo entonces aplica los
  /// descuentos (transacción de Firestore en la implementación real).
  Future<({Sale? sale, String? error})> checkoutSale({
    required List<SaleItem> items,
    required PaymentMethod paymentMethod,
    required String userName,
  });

  /// Cancela un folio (solo Admin) y devuelve el stock al inventario.
  Future<void> cancelSale(String saleId);

  Future<void> addUser({
    required String name,
    required String email,
    required UserRole role,
  });
  Future<void> updateUser(AppUser updated);
  Future<void> deleteUser(String id);
}

/// Implementación en memoria con datos de demostración.
///
/// Se usa cuando la sesión es de una cuenta demo, para diseñar y probar
/// toda la UI en Android Studio sin depender de la consola de Firebase.
class LocalInventoryRepository extends InventoryRepository {
  LocalInventoryRepository() {
    _seed();
  }

  int _folioCounter = 0;
  int _idCounter = 0;

  String _nextId() => 'id-${++_idCounter}';

  // ---------------- Categorías ----------------

  @override
  Future<void> addCategory(String name, String description) async {
    categoriesCache.add(
      Category(id: _nextId(), name: name, description: description),
    );
    notifyListeners();
  }

  @override
  Future<void> updateCategory(
      String id, String name, String description) async {
    final index = categoriesCache.indexWhere((c) => c.id == id);
    if (index == -1) return;
    categoriesCache[index] =
        Category(id: id, name: name, description: description);
    notifyListeners();
  }

  @override
  Future<bool> deleteCategory(String id) async {
    if (productsCache.any((p) => p.categoryId == id)) return false;
    categoriesCache.removeWhere((c) => c.id == id);
    notifyListeners();
    return true;
  }

  // ---------------- Productos ----------------

  @override
  Future<void> createProduct({
    required String name,
    required String sku,
    required String categoryId,
    required double costPrice,
    required double salePrice,
    required int stock,
    required int minStock,
    required int maxStock,
    String imageUrl = '',
  }) async {
    productsCache.add(Product(
      id: _nextId(),
      name: name,
      sku: sku,
      categoryId: categoryId,
      costPrice: costPrice,
      salePrice: salePrice,
      stock: stock,
      minStock: minStock,
      maxStock: maxStock,
      imageUrl: imageUrl,
    ));
    notifyListeners();
  }

  @override
  Future<void> updateProduct(Product updated) async {
    _applyProductUpdate(updated);
    notifyListeners();
  }

  void _applyProductUpdate(Product updated) {
    final index = productsCache.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    productsCache[index] = updated;
  }

  @override
  Future<void> deleteProduct(String id) async {
    productsCache.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ---------------- Movimientos ----------------

  @override
  Future<String?> registerMovement({
    required String productId,
    required MovementType type,
    required int quantity,
    required String reason,
    required String userName,
  }) async {
    final product = productById(productId);
    if (product == null) return 'Producto no encontrado';
    if (quantity <= 0) return 'La cantidad debe ser mayor a cero';
    if (type == MovementType.exit && quantity > product.stock) {
      return 'Stock insuficiente (disponible: ${product.stock})';
    }

    final delta = type == MovementType.entry ? quantity : -quantity;
    _applyProductUpdate(product.copyWith(stock: product.stock + delta));

    movementsCache.insert(
      0,
      StockMovement(
        id: _nextId(),
        productId: product.id,
        productName: product.name,
        type: type,
        quantity: quantity,
        reason: reason,
        userName: userName,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return null;
  }

  // ---------------- Ventas (POS) ----------------

  @override
  Future<({Sale? sale, String? error})> checkoutSale({
    required List<SaleItem> items,
    required PaymentMethod paymentMethod,
    required String userName,
  }) async {
    if (items.isEmpty) return (sale: null, error: 'El carrito está vacío');

    for (final item in items) {
      final product = productById(item.productId);
      if (product == null) {
        return (
          sale: null,
          error: 'Producto no encontrado: ${item.productName}'
        );
      }
      if (item.quantity > product.stock) {
        return (
          sale: null,
          error:
              'Stock insuficiente de "${product.name}" (disponible: ${product.stock})',
        );
      }
    }

    for (final item in items) {
      final product = productById(item.productId)!;
      _applyProductUpdate(
        product.copyWith(stock: product.stock - item.quantity),
      );
    }

    _folioCounter++;
    final sale = Sale(
      id: _nextId(),
      folio: 'V-${_folioCounter.toString().padLeft(4, '0')}',
      items: List.unmodifiable(items),
      paymentMethod: paymentMethod,
      userName: userName,
      date: DateTime.now(),
    );
    salesCache.insert(0, sale);
    notifyListeners();
    return (sale: sale, error: null);
  }

  @override
  Future<void> cancelSale(String saleId) async {
    final index = salesCache.indexWhere((s) => s.id == saleId);
    if (index == -1 || salesCache[index].cancelled) return;
    final sale = salesCache[index];
    for (final item in sale.items) {
      final product = productById(item.productId);
      if (product != null) {
        _applyProductUpdate(
          product.copyWith(stock: product.stock + item.quantity),
        );
      }
    }
    salesCache[index] = sale.copyWith(cancelled: true);
    notifyListeners();
  }

  // ---------------- Usuarios ----------------

  @override
  Future<void> addUser({
    required String name,
    required String email,
    required UserRole role,
  }) async {
    usersCache.add(AppUser(
      id: _nextId(),
      name: name,
      email: email,
      role: role,
    ));
    notifyListeners();
  }

  @override
  Future<void> updateUser(AppUser updated) async {
    final index = usersCache.indexWhere((u) => u.id == updated.id);
    if (index == -1) return;
    usersCache[index] = updated;
    notifyListeners();
  }

  @override
  Future<void> deleteUser(String id) async {
    usersCache.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  // ---------------- Datos de demostración ----------------

  void _seed() {
    categoriesCache.addAll([
      Category(id: _nextId(), name: 'Bebidas', description: 'Refrescos, jugos y agua'),
      Category(id: _nextId(), name: 'Abarrotes', description: 'Despensa básica'),
      Category(id: _nextId(), name: 'Limpieza', description: 'Productos de higiene y limpieza'),
      Category(id: _nextId(), name: 'Botanas', description: 'Frituras y dulces'),
    ]);
    final beverages = categoriesCache[0].id;
    final groceries = categoriesCache[1].id;
    final cleaning = categoriesCache[2].id;
    final snacks = categoriesCache[3].id;

    productsCache.addAll([
      Product(id: _nextId(), name: 'Refresco Cola 600ml', sku: '7501000111', categoryId: beverages, costPrice: 12.5, salePrice: 19, stock: 48, minStock: 12, maxStock: 120),
      Product(id: _nextId(), name: 'Agua Natural 1L', sku: '7501000222', categoryId: beverages, costPrice: 8, salePrice: 14, stock: 9, minStock: 15, maxStock: 100),
      Product(id: _nextId(), name: 'Jugo de Naranja 1L', sku: '7501000333', categoryId: beverages, costPrice: 18, salePrice: 28, stock: 22, minStock: 10, maxStock: 60),
      Product(id: _nextId(), name: 'Arroz 1kg', sku: '7502000111', categoryId: groceries, costPrice: 22, salePrice: 34, stock: 35, minStock: 10, maxStock: 80),
      Product(id: _nextId(), name: 'Frijol Negro 1kg', sku: '7502000222', categoryId: groceries, costPrice: 28, salePrice: 42, stock: 0, minStock: 8, maxStock: 60),
      Product(id: _nextId(), name: 'Aceite Vegetal 1L', sku: '7502000333', categoryId: groceries, costPrice: 38, salePrice: 55, stock: 18, minStock: 6, maxStock: 40),
      Product(id: _nextId(), name: 'Detergente en Polvo 1kg', sku: '7503000111', categoryId: cleaning, costPrice: 30, salePrice: 47, stock: 14, minStock: 5, maxStock: 40),
      Product(id: _nextId(), name: 'Cloro 950ml', sku: '7503000222', categoryId: cleaning, costPrice: 15, salePrice: 24, stock: 4, minStock: 6, maxStock: 30),
      Product(id: _nextId(), name: 'Papas Fritas 45g', sku: '7504000111', categoryId: snacks, costPrice: 9, salePrice: 16, stock: 60, minStock: 20, maxStock: 150),
      Product(id: _nextId(), name: 'Galletas de Chocolate', sku: '7504000222', categoryId: snacks, costPrice: 11, salePrice: 18.5, stock: 25, minStock: 10, maxStock: 90),
    ]);

    usersCache.addAll([
      AppUser(id: _nextId(), name: 'Ana Martínez', email: 'admin@pymesync.com', role: UserRole.admin),
      AppUser(id: _nextId(), name: 'Luis Herrera', email: 'operador@pymesync.com', role: UserRole.operator),
      AppUser(id: _nextId(), name: 'Sofía Rangel', email: 'sofia@pymesync.com', role: UserRole.operator),
    ]);

    // Historial de ejemplo: ventas de los últimos meses para las gráficas.
    final now = DateTime.now();
    void demoSale(DateTime date, List<(int productIndex, int qty)> lines,
        PaymentMethod method, String seller) {
      _folioCounter++;
      salesCache.insert(
        0,
        Sale(
          id: _nextId(),
          folio: 'V-${_folioCounter.toString().padLeft(4, '0')}',
          items: [
            for (final (i, qty) in lines)
              SaleItem(
                productId: productsCache[i].id,
                productName: productsCache[i].name,
                unitPrice: productsCache[i].salePrice,
                quantity: qty,
              ),
          ],
          paymentMethod: method,
          userName: seller,
          date: date,
        ),
      );
    }

    demoSale(DateTime(now.year, now.month - 5, 12), [(0, 24), (8, 30)], PaymentMethod.cash, 'Luis Herrera');
    demoSale(DateTime(now.year, now.month - 4, 8), [(3, 10), (5, 6)], PaymentMethod.card, 'Sofía Rangel');
    demoSale(DateTime(now.year, now.month - 4, 21), [(0, 18), (9, 12)], PaymentMethod.cash, 'Luis Herrera');
    demoSale(DateTime(now.year, now.month - 3, 5), [(2, 8), (6, 4)], PaymentMethod.transfer, 'Luis Herrera');
    demoSale(DateTime(now.year, now.month - 3, 17), [(8, 40), (0, 12)], PaymentMethod.cash, 'Sofía Rangel');
    demoSale(DateTime(now.year, now.month - 2, 9), [(3, 15), (4, 5), (5, 3)], PaymentMethod.card, 'Luis Herrera');
    demoSale(DateTime(now.year, now.month - 1, 3), [(0, 30), (8, 25), (9, 10)], PaymentMethod.cash, 'Sofía Rangel');
    demoSale(DateTime(now.year, now.month - 1, 19), [(6, 6), (7, 5)], PaymentMethod.transfer, 'Luis Herrera');
    demoSale(DateTime(now.year, now.month, 2), [(0, 10), (2, 4)], PaymentMethod.cash, 'Luis Herrera');
    demoSale(now.subtract(const Duration(hours: 3)), [(8, 6), (9, 3)], PaymentMethod.cash, 'Luis Herrera');
    demoSale(now.subtract(const Duration(hours: 1)), [(0, 4), (3, 2)], PaymentMethod.card, 'Luis Herrera');

    movementsCache.addAll([
      StockMovement(id: _nextId(), productId: productsCache[0].id, productName: productsCache[0].name, type: MovementType.entry, quantity: 48, reason: 'Compra a proveedor', userName: 'Luis Herrera', date: now.subtract(const Duration(days: 2, hours: 4))),
      StockMovement(id: _nextId(), productId: productsCache[7].id, productName: productsCache[7].name, type: MovementType.exit, quantity: 2, reason: 'Merma: envase dañado', userName: 'Sofía Rangel', date: now.subtract(const Duration(days: 1, hours: 6))),
      StockMovement(id: _nextId(), productId: productsCache[8].id, productName: productsCache[8].name, type: MovementType.entry, quantity: 60, reason: 'Compra a proveedor', userName: 'Ana Martínez', date: now.subtract(const Duration(hours: 8))),
    ]);
  }
}
