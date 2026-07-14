import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';

/// Módulo 2 — Formulario de Producto (Solo Admin).
///
/// Crea o edita productos con: nombre, SKU/código de barras, categoría,
/// precio de costo, precio de venta, stock mínimo y máximo.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// Si es `null` el formulario crea un producto nuevo.
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _costController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _descriptionController;
  String? _categoryId;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _costController =
        TextEditingController(text: p == null ? '' : '${p.costPrice}');
    _priceController =
        TextEditingController(text: p == null ? '' : '${p.salePrice}');
    _stockController =
        TextEditingController(text: p == null ? '0' : '${p.stock}');
    _minStockController =
        TextEditingController(text: p == null ? '' : '${p.minStock}');
    _maxStockController =
        TextEditingController(text: p == null ? '' : '${p.maxStock}');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _descriptionController =
        TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _requiredNumber(String? value, {bool integer = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Campo obligatorio';
    final number = integer ? int.tryParse(text) : double.tryParse(text);
    if (number == null) return 'Número no válido';
    if (number < 0) return 'Debe ser positivo';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      showErrorSnackBar(context, 'Selecciona una categoría');
      return;
    }
    final minStock = int.parse(_minStockController.text.trim());
    final maxStock = int.parse(_maxStockController.text.trim());
    if (maxStock < minStock) {
      showErrorSnackBar(
        context,
        'El stock máximo debe ser mayor o igual al mínimo',
      );
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<InventoryRepository>();
    try {
      if (_isEditing) {
        await repo.updateProduct(widget.product!.copyWith(
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          categoryId: _categoryId,
          costPrice: double.parse(_costController.text.trim()),
          salePrice: double.parse(_priceController.text.trim()),
          minStock: minStock,
          maxStock: maxStock,
          imageUrl: _imageUrlController.text.trim(),
          description: _descriptionController.text.trim(),
        ));
      } else {
        await repo.createProduct(
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          categoryId: _categoryId!,
          costPrice: double.parse(_costController.text.trim()),
          salePrice: double.parse(_priceController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          minStock: minStock,
          maxStock: maxStock,
          imageUrl: _imageUrlController.text.trim(),
          description: _descriptionController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(
        context,
        _isEditing ? 'Producto actualizado' : 'Producto creado',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, 'No se pudo guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final numberFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    ];
    final intFormatters = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: EdgeInsets.all(context.pagePadding),
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU / Código de barras',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el SKU o código'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final category in repo.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (v) =>
                      v == null ? 'Selecciona una categoría' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: numberFormatters,
                        decoration: const InputDecoration(
                          labelText: 'Precio de costo',
                          prefixText: '\$ ',
                        ),
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: numberFormatters,
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta',
                          prefixText: '\$ ',
                        ),
                        validator: _requiredNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isEditing) ...[
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: intFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Stock inicial',
                      prefixIcon: Icon(Icons.numbers),
                      helperText:
                          'Las modificaciones posteriores se hacen en Movimientos',
                    ),
                    validator: (v) => _requiredNumber(v, integer: true),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minStockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: intFormatters,
                        decoration: const InputDecoration(
                          labelText: 'Stock mínimo',
                        ),
                        validator: (v) => _requiredNumber(v, integer: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxStockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: intFormatters,
                        decoration: const InputDecoration(
                          labelText: 'Stock máximo',
                        ),
                        validator: (v) => _requiredNumber(v, integer: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'URL de imagen (opcional)',
                    prefixIcon: Icon(Icons.image_outlined),
                    hintText: 'https://…/imagen.jpg',
                    helperText:
                        'Enlace directo a la imagen; se guarda solo la URL',
                  ),
                  validator: (v) {
                    final url = v?.trim() ?? '';
                    if (url.isEmpty) return null;
                    final uri = Uri.tryParse(url);
                    if (uri == null || !uri.isAbsolute || !url.startsWith('http')) {
                      return 'Debe ser una URL válida (http/https)';
                    }
                    return null;
                  },
                ),
                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ProductImage(
                        imageUrl: _imageUrlController.text,
                        size: 96,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vista previa — si ves el ícono gris, la URL no '
                          'carga como imagen directa.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'Guardar cambios' : 'Crear producto',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
