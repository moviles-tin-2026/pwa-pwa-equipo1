// Pruebas de la unicidad de SKU.
//
// El SKU es lo que teclea o escanea el cajero en el POS: si dos productos
// comparten código, la búsqueda es ambigua y se puede cobrar el producto
// equivocado. Estas pruebas fijan las reglas de comparación (sin
// distinguir mayúsculas ni espacios) y que un producto no choque consigo
// mismo al editarse.

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';
import 'package:login_app/services/inventory_repository.dart';

void main() {
  Product product(String id, String name, String sku) => Product(
        id: id,
        name: name,
        sku: sku,
        categoryId: 'cat-1',
        costPrice: 100,
        salePrice: 180,
        stock: 10,
        minStock: 2,
        maxStock: 40,
      );

  late _FakeRepository repo;

  setUp(() {
    repo = _FakeRepository([
      product('p1', 'Vitamin C Serum', 'AV-001'),
      product('p2', 'Mineral Sunscreen', 'AV-002'),
    ]);
  });

  test('un SKU libre no reporta dueño', () {
    expect(repo.productBySku('AV-999'), isNull);
  });

  test('detecta el producto que ya usa el SKU', () {
    expect(repo.productBySku('AV-002')?.name, 'Mineral Sunscreen');
  });

  test('ignora mayúsculas y espacios sobrantes', () {
    expect(repo.productBySku('av-001')?.id, 'p1');
    expect(repo.productBySku('  AV-001  ')?.id, 'p1');
    expect(repo.productBySku('Av-001')?.id, 'p1');
  });

  test('al editar, un producto no choca con su propio SKU', () {
    expect(repo.productBySku('AV-001', excludingId: 'p1'), isNull);
    // Pero sí con el de otro producto.
    expect(repo.productBySku('AV-002', excludingId: 'p1')?.id, 'p2');
  });

  test('un SKU vacío no reporta dueño (lo cubre el campo obligatorio)', () {
    expect(repo.productBySku(''), isNull);
    expect(repo.productBySku('   '), isNull);
  });
}

/// Repositorio con el catálogo en memoria: las lecturas de
/// [InventoryRepository] son las reales, las escrituras no se usan aquí.
class _FakeRepository extends InventoryRepository {
  _FakeRepository(List<Product> products) {
    productsCache.addAll(products);
  }

  @override
  Future<void> addCategory(String name, String description) async =>
      throw UnimplementedError();

  @override
  Future<void> updateCategory(String id, String name, String description) async =>
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
