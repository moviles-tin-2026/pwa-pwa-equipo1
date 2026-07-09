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
          const SectionHeader(title: 'Usuarios del sistema'),
          const SizedBox(height: 4),
          Text(
            'Asigna roles para controlar el acceso a cada módulo (matriz RBAC).',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (repo.users.isEmpty)
            const EmptyState(
              icon: Icons.group_outlined,
              title: 'Sin usuarios registrados',
            )
          else
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < repo.users.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _UserTile(user: repo.users[i]),
                  ],
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

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: (user.isAdmin ? AppTheme.brandNavy : AppTheme.brandBlue)
            .withValues(alpha: 0.12),
        child: Text(
          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
          style: TextStyle(
            color: user.isAdmin ? AppTheme.brandNavy : AppTheme.brandBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: user.active ? null : TextDecoration.lineThrough,
                color: user.active ? null : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoleBadge(role: user.role),
          if (!user.active) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Inactivo',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(user.email),
      trailing: PopupMenuButton<String>(
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
              leading: Icon(Icons.delete_outline, color: AppTheme.danger),
              title: Text(
                'Eliminar',
                style: TextStyle(color: AppTheme.danger),
              ),
            ),
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
