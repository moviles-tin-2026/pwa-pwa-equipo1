import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
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

/// Shell principal responsive (mobile-first).
///
/// - Móvil (`< 700`): `NavigationBar` inferior.
/// - Tablet (`700-1099`): `NavigationRail` compacto.
/// - Web/escritorio (`>= 1100`): `NavigationRail` extendido.
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

  List<AppSection> _sectionsFor(AppUser user) => [
        AppSection.dashboard,
        AppSection.inventory,
        AppSection.movements,
        AppSection.sales,
        if (user.isAdmin) AppSection.users,
      ];

  void _goTo(AppSection section) => setState(() => _section = section);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    final sections = _sectionsFor(user);
    final selectedIndex = sections.indexOf(_section);
    final screenSize = context.screenSize;

    final body = switch (_section) {
      AppSection.dashboard => DashboardScreen(onNavigate: _goTo),
      AppSection.inventory => const ProductListScreen(),
      AppSection.movements => const MovementsScreen(),
      AppSection.sales => const SalesScreen(),
      AppSection.users => const UsersScreen(),
    };

    final appBar = AppBar(
      title: Text(_section.label),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              if (screenSize != ScreenSize.mobile) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.04,
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
                const SizedBox(width: 10),
              ],
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
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ],
    );

    if (screenSize == ScreenSize.mobile) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: NavigationBar(
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

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            extended: screenSize == ScreenSize.desktop,
            minExtendedWidth: 220,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => _goTo(sections[i]),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: screenSize == ScreenSize.desktop
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppTheme.merlot,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AURA VITAE',
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
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 9,
                                color: AppTheme.mauve,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.merlot,
                      size: 20,
                    ),
            ),
            destinations: [
              for (final section in sections)
                NavigationRailDestination(
                  icon: Icon(section.icon),
                  selectedIcon: Icon(section.selectedIcon),
                  label: Text(section.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
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
