import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';

/// Módulo 0 — Gestión de Usuarios (solo Admin).
///
/// Alta, baja y asignación de roles para los operadores del sistema.
/// En la versión final las altas crean el usuario en Firebase Auth y su
/// documento de rol en Firestore; aquí opera sobre el repositorio local.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final padding = context.pagePadding;
    final isMobile = context.isMobile;

    final activeCount = repo.users.where((u) => u.active).length;
    final adminCount = repo.users.where((u) => u.isAdmin).length;
    final inactiveCount = repo.users.where((u) => !u.active).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo usuario'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.merlot.withValues(alpha: 0.08),
                  AppTheme.almond,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestión de usuarios',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.cocoa,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Administra roles, accesos y estado del equipo sin perder el control del negocio.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.merlot.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.group_outlined,
                    color: AppTheme.merlot,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 1 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isMobile ? 2.8 : 2.1,
            children: [
              _SummaryCard(
                title: 'Activos',
                value: '$activeCount',
                icon: Icons.verified_user,
                color: AppTheme.success,
              ),
              _SummaryCard(
                title: 'Administradores',
                value: '$adminCount',
                icon: Icons.admin_panel_settings_outlined,
                color: AppTheme.brandNavy,
              ),
              _SummaryCard(
                title: 'Inactivos',
                value: '$inactiveCount',
                icon: Icons.person_off_outlined,
                color: AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Equipo operativo'),
          const SizedBox(height: 12),
          if (repo.users.isEmpty)
            const EmptyState(
              icon: Icons.group_outlined,
              title: 'Sin usuarios registrados',
            )
          else
            GridView.count(
              crossAxisCount: isMobile ? 1 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isMobile ? 1.8 : 1.45,
              children: [for (final user in repo.users) _UserTile(user: user)],
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.cocoa,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<InventoryRepository>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    (user.isAdmin ? AppTheme.brandNavy : AppTheme.brandBlue)
                        .withValues(alpha: 0.12),
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: TextStyle(
                    color: user.isAdmin
                        ? AppTheme.brandNavy
                        : AppTheme.brandBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        decoration: user.active
                            ? null
                            : TextDecoration.lineThrough,
                        color: user.active ? AppTheme.cocoa : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _showUserForm(context, user: user);
                    case 'toggle':
                      repo.updateUser(user.copyWith(active: !user.active));
                    case 'delete':
                      _confirmDelete(context, user);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar / cambiar rol'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        user.active
                            ? Icons.person_off_outlined
                            : Icons.person_outline,
                      ),
                      title: Text(user.active ? 'Desactivar' : 'Reactivar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppTheme.danger,
                      ),
                      title: Text(
                        'Eliminar',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoleBadge(role: user.role),
              if (!user.active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppUser user) {
    final repo = context.read<InventoryRepository>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Eliminar a "${user.name}"? Perderá el acceso al sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              repo.deleteUser(user.id);
              Navigator.pop(dialogContext);
              showSuccessSnackBar(context, 'Usuario eliminado');
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Formulario de alta / edición de usuario en un diálogo modal
/// (bottom sheet en móvil quedaría igual de bien; el diálogo funciona
/// en ambos formatos).
void _showUserForm(BuildContext context, {AppUser? user}) {
  final repo = context.read<InventoryRepository>();
  final nameController = TextEditingController(text: user?.name ?? '');
  final emailController = TextEditingController(text: user?.email ?? '');
  final formKey = GlobalKey<FormState>();
  UserRole role = user?.role ?? UserRole.operator;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(user == null ? 'Nuevo usuario' : 'Editar usuario'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  enabled: user == null,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    final email = v?.trim() ?? '';
                    if (email.isEmpty) return 'Ingresa el correo';
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Correo no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.operator,
                      icon: Icon(Icons.point_of_sale_outlined),
                      label: Text('Operador'),
                    ),
                    ButtonSegment(
                      value: UserRole.admin,
                      icon: Icon(Icons.admin_panel_settings_outlined),
                      label: Text('Admin'),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (selection) =>
                      setDialogState(() => role = selection.first),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (user == null) {
                repo.addUser(
                  name: nameController.text.trim(),
                  email: emailController.text.trim().toLowerCase(),
                  role: role,
                );
              } else {
                repo.updateUser(
                  user.copyWith(name: nameController.text.trim(), role: role),
                );
              }
              Navigator.pop(dialogContext);
              showSuccessSnackBar(
                context,
                user == null ? 'Usuario creado' : 'Usuario actualizado',
              );
            },
            child: Text(user == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}
