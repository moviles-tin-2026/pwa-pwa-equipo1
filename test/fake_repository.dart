// Repositorio de mentira compartido por las pruebas.
//
// Vive en un solo archivo a propósito: cuando el contrato de
// `InventoryRepository` cambia, hay un único sitio que actualizar. Tenerlo
// duplicado en cada prueba fue lo que dejó el análisis en rojo al agregar
// `setProductActive` y cambiar el retorno de `deleteProduct`/`cancelSale`.
//
// Las lecturas y métricas que hereda son las reales —eso es lo que las
// pruebas ejercitan—; las escrituras no se usan y lanzan.

import 'package:login_app/models/models.dart';
import 'package:login_app/services/inventory_repository.dart';

class FakeRepository extends InventoryRepository {
  FakeRepository({
    List<Product> products = const [],
    List<Sale> sales = const [],
    List<StockMovement> movements = const [],
  }) {
    productsCache.addAll(products);
    salesCache.addAll(sales);
    movementsCache.addAll(movements);
  }

  void seedProducts(List<Product> products) => productsCache.addAll(products);
  void seedSales(List<Sale> sales) => salesCache.addAll(sales);
  void seedMovements(List<StockMovement> movements) =>
      movementsCache.addAll(movements);

  @override
  Future<void> addCategory(String name, String description) async =>
      throw UnimplementedError();

  @override
  Future<void> updateCategory(
    String id,
    String name,
    String description,
  ) async =>
      throw UnimplementedError();

  @override
  Future<bool> deleteCategory(String id) async => throw UnimplementedError();

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
    String description = '',
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateProduct(Product updated) async =>
      throw UnimplementedError();

  @override
  Future<ProductDeletionOutcome> deleteProduct(String id) async =>
      throw UnimplementedError();

  @override
  Future<void> setProductActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<String?> registerMovement({
    required String productId,
    required MovementType type,
    required int quantity,
    required String reason,
    required String userName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<({Sale? sale, String? error})> checkoutSale({
    required List<SaleItem> items,
    required PaymentMethod paymentMethod,
    required String userName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<SaleCancellation> cancelSale(
    String saleId, {
    required String userName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateUser(AppUser updated) async => throw UnimplementedError();

  @override
  Future<void> deleteUser(String id) async => throw UnimplementedError();
}
