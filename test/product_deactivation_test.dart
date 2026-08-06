// Pruebas de la baja lógica de productos.
//
// Borrar un producto con historial dejaba las líneas de venta apuntando a
// un id inexistente: al cancelar ese folio no había a quién devolverle el
// stock y la cancelación se saltaba la línea sin decir nada. Ahora el
// producto se marca `active: false` y sigue existiendo. Estas pruebas
// fijan la otra mitad del trato: un descontinuado no vuelve a ofrecerse
// para vender ni para mover stock, y deja de contar como alerta.

import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/models.dart';

import 'fake_repository.dart';

void main() {
  Product product(
    String id,
    String name, {
    bool active = true,
    int stock = 10,
  }) =>
      Product(
        id: id,
        name: name,
        sku: 'SKU-$id',
        categoryId: 'cat-1',
        costPrice: 100,
        salePrice: 180,
        stock: stock,
        minStock: 2,
        maxStock: 40,
        active: active,
      );

  test('un producto nace vigente si Firestore no trae el campo', () {
    // Los documentos anteriores a la baja lógica no tienen `active`: si se
    // leyeran como inactivos, el catálogo entero desaparecería del POS.
    final legacy = Product.fromMap('p1', {
      'name': 'Serum',
      'sku': 'AV-001',
      'categoryId': 'cat-1',
      'costPrice': 100,
      'salePrice': 180,
      'stock': 10,
      'minStock': 2,
      'maxStock': 40,
    });

    expect(legacy.active, isTrue);
  });

  test('editar un producto descontinuado no lo reactiva de rebote', () {
    final discontinued = product('p1', 'Serum', active: false);
    expect(discontinued.copyWith(salePrice: 200).active, isFalse);
  });

  test('los descontinuados salen del catálogo vendible', () {
    final repo = FakeRepository(products: [
      product('p1', 'Serum'),
      product('p2', 'Bloqueador', active: false),
    ]);

    // `products` conserva todo: la lista de Admin necesita poder mostrar
    // los descontinuados con su distintivo.
    expect(repo.products.length, 2);
    // `activeProducts` es la que consumen el POS y el alta de movimientos.
    expect(repo.activeProducts.map((p) => p.id), ['p1']);
  });

  test('un descontinuado no genera alerta de stock bajo', () {
    final repo = FakeRepository(products: [
      product('p1', 'Serum', stock: 0),
      product('p2', 'Bloqueador', active: false, stock: 0),
    ]);

    // Sin este filtro el dashboard pediría reponer productos que ya nadie
    // vende y la alerta perdería sentido.
    expect(repo.lowStockProducts.map((p) => p.id), ['p1']);
  });

  test('el descontinuado sigue en el catálogo para devolverle stock', () {
    // Es el punto del issue: la línea de una venta vieja tiene que poder
    // encontrar su producto al cancelar el folio.
    final repo = FakeRepository(products: [
      product('p1', 'Serum', active: false),
    ]);

    expect(repo.productById('p1'), isNotNull);
  });
}
