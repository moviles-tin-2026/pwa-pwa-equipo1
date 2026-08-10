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
    this.recoveryEmail = '',
    this.startSection = '',
    this.monthlyGoal = 0,
  });

  final String id;
  final String name;

  /// Correo de la cuenta: con este se inicia sesión y a este manda Firebase
  /// el enlace para restablecer la contraseña.
  final String email;
  final UserRole role;
  final bool active;

  /// Correo personal de contacto de la persona, guardado en su perfil.
  ///
  /// Firebase solo envía el restablecimiento al correo de la cuenta, así
  /// que este no recibe nada por sí solo: sirve para localizar a la persona
  /// y como origen del cambio de correo de la cuenta (ver
  /// `AuthService.startAccountEmailChange`), que es lo que sí hace que el
  /// enlace llegue a una bandeja real.
  final String recoveryEmail;

  /// Sección que abre al iniciar sesión, guardada como el `name` del enum
  /// `AppSection`. Vacío = Dashboard.
  final String startSection;

  /// Meta de ventas del mes, en la misma moneda que `Sale.total`. La fija
  /// el admin desde "Editar usuario"; `0` significa que no tiene meta
  /// definida (el medidor lo muestra como "Sin meta" en vez de 0%).
  final double monthlyGoal;

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? name,
    String? email,
    UserRole? role,
    bool? active,
    String? recoveryEmail,
    String? startSection,
    double? monthlyGoal,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        active: active ?? this.active,
        recoveryEmail: recoveryEmail ?? this.recoveryEmail,
        startSection: startSection ?? this.startSection,
        monthlyGoal: monthlyGoal ?? this.monthlyGoal,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role.name,
        'active': active,
        'recoveryEmail': recoveryEmail,
        'startSection': startSection,
        'monthlyGoal': monthlyGoal,
      };

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
        id: id,
        name: (map['name'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        role: map['role'] == UserRole.admin.name
            ? UserRole.admin
            : UserRole.operator,
        active: (map['active'] ?? true) as bool,
        recoveryEmail: (map['recoveryEmail'] ?? '') as String,
        startSection: (map['startSection'] ?? '') as String,
        monthlyGoal: ((map['monthlyGoal'] ?? 0) as num).toDouble(),
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
    this.imageUrl = '',
    this.description = '',
    this.active = true,
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

  /// URL pública directa de la imagen del producto (opción "URL externa"):
  /// Firestore solo guarda la referencia, nunca el binario.
  final String imageUrl;

  /// Descripción comercial del producto.
  final String description;

  /// `false` = producto descontinuado (baja lógica). Un producto con ventas
  /// o movimientos nunca se borra de Firestore: se desactiva para no
  /// romper la trazabilidad ni la restauración de stock al cancelar un
  /// folio antiguo. Deja de ofrecerse en el POS y en Movimientos.
  final bool active;

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
    String? imageUrl,
    String? description,
    bool? active,
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
        imageUrl: imageUrl ?? this.imageUrl,
        description: description ?? this.description,
        active: active ?? this.active,
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
        'imageUrl': imageUrl,
        'description': description,
        'active': active,
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
        imageUrl: (map['imageUrl'] ?? '') as String,
        description: (map['description'] ?? '') as String,
        active: (map['active'] ?? true) as bool,
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

/// Una sesión de conexión, para medir horas conectadas por usuario.
///
/// `AuthService` la abre al iniciar sesión y la va refrescando con un
/// heartbeat periódico mientras la app sigue abierta; `endedAt` solo se
/// llena si la persona cierra sesión de forma explícita.
class UserSession {
  const UserSession({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startedAt,
    required this.lastSeenAt,
    this.endedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final DateTime startedAt;

  /// Última vez que el heartbeat confirmó que la sesión seguía abierta.
  final DateTime lastSeenAt;

  /// `null` si la sesión sigue abierta o si se cerró la pestaña sin pasar
  /// por `signOut()` — Firebase no avisa de eso, así que nunca se llena
  /// solo. `effectiveEnd` cubre ese caso con `lastSeenAt`.
  final DateTime? endedAt;

  /// Fin efectivo para calcular duración: `endedAt` si cerró sesión limpio,
  /// o el último heartbeat si no. Evita que una pestaña cerrada sin
  /// `signOut()` cuente como "conectado" para siempre.
  DateTime get effectiveEnd => endedAt ?? lastSeenAt;

  Duration get duration => effectiveEnd.difference(startedAt);

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'lastSeenAt': lastSeenAt.millisecondsSinceEpoch,
        'endedAt': endedAt?.millisecondsSinceEpoch,
      };

  factory UserSession.fromMap(String id, Map<String, dynamic> map) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      ((map['startedAt'] ?? 0) as num).toInt(),
    );
    return UserSession(
      id: id,
      userId: (map['userId'] ?? '') as String,
      userName: (map['userName'] ?? '') as String,
      startedAt: startedAt,
      lastSeenAt: map['lastSeenAt'] == null
          ? startedAt
          : DateTime.fromMillisecondsSinceEpoch(
              (map['lastSeenAt'] as num).toInt(),
            ),
      endedAt: map['endedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (map['endedAt'] as num).toInt(),
            ),
    );
  }
}
