import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';

/// Módulo 2 — Pantalla de Categorías (Solo Admin).
///
/// Gestión simplificada de los rubros o familias de productos.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final padding = context.pagePadding;

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: repo.categories.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'Sin categorías',
                  message: 'Crea la primera categoría para tus productos.',
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 96),
                  itemCount: repo.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = repo.categories[index];
                    final productCount = repo.products
                        .where((p) => p.categoryId == category.id)
                        .length;
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.brandBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.category_outlined,
                            color: AppTheme.brandBlue,
                          ),
                        ),
                        title: Text(
                          category.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          category.description.isEmpty
                              ? '$productCount producto(s)'
                              : '${category.description} · $productCount producto(s)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showCategoryForm(
                                context,
                                category: category,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.danger,
                              ),
                              onPressed: () =>
                                  _confirmDelete(context, category),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    final repo = context.read<InventoryRepository>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar la categoría "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final deleted = await repo.deleteCategory(category.id);
              if (!context.mounted) return;
              if (deleted) {
                showSuccessSnackBar(context, 'Categoría eliminada');
              } else {
                showErrorSnackBar(
                  context,
                  'No se puede eliminar: hay productos en esta categoría',
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

void _showCategoryForm(BuildContext context, {Category? category}) {
  final repo = context.read<InventoryRepository>();
  final nameController = TextEditingController(text: category?.name ?? '');
  final descriptionController =
      TextEditingController(text: category?.description ?? '');
  final formKey = GlobalKey<FormState>();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(category == null ? 'Nueva categoría' : 'Editar categoría'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el nombre'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
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
            if (category == null) {
              repo.addCategory(
                nameController.text.trim(),
                descriptionController.text.trim(),
              );
            } else {
              repo.updateCategory(
                category.id,
                nameController.text.trim(),
                descriptionController.text.trim(),
              );
            }
            Navigator.pop(dialogContext);
            showSuccessSnackBar(
              context,
              category == null ? 'Categoría creada' : 'Categoría actualizada',
            );
          },
          child: Text(category == null ? 'Crear' : 'Guardar'),
        ),
      ],
    ),
  );
}
