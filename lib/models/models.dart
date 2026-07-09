/// Modelos de dominio de PyME-Sync.
///
/// Cada modelo incluye `toMap`/`fromMap` para serializarse hacia/desde
/// Cloud Firestore. El mismo modelo se usa con el repositorio local de
/// demostración (cuentas demo sin conexión).
library;

/// Roles del sistema según la matriz RBAC del documento de diseño.
enum UserRole {
  admin('Administrador'),
  operator('Operador');

  const UserRole(this.label);
  final String label;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool active;

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({String? name, UserRole? role, bool? active}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role ?? this.role,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role.name,
        'active': active,
      };

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
        id: id,
        name: (map['name'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        role: map['role'] == UserRole.admin.name
            ? UserRole.admin
            : UserRole.operator,
        active: (map['active'] ?? true) as bool,
      );
}

class Category {
  const Category({required this.id, required this.name, this.description = ''});

  final String id;
  final String name;
  final String description;

  Map<String, dynamic> toMap() => {'name': name, 'description': description};

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        name: (map['name'] ?? '') as String,
        description: (map['description'] ?? '') as String,
      );
}

enum StockStatus { ok, low, out }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    required this.costPrice,
    required this.salePrice,
    required this.stock,
    required this.minStock,
    required this.maxStock,
  });

  final String id;
  final String name;
  final String sku;
  final String categoryId;
  final double costPrice;
  final double salePrice;
  final int stock;
  final int minStock;
  final int maxStock;

  StockStatus get stockStatus {
    if (stock <= 0) return StockStatus.out;
    if (stock <= minStock) return StockStatus.low;
    return StockStatus.ok;
  }

  double get margin =>
      salePrice == 0 ? 0 : (salePrice - costPrice) / salePrice * 100;

  Product copyWith({
    String? name,
    String? sku,
    String? categoryId,
    double? costPrice,
    double? salePrice,
    int? stock,
    int? minStock,
    int? maxStock,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        categoryId: categoryId ?? this.categoryId,
        costPrice: costPrice ?? this.costPrice,
        salePrice: salePrice ?? this.salePrice,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        maxStock: maxStock ?? this.maxStock,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'sku': sku,
        'categoryId': categoryId,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'stock': stock,
        'minStock': minStock,
        'maxStock': maxStock,
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        name: (map['name'] ?? '') as String,
        sku: (map['sku'] ?? '') as String,
        categoryId: (map['categoryId'] ?? '') as String,
        costPrice: ((map['costPrice'] ?? 0) as num).toDouble(),
        salePrice: ((map['salePrice'] ?? 0) as num).toDouble(),
        stock: ((map['stock'] ?? 0) as num).toInt(),
        minStock: ((map['minStock'] ?? 0) as num).toInt(),
        maxStock: ((map['maxStock'] ?? 0) as num).toInt(),
      );
}

enum MovementType {
  entry('Entrada'),
  exit('Salida');

  const MovementType(this.label);
  final String label;
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.userName,
    required this.date,
  });

  final String id;
  final String productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final String reason;
  final String userName;
  final DateTime date;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'quantity': quantity,
        'reason': reason,
        'userName': userName,
        'date': date.millisecondsSinceEpoch,
      };

  factory StockMovement.fromMap(String id, Map<String, dynamic> map) =>
      StockMovement(
        id: id,
        productId: (map['productId'] ?? '') as String,
        productName: (map['productName'] ?? '') as String,
        type: map['type'] == MovementType.entry.name
            ? MovementType.entry
            : MovementType.exit,
        quantity: ((map['quantity'] ?? 0) as num).toInt(),
        reason: (map['reason'] ?? '') as String,
        userName: (map['userName'] ?? '') as String,
        date: DateTime.fromMillisecondsSinceEpoch(
          ((map['date'] ?? 0) as num).toInt(),
        ),
      );
}

enum PaymentMethod {
  cash('Efectivo'),
  card('Tarjeta'),
  transfer('Transferencia');

  const PaymentMethod(this.label);
  final String label;
}

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        productId: (map['productId'] ?? '') as String,
        productName: (map['productName'] ?? '') as String,
        unitPrice: ((map['unitPrice'] ?? 0) as num).toDouble(),
        quantity: ((map['quantity'] ?? 0) as num).toInt(),
      );
}

class Sale {
  const Sale({
    required this.id,
    required this.folio,
    required this.items,
    required this.paymentMethod,
    required this.userName,
    required this.date,
    this.cancelled = false,
  });

  final String id;
  final String folio;
  final List<SaleItem> items;
  final PaymentMethod paymentMethod;
  final String userName;
  final DateTime date;
  final bool cancelled;

  double get total =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Sale copyWith({bool? cancelled}) => Sale(
        id: id,
        folio: folio,
        items: items,
        paymentMethod: paymentMethod,
        userName: userName,
        date: date,
        cancelled: cancelled ?? this.cancelled,
      );

  Map<String, dynamic> toMap() => {
        'folio': folio,
        'items': [for (final item in items) item.toMap()],
        'paymentMethod': paymentMethod.name,
        'userName': userName,
        'date': date.millisecondsSinceEpoch,
        'cancelled': cancelled,
        'total': total,
      };

  factory Sale.fromMap(String id, Map<String, dynamic> map) => Sale(
        id: id,
        folio: (map['folio'] ?? '') as String,
        items: [
          for (final raw in (map['items'] ?? const []) as List)
            SaleItem.fromMap(Map<String, dynamic>.from(raw as Map)),
        ],
        paymentMethod: PaymentMethod.values.firstWhere(
          (m) => m.name == map['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        userName: (map['userName'] ?? '') as String,
        date: DateTime.fromMillisecondsSinceEpoch(
          ((map['date'] ?? 0) as num).toInt(),
        ),
        cancelled: (map['cancelled'] ?? false) as bool,
      );
}
