// Verificación mobile-first: cada pantalla se pinta en los anchos reales
// de los dispositivos objetivo y se recogen los desbordes de layout
// (RenderFlex / RenderBox "overflowed by …") que Flutter reporta.
//
// El propósito no es cubrir lógica sino tamaños: un layout con anchos
// fijos sumados a mano (sidebar + tarjeta + padding) revienta en cuanto
// la pantalla es más angosta que esa suma, y eso solo se ve pintando.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:login_app/models/models.dart';
import 'package:login_app/screens/login/login_screen.dart';
import 'package:login_app/screens/movements/movements_screen.dart';
import 'package:login_app/screens/products/product_list_screen.dart';
import 'package:login_app/screens/sales/sales_screen.dart';
import 'package:login_app/screens/settings/settings_screen.dart';
import 'package:login_app/screens/shell/app_shell.dart';
import 'package:login_app/screens/users/users_screen.dart';
import 'package:login_app/services/auth_service.dart';
import 'package:login_app/services/inventory_repository.dart';

import 'fake_repository.dart';

/// Anchos representativos: móvil chico, móvil grande, tablet vertical,
/// tablet horizontal y escritorio.
const _viewports = <({String name, Size size})>[
  (name: 'móvil 320×568 (iPhone SE 1)', size: Size(320, 568)),
  (name: 'móvil 360×800 (Android base)', size: Size(360, 800)),
  (name: 'móvil 390×844 (iPhone 14)', size: Size(390, 844)),
  (name: 'tablet 768×1024 (iPad vertical)', size: Size(768, 1024)),
  (name: 'tablet 834×1112 (iPad Air)', size: Size(834, 1112)),
  (name: 'tablet 1024×768 (iPad horizontal)', size: Size(1024, 768)),
  (name: 'escritorio 1280×800', size: Size(1280, 800)),
];

class _FakeAuth extends AuthService {
  _FakeAuth(this._user);

  final AppUser _user;

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isAdmin => _user.isAdmin;

  @override
  bool get isLoading => false;
}

const _admin = AppUser(
  id: 'u1',
  name: 'Fernanda Administradora',
  email: 'admin@auravitae.mx',
  role: UserRole.admin,
);

const _operator = AppUser(
  id: 'u2',
  name: 'Said Operador',
  email: 'operador@auravitae.mx',
  role: UserRole.operator,
);

FakeRepository _seededRepo() {
  final repo = FakeRepository();
  repo.seedCategories(const [
    Category(id: 'c1', name: 'Limpieza facial'),
    Category(id: 'c2', name: 'Hidratación'),
    Category(id: 'c3', name: 'Protección solar'),
  ]);
  repo.seedProducts([
    for (var i = 0; i < 8; i++)
      Product(
        id: 'p$i',
        name: 'Sérum revitalizante de noche $i',
        sku: 'SKU-000$i',
        categoryId: 'c${(i % 3) + 1}',
        costPrice: 120 + i * 1.0,
        salePrice: 340 + i * 10.0,
        stock: i == 0 ? 0 : i,
        minStock: 5,
        maxStock: 40,
      ),
  ]);
  repo.seedSales([
    for (var i = 0; i < 4; i++)
      Sale(
        id: 's$i',
        folio: 'V-2026-000$i',
        items: [
          SaleItem(
            productId: 'p$i',
            productName: 'Sérum revitalizante de noche $i',
            unitPrice: 340,
            quantity: 2,
          ),
        ],
        paymentMethod: PaymentMethod.card,
        userName: 'Said Operador',
        date: DateTime.now().subtract(Duration(hours: i)),
      ),
  ]);
  repo.seedMovements([
    for (var i = 0; i < 4; i++)
      StockMovement(
        id: 'm$i',
        productId: 'p$i',
        productName: 'Sérum revitalizante de noche $i',
        type: i.isEven ? MovementType.entry : MovementType.exit,
        quantity: 3 + i,
        reason: 'Compra a proveedor: factura #100$i',
        userName: 'Said Operador',
        date: DateTime.now().subtract(Duration(days: i)),
      ),
  ]);
  repo.seedUsers(const [_admin, _operator]);
  return repo;
}

Widget _wrap(Widget child, AppUser user, InventoryRepository repo) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => _FakeAuth(user)),
      ChangeNotifierProvider<InventoryRepository>.value(value: repo),
    ],
    child: MaterialApp(home: child),
  );
}

/// Pinta [child] a [size] y devuelve los mensajes de desborde de layout.
Future<List<String>> _overflowsAt(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  final messages = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    // Solo desbordes de layout: los assets que faltan en el entorno de
    // prueba (fotos del catálogo, fondo del login) no vienen al caso.
    if (!text.contains('overflowed by')) return;
    // Se guarda también el widget culpable (línea "The relevant
    // error-causing widget was"), que es lo único accionable del reporte.
    final info = StringBuffer(details.toString());
    final extra = details.informationCollector?.call();
    if (extra != null) {
      for (final node in extra) {
        info.writeln(node.toStringDeep());
      }
    }
    final culprit = info
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains('package:login_app'))
        .join(' | ');
    messages.add('${text.split('\n').first}  ←  $culprit');
  };

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  try {
    await tester.pumpWidget(child);
    await tester.pump(const Duration(milliseconds: 400));
  } finally {
    FlutterError.onError = previous;
  }
  // Vacía la cola de excepciones no relacionadas (assets ausentes) para
  // que no hagan fallar la prueba por su cuenta.
  while (tester.takeException() != null) {}
  return messages;
}

void main() {
  final screens = <({String name, Widget Function() build, AppUser user})>[
    (name: 'Login', build: () => const LoginScreen(), user: _admin),
    (name: 'Shell + Dashboard (admin)', build: AppShell.new, user: _admin),
    (
      name: 'Shell + Dashboard (operador)',
      build: AppShell.new,
      user: _operator
    ),
    (
      name: 'Inventario',
      build: () => const ProductListScreen(),
      user: _admin,
    ),
    (name: 'Movimientos', build: () => const MovementsScreen(), user: _admin),
    (name: 'Ventas (POS + historial)', build: SalesScreen.new, user: _admin),
    (name: 'Usuarios', build: () => const UsersScreen(), user: _admin),
    (name: 'Configuración', build: SettingsScreen.new, user: _admin),
  ];

  for (final screen in screens) {
    for (final viewport in _viewports) {
      testWidgets('${screen.name} sin desbordes en ${viewport.name}',
          (tester) async {
        final overflows = await _overflowsAt(
          tester,
          viewport.size,
          _wrap(screen.build(), screen.user, _seededRepo()),
        );
        expect(
          overflows,
          isEmpty,
          reason: '${screen.name} desborda en ${viewport.name}:\n'
              '${overflows.join('\n')}',
        );
      });
    }
  }

  // El bug que motivó todo esto no producía ningún desborde: las dos
  // piezas del login viven en un `Stack`, y ahí solaparse es silencioso.
  // El layout ancho pedía 876 px (400 del panel de marca + 420 de la
  // tarjeta + 56 de margen) pero se activaba desde 700, así que en un
  // iPad en vertical la tarjeta se montaba sobre el panel. Se comprueba
  // con geometría, que no depende de la tipografía del entorno.
  group('El login nunca solapa la marca con el formulario', () {
    for (final width in [700.0, 768.0, 834.0, 900.0, 1024.0, 1280.0]) {
      testWidgets('a $width px de ancho', (tester) async {
        tester.view.physicalSize = Size(width, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(const LoginScreen(), _admin, _seededRepo()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        while (tester.takeException() != null) {}

        final brand = tester.getRect(find.text('AURA VITAE'));
        final form = tester.getRect(find.text('Iniciar sesión'));

        // Sin cruzarse: el layout ancho los pone lado a lado y el
        // compacto los apila, pero en ninguno de los dos puede la
        // tarjeta quedar encima de la marca.
        expect(
          brand.overlaps(form),
          isFalse,
          reason: 'A $width px la tarjeta del formulario ($form) se monta '
              'sobre el texto de marca ($brand)',
        );
      });
    }
  });
}
