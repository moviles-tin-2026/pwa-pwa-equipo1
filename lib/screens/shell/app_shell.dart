import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_screen.dart';
import '../movements/movements_screen.dart';
import '../products/product_list_screen.dart';
import '../sales/sales_screen.dart';
import '../users/users_screen.dart';

/// Secciones de nivel superior del sistema.
enum AppSection {
  dashboard('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
  inventory('Inventario', Icons.inventory_2_outlined, Icons.inventory_2),
  movements('Movimientos', Icons.swap_vert_outlined, Icons.swap_vert),
  sales('Ventas', Icons.point_of_sale_outlined, Icons.point_of_sale),
  users('Usuarios', Icons.group_outlined, Icons.group);

  const AppSection(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Shell principal responsive (mobile-first) con estética glassmorphism.
///
/// - Móvil (`< 700`): topbar de vidrio compacta (búsqueda, alertas,
///   usuario) + `NavigationBar` inferior.
/// - Tablet/escritorio (`>= 700`): sidebar de vidrio expandible/retráctil
///   + topbar con búsqueda global, campana de alertas de stock y clúster
///   de usuario.
///
/// El menú se filtra por rol: la sección Usuarios solo aparece para
/// Administradores (matriz RBAC del documento de diseño).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.dashboard;

  /// Estado del sidebar; `null` = según tamaño de pantalla
  /// (extendido en escritorio, compacto en tablet).
  bool? _sidebarExtended;

  /// Búsqueda pendiente para Inventario (fijada desde la búsqueda global).
  String? _inventoryQuery;

  final SearchController _searchController = SearchController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppSection> _sectionsFor(AppUser user) => [
        AppSection.dashboard,
        AppSection.inventory,
        AppSection.movements,
        AppSection.sales,
        if (user.isAdmin) AppSection.users,
      ];

  void _goTo(AppSection section, {String? searchQuery}) => setState(() {
        _section = section;
        _inventoryQuery = searchQuery;
      });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    final sections = _sectionsFor(user);
    final selectedIndex = sections.indexOf(_section);
    final screenSize = context.screenSize;
    final isMobile = screenSize == ScreenSize.mobile;

    final body = switch (_section) {
      AppSection.dashboard => DashboardScreen(onNavigate: _goTo),
      AppSection.inventory => ProductListScreen(
          key: ValueKey('inventory-${_inventoryQuery ?? ''}'),
          initialQuery: _inventoryQuery,
        ),
      AppSection.movements => const MovementsScreen(),
      AppSection.sales => const SalesScreen(),
      AppSection.users => const UsersScreen(),
    };

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AuraBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: _buildTopBar(user, compact: true),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white.withValues(alpha: 0.88),
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) => _goTo(sections[i]),
          destinations: [
            for (final section in sections)
              NavigationDestination(
                icon: Icon(section.icon),
                selectedIcon: Icon(section.selectedIcon),
                label: section.label,
              ),
          ],
        ),
      );
    }

    final extended = _sidebarExtended ?? (screenSize == ScreenSize.desktop);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GlassSidebar(
                  sections: sections,
                  selected: _section,
                  extended: extended,
                  onSelect: _goTo,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(
                        user,
                        compact: false,
                        onToggleSidebar: () => setState(
                          () => _sidebarExtended = !extended,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Topbar de vidrio: título + búsqueda + alertas + usuario ────────

  Widget _buildTopBar(
    AppUser user, {
    required bool compact,
    VoidCallback? onToggleSidebar,
  }) {
    return GlassCard(
      borderRadius: 16,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: 8,
      ),
      child: Row(
        children: [
          if (onToggleSidebar != null)
            IconButton(
              tooltip: 'Expandir / contraer menú',
              icon: const Icon(Icons.menu, color: AppTheme.mauve),
              onPressed: onToggleSidebar,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _section.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.08,
                color: AppTheme.cocoa,
              ),
            ),
          ),
          _buildSearch(compact: compact),
          const SizedBox(width: 6),
          _buildAlertsBell(),
          const SizedBox(width: 6),
          _buildUserCluster(user, compact: compact),
        ],
      ),
    );
  }

  // ── Búsqueda global de productos ───────────────────────────────────

  Widget _buildSearch({required bool compact}) {
    return SearchAnchor(
      searchController: _searchController,
      viewHintText: 'Buscar producto por nombre o SKU…',
      viewBackgroundColor: const Color(0xFFFAF5F2),
      viewSurfaceTintColor: Colors.transparent,
      builder: (context, controller) => compact
          ? IconButton(
              tooltip: 'Buscar productos',
              icon: const Icon(Icons.search, color: AppTheme.mauve),
              onPressed: () => controller.openView(),
            )
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => controller.openView(),
              child: Container(
                width: 240,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 18, color: AppTheme.mauve),
                    SizedBox(width: 8),
                    Text(
                      'Buscar productos…',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppTheme.mauve,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      suggestionsBuilder: (context, controller) {
        final query = controller.text.trim().toLowerCase();
        final repo = context.read<InventoryRepository>();
        final matches = repo.products
            .where((p) =>
                query.isEmpty ||
                p.name.toLowerCase().contains(query) ||
                p.sku.toLowerCase().contains(query))
            .take(8)
            .toList();

        if (matches.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin resultados',
                  style: TextStyle(color: AppTheme.mauve),
                ),
              ),
            ),
          ];
        }

        return [
          for (final product in matches)
            ListTile(
              leading: ProductImage(
                imageUrl: product.imageUrl,
                size: 38,
                borderRadius: 8,
              ),
              title: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'SKU ${product.sku} · Stock: ${product.stock}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                formatCurrency(product.salePrice),
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.merlot,
                ),
              ),
              onTap: () {
                controller.closeView('');
                FocusScope.of(context).unfocus();
                _goTo(AppSection.inventory, searchQuery: product.name);
              },
            ),
        ];
      },
    );
  }

  // ── Campana de alertas de stock ────────────────────────────────────

  Widget _buildAlertsBell() {
    final repo = context.watch<InventoryRepository>();
    final lowStock = repo.lowStockProducts;

    return MenuAnchor(
      alignmentOffset: const Offset(-220, 8),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFFFAF5F2)),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      builder: (context, controller, _) => IconButton(
        tooltip: 'Alertas de stock',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          isLabelVisible: lowStock.isNotEmpty,
          label: Text('${lowStock.length}'),
          backgroundColor: AppTheme.danger,
          child: const Icon(
            Icons.notifications_outlined,
            color: AppTheme.mauve,
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'ALERTAS DE STOCK',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.16,
              color: AppTheme.mauve,
            ),
          ),
        ),
        if (lowStock.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Todo en orden, sin alertas de stock',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
          )
        else ...[
          for (final product in lowStock.take(5))
            MenuItemButton(
              onPressed: () =>
                  _goTo(AppSection.inventory, searchQuery: product.name),
              leadingIcon: Icon(
                product.stockStatus == StockStatus.out
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                size: 18,
                color: product.stockStatus == StockStatus.out
                    ? AppTheme.danger
                    : AppTheme.warning,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Stock: ${product.stock} / mín. ${product.minStock}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.mauve,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 8),
          MenuItemButton(
            onPressed: () => _goTo(AppSection.inventory),
            leadingIcon: const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: AppTheme.merlot,
            ),
            child: const Text(
              'Ver inventario completo',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppTheme.merlot,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Clúster de usuario (avatar + nombre/rol + menú) ────────────────

  Widget _buildUserCluster(AppUser user, {required bool compact}) {
    return MenuAnchor(
      alignmentOffset: const Offset(-140, 8),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFFFAF5F2)),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      builder: (context, controller, _) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.peony,
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppTheme.merlot,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cocoa,
                      ),
                    ),
                    Text(
                      user.role.label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: AppTheme.mauve,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppTheme.mauve,
                ),
              ],
            ],
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppTheme.cocoa,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppTheme.mauve,
                ),
              ),
              const SizedBox(height: 6),
              RoleBadge(role: user.role),
            ],
          ),
        ),
        const Divider(height: 8),
        MenuItemButton(
          onPressed: () => _confirmSignOut(context),
          leadingIcon: const Icon(
            Icons.logout,
            size: 18,
            color: AppTheme.danger,
          ),
          child: const Text(
            'Cerrar sesión',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppTheme.danger,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context) {
    final auth = context.read<AuthService>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir del sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              auth.signOut();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

/// Sidebar de vidrio expandible/retráctil (tablet y escritorio).
class _GlassSidebar extends StatelessWidget {
  const _GlassSidebar({
    required this.sections,
    required this.selected,
    required this.extended,
    required this.onSelect,
  });

  final List<AppSection> sections;
  final AppSection selected;
  final bool extended;
  final void Function(AppSection) onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: extended ? 216 : 72,
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        // Las etiquetas se muestran según el ancho REAL disponible en cada
        // frame de la animación (no según el estado destino) para evitar
        // overflows mientras el panel crece o se contrae.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = constraints.maxWidth >= 150;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: showLabels
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.merlot,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      if (showLabels) ...[
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AURA VITAE',
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.12,
                                  color: AppTheme.cocoa,
                                ),
                              ),
                              Text(
                                'Skincare CRM',
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  color: AppTheme.mauve,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── Navegación ──
                for (final section in sections) ...[
                  _SidebarItem(
                    section: section,
                    selected: section == selected,
                    extended: showLabels,
                    onTap: () => onSelect(section),
                  ),
                  const SizedBox(height: 4),
                ],
                const Spacer(),
                if (showLabels)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'PymeSync · v1.0',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: AppTheme.mauve,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.merlot : AppTheme.mauve;

    final item = Material(
      color: selected ? AppTheme.peony : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: extended
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                selected ? section.selectedIcon : section.icon,
                color: color,
                size: 21,
              ),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.06,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return extended
        ? item
        : Tooltip(message: section.label, child: item);
  }
}

/// Envoltorio de página que limita el ancho del contenido en pantallas
/// grandes para mantener una lectura cómoda.
class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Guardia de rol: muestra [child] solo si el usuario es Admin;
/// de lo contrario muestra un aviso de acceso restringido.
class AdminOnly extends StatelessWidget {
  const AdminOnly({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthService>().isAdmin;
    if (isAdmin) return child;
    return const EmptyState(
      icon: Icons.lock_outline,
      title: 'Acceso restringido',
      message: 'Esta sección requiere rol de Administrador.',
    );
  }
}
