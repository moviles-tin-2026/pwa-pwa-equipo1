import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';

/// Contrato del repositorio central de datos (productos, categorías,
/// movimientos, ventas y usuarios).
///
/// La implementación real es `FirestoreInventoryRepository`
/// (ver `firestore_inventory_repository.dart`): mantiene las cachés
/// sincronizadas con Cloud Firestore mediante snapshots reactivos.
/// Las pantallas solo dependen de esta clase, por lo que el backend es
/// transparente para la UI.
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
    String description = '',
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
  /// descuentos (transacción de Firestore).
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
