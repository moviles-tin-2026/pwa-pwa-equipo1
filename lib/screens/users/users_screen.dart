import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import 'users_helpers.dart';

/// Módulo 0 — Gestión de Usuarios (solo Admin).
///
/// Alta, baja y asignación de roles para los operadores del sistema.
/// El alta crea la cuenta en Firebase Auth y su documento de rol en
/// `users/{uid}` (ver `AuthService.createUserAccount`), así que quien se
/// da de alta puede iniciar sesión de inmediato con la contraseña temporal
/// que se muestra al terminar.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  UserRole? _roleFilter;
  bool? _statusFilter; // null = todos, true = activos, false = inactivos

  SortOption _sortOption = SortOption.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filteredUsers(InventoryRepository repo) {
    final query = _search.trim().toLowerCase();
    return repo.users.where((user) {
      if (_roleFilter != null && user.role != _roleFilter) return false;
      if (_statusFilter != null && user.active != _statusFilter) return false;
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.label.toLowerCase().contains(query);
    }).toList();
  }

  void _showUserDetail(BuildContext context, AppUser user) {
    final history = List.generate(6, (i) {
      final when = DateTime.now().subtract(Duration(hours: i * 5 + 2));
      final actions = [
        'Inició sesión',
        'Editó perfil',
        'Cambio de rol',
        'Inactivado',
        'Reactivado',
        'Registrado en el sistema',
      ];
      return (time: when, action: actions[i % actions.length]);
    });

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(user.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        (user.isAdmin ? AppTheme.brandNavy : AppTheme.brandBlue)
                            .withValues(alpha: 0.12),
                    child: Text(
                      user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        // Correo real de contacto que la persona registra
                        // en Configuración: sirve para localizarla cuando
                        // el correo de la cuenta es interno o ficticio.
                        if (user.recoveryEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Recuperación: ${user.recoveryEmail}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            RoleBadge(role: user.role),
                            const SizedBox(width: 8),
                            if (user.active)
                              const Chip(label: Text('Activo'))
                            else
                              const Chip(label: Text('Inactivo')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              const Text(
                'Historial reciente',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const Divider(height: 8),
                  itemBuilder: (context, i) {
                    final entry = history[i];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.action),
                        Text(
                          '${TimeOfDay.fromDateTime(entry.time).format(context)} · ${entry.time.day}/${entry.time.month}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final padding = context.pagePadding;
    final isMobile = context.isMobile;

    final activeCount = repo.users.where((u) => u.active).length;
    final adminCount = repo.users.where((u) => u.isAdmin).length;
    final inactiveCount = repo.users.where((u) => !u.active).length;
    final users = _filteredUsers(repo);

    // Aplicar ordenamiento seleccionado
    users.sort((a, b) {
      switch (_sortOption) {
        case SortOption.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortOption.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SortOption.role:
          return a.role.name.compareTo(b.role.name);
        case SortOption.email:
          return a.email.toLowerCase().compareTo(b.email.toLowerCase());
      }
    });

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _search = value),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, correo o rol…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<SortOption>(
                      value: _sortOption,
                      onChanged: (s) => setState(() => _sortOption = s!),
                      items: const [
                        DropdownMenuItem(
                          value: SortOption.nameAsc,
                          child: Text('Nombre A→Z'),
                        ),
                        DropdownMenuItem(
                          value: SortOption.nameDesc,
                          child: Text('Nombre Z→A'),
                        ),
                        DropdownMenuItem(
                          value: SortOption.role,
                          child: Text('Rol'),
                        ),
                        DropdownMenuItem(
                          value: SortOption.email,
                          child: Text('Correo'),
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
                    _buildRoleFilterChip(null, 'Todos'),
                    _buildRoleFilterChip(UserRole.admin, 'Administrador'),
                    _buildRoleFilterChip(UserRole.operator, 'Operador'),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Todos estados'),
                      selected: _statusFilter == null,
                      onSelected: (_) => setState(() => _statusFilter = null),
                    ),
                    FilterChip(
                      label: const Text('Activos'),
                      selected: _statusFilter == true,
                      onSelected: (s) =>
                          setState(() => _statusFilter = s ? true : null),
                    ),
                    FilterChip(
                      label: const Text('Inactivos'),
                      selected: _statusFilter == false,
                      onSelected: (s) =>
                          setState(() => _statusFilter = s ? false : null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Equipo operativo'),
          const SizedBox(height: 12),
          if (users.isEmpty)
            const EmptyState(
              icon: Icons.group_outlined,
              title: 'Sin usuarios registrados',
              message: 'Ajusta los filtros para encontrar un usuario.',
            )
          else
            GridView.count(
              crossAxisCount: isMobile ? 1 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isMobile ? 2.6 : 3.2,
              children: [
                for (final user in users)
                  InkWell(
                    onTap: () => _showUserDetail(context, user),
                    child: _UserTile(user: user),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(UserRole? role, String label) {
    return FilterChip(
      label: Text(label),
      selected: _roleFilter == role,
      onSelected: (selected) =>
          setState(() => _roleFilter = selected ? role : null),
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
                      break;
                    case 'toggle':
                      repo.updateUser(user.copyWith(active: true));
                      break;
                    case 'deactivate':
                      _confirmDeactivate(context, user);
                      break;
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
                  if (!user.active)
                    const PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Reactivar'),
                      ),
                    ),
                  if (user.active)
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: ListTile(
                        leading: Icon(
                          Icons.person_off_outlined,
                          color: AppTheme.danger,
                        ),
                        title: Text(
                          'Desactivar',
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

  void _confirmDeactivate(BuildContext context, AppUser user) {
    final repo = context.read<InventoryRepository>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text(
          '¿Desactivar a "${user.name}"? Perderá el acceso al sistema.\n\nPor seguridad, las cuentas no se pueden eliminar por completo para mantener el historial de operaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              repo.updateUser(user.copyWith(active: false));
              Navigator.pop(dialogContext);
              showSuccessSnackBar(context, 'Usuario desactivado');
            },
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }
}

/// Formulario de alta / edición de usuario en un diálogo modal
/// (bottom sheet en móvil quedaría igual de bien; el diálogo funciona
/// en ambos formatos).
///
/// El alta crea la cuenta en Firebase Authentication además del documento
/// de rol, así que el usuario puede iniciar sesión de inmediato con la
/// contraseña que se muestra al final.
void _showUserForm(BuildContext context, {AppUser? user}) {
  final auth = context.read<AuthService>();
  final repo = context.read<InventoryRepository>();
  final nameController = TextEditingController(text: user?.name ?? '');
  final emailController = TextEditingController(text: user?.email ?? '');
  final passwordController =
      TextEditingController(text: user == null ? generateTemporaryPassword() : '');
  final formKey = GlobalKey<FormState>();
  UserRole role = user?.role ?? UserRole.operator;
  var saving = false;
  String? errorMessage;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> submit() async {
          if (!formKey.currentState!.validate()) return;
          setDialogState(() {
            saving = true;
            errorMessage = null;
          });

          if (user != null) {
            await repo.updateUser(
              user.copyWith(name: nameController.text.trim(), role: role),
            );
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            showSuccessSnackBar(context, 'Usuario actualizado');
            return;
          }

          final email = emailController.text.trim().toLowerCase();
          final password = passwordController.text;
          try {
            await auth.createUserAccount(
              name: nameController.text.trim(),
              email: email,
              password: password,
              role: role,
            );
          } on AuthException catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              saving = false;
              errorMessage = e.message;
            });
            return;
          }
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          _showCredentialsDialog(context, email: email, password: password);
        }

        return AlertDialog(
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
                if (user == null) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña temporal',
                      helperText: 'El operador podrá cambiarla desde el login',
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Generar otra',
                        icon: const Icon(Icons.casino_outlined),
                        onPressed: saving
                            ? null
                            : () => setDialogState(() {
                                  passwordController.text =
                                      generateTemporaryPassword();
                                }),
                      ),
                    ),
                    validator: validateNewPassword,
                  ),
                ],
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
                  onSelectionChanged: saving
                      ? null
                      : (selection) =>
                          setDialogState(() => role = selection.first),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving ? null : submit,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(user == null ? 'Crear' : 'Guardar'),
          ),
        ],
        );
      },
    ),
  );
}

/// Entrega las credenciales al administrador después de un alta.
///
/// El correo de Firebase puede tardar o caer en spam, así que la
/// contraseña temporal se muestra aquí: es la única vez que aparece.
void _showCredentialsDialog(
  BuildContext context, {
  required String email,
  required String password,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 44),
      title: const Text('Usuario creado'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La cuenta ya puede iniciar sesión. Comparte estos datos con '
              'la persona; la contraseña no se vuelve a mostrar.',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.almond,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Correo',
                    style: TextStyle(fontSize: 11, color: AppTheme.mauve),
                  ),
                  SelectableText(email),
                  const SizedBox(height: 10),
                  const Text(
                    'Contraseña temporal',
                    style: TextStyle(fontSize: 11, color: AppTheme.mauve),
                  ),
                  SelectableText(
                    password,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
