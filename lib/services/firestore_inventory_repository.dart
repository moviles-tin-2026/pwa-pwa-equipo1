import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'inventory_repository.dart';

/// Implementación real del repositorio sobre Cloud Firestore.
///
/// Colecciones:
/// - `categories`: {name, description}
/// - `products`:   {name, sku, categoryId, costPrice, salePrice, stock,
///                  minStock, maxStock}
/// - `movements`:  {productId, productName, type, quantity, reason,
///                  userName, date}
/// - `sales`:      {folio, items[], paymentMethod, userName, date,
///                  cancelled, total}
/// - `users`:      {name, email, role: 'admin'|'operator', active}
/// - `meta/counters`: {saleFolio} — consecutivo de folios de venta.
///
/// Sincronización reactiva: cada colección se escucha con `snapshots()`;
/// cualquier cambio (de este u otro dispositivo) actualiza las cachés y
/// notifica a la UI, cumpliendo el criterio del documento de diseño de que
/// una venta en móvil refresque al instante la pantalla web del admin.
///
/// Escrituras críticas (ventas y movimientos) usan transacciones de
/// Firestore para validar stock y descontarlo de forma atómica.
class FirestoreInventoryRepository extends InventoryRepository {
  FirestoreInventoryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    _subscriptions.addAll([
      _db.collection('categories').orderBy('name').snapshots().listen((snap) {
        categoriesCache
          ..clear()
          ..addAll(snap.docs.map((d) => Category.fromMap(d.id, d.data())));
        notifyListeners();
      }),
      _db.collection('products').orderBy('name').snapshots().listen((snap) {
        productsCache
          ..clear()
          ..addAll(snap.docs.map((d) => Product.fromMap(d.id, d.data())));
        notifyListeners();
      }),
      _db
          .collection('movements')
          .orderBy('date', descending: true)
          .limit(200)
          .snapshots()
          .listen((snap) {
        movementsCache
          ..clear()
          ..addAll(snap.docs.map((d) => StockMovement.fromMap(d.id, d.data())));
        notifyListeners();
      }),
      _db
          .collection('sales')
          .orderBy('date', descending: true)
          .limit(300)
          .snapshots()
          .listen((snap) {
        salesCache
          ..clear()
          ..addAll(snap.docs.map((d) => Sale.fromMap(d.id, d.data())));
        notifyListeners();
      }),
      _db.collection('users').orderBy('name').snapshots().listen((snap) {
        usersCache
          ..clear()
          ..addAll(snap.docs.map((d) => AppUser.fromMap(d.id, d.data())));
        notifyListeners();
      }),
    ]);
  }

  final FirebaseFirestore _db;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _subscriptions = [];

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  // ---------------- Categorías ----------------

  @override
  Future<void> addCategory(String name, String description) =>
      _db.collection('categories').add(
        Category(id: '', name: name, description: description).toMap(),
      );

  @override
  Future<void> updateCategory(String id, String name, String description) =>
      _db.collection('categories').doc(id).update(
        Category(id: id, name: name, description: description).toMap(),
      );

  @override
  Future<bool> deleteCategory(String id) async {
    final inUse = await _db
        .collection('products')
        .where('categoryId', isEqualTo: id)
        .limit(1)
        .get();
    if (inUse.docs.isNotEmpty) return false;
    await _db.collection('categories').doc(id).delete();
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
    String description = '',
  }) =>
      _db.collection('products').add(Product(
        id: '',
        name: name,
        sku: sku,
        categoryId: categoryId,
        costPrice: costPrice,
        salePrice: salePrice,
        stock: stock,
        minStock: minStock,
        maxStock: maxStock,
        imageUrl: imageUrl,
        description: description,
      ).toMap());

  @override
  Future<void> updateProduct(Product updated) =>
      _db.collection('products').doc(updated.id).update(updated.toMap());

  @override
  Future<void> deleteProduct(String id) =>
      _db.collection('products').doc(id).delete();

  // ---------------- Movimientos ----------------

  @override
  Future<String?> registerMovement({
    required String productId,
    required MovementType type,
    required int quantity,
    required String reason,
    required String userName,
  }) async {
    if (quantity <= 0) return 'La cantidad debe ser mayor a cero';
    try {
      return await _db.runTransaction<String?>((tx) async {
        final productRef = _db.collection('products').doc(productId);
        final snap = await tx.get(productRef);
        if (!snap.exists) return 'Producto no encontrado';
        final product = Product.fromMap(snap.id, snap.data()!);

        if (type == MovementType.exit && quantity > product.stock) {
          return 'Stock insuficiente (disponible: ${product.stock})';
        }

        final delta = type == MovementType.entry ? quantity : -quantity;
        tx.update(productRef, {'stock': product.stock + delta});
        tx.set(
          _db.collection('movements').doc(),
          StockMovement(
            id: '',
            productId: product.id,
            productName: product.name,
            type: type,
            quantity: quantity,
            reason: reason,
            userName: userName,
            date: DateTime.now(),
          ).toMap(),
        );
        return null;
      });
    } catch (e) {
      return 'Error al registrar el movimiento: $e';
    }
  }

  // ---------------- Ventas (POS) ----------------

  @override
  Future<({Sale? sale, String? error})> checkoutSale({
    required List<SaleItem> items,
    required PaymentMethod paymentMethod,
    required String userName,
  }) async {
    if (items.isEmpty) return (sale: null, error: 'El carrito está vacío');
    try {
      final sale = await _db.runTransaction<Sale>((tx) async {
        // 1. Leer y validar todas las líneas antes de escribir
        //    (regla de Firestore: todas las lecturas primero).
        final counterRef = _db.collection('meta').doc('counters');
        final counterSnap = await tx.get(counterRef);

        final productSnaps =
            <({SaleItem item, DocumentReference<Map<String, dynamic>> ref, Product product})>[];
        for (final item in items) {
          final ref = _db.collection('products').doc(item.productId);
          final snap = await tx.get(ref);
          if (!snap.exists) {
            throw _CheckoutError('Producto no encontrado: ${item.productName}');
          }
          final product = Product.fromMap(snap.id, snap.data()!);
          if (item.quantity > product.stock) {
            throw _CheckoutError(
              'Stock insuficiente de "${product.name}" (disponible: ${product.stock})',
            );
          }
          productSnaps.add((item: item, ref: ref, product: product));
        }

        final folioNumber =
            (((counterSnap.data() ?? const {})['saleFolio'] ?? 0) as num)
                    .toInt() +
                1;
        final folio = 'V-${folioNumber.toString().padLeft(4, '0')}';
        final now = DateTime.now();

        // 2. Aplicar descuentos de stock, registrar salidas y la venta.
        for (final entry in productSnaps) {
          tx.update(entry.ref, {
            'stock': entry.product.stock - entry.item.quantity,
          });
          final mRef = _db.collection('movements').doc();
          tx.set(
            mRef,
            StockMovement(
              id: mRef.id,
              productId: entry.product.id,
              productName: entry.product.name,
              type: MovementType.exit,
              quantity: entry.item.quantity,
              reason: 'Venta: $folio',
              userName: userName,
              date: DateTime.now(),
            ).toMap(),
          );
        }

        tx.set(counterRef, {'saleFolio': folioNumber}, SetOptions(merge: true));

        final sale = Sale(
          id: '',
          folio: folio,
          items: List.unmodifiable(items),
          paymentMethod: paymentMethod,
          userName: userName,
          date: now,
        );
        tx.set(_db.collection('sales').doc(), sale.toMap());
        return sale;
      });
      return (sale: sale, error: null);
    } on _CheckoutError catch (e) {
      return (sale: null, error: e.message);
    } catch (e) {
      return (sale: null, error: 'Error al procesar la venta: $e');
    }
  }

  @override
  Future<void> cancelSale(String saleId) async {
    await _db.runTransaction<void>((tx) async {
      final saleRef = _db.collection('sales').doc(saleId);
      final saleSnap = await tx.get(saleRef);
      if (!saleSnap.exists) return;
      final sale = Sale.fromMap(saleSnap.id, saleSnap.data()!);
      if (sale.cancelled) return;

      final restores =
          <({DocumentReference<Map<String, dynamic>> ref, int newStock})>[];
      for (final item in sale.items) {
        final ref = _db.collection('products').doc(item.productId);
        final snap = await tx.get(ref);
        if (snap.exists) {
          final product = Product.fromMap(snap.id, snap.data()!);
          restores.add((ref: ref, newStock: product.stock + item.quantity));
        }
      }

      for (final restore in restores) {
        tx.update(restore.ref, {'stock': restore.newStock});
      }
      tx.update(saleRef, {'cancelled': true});
    });
  }

  // ---------------- Usuarios ----------------

  @override
  Future<void> addUser({
    required String name,
    required String email,
    required UserRole role,
  }) =>
      _db.collection('users').add(
        AppUser(id: '', name: name, email: email, role: role).toMap(),
      );

  @override
  Future<void> updateUser(AppUser updated) =>
      _db.collection('users').doc(updated.id).update(updated.toMap());

  @override
  Future<void> deleteUser(String id) =>
      _db.collection('users').doc(id).delete();
}

class _CheckoutError implements Exception {
  const _CheckoutError(this.message);
  final String message;
}
