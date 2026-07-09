import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';

/// Módulo 3 — Registro de Movimiento (Operador y Admin).
///
/// Formulario ágil para ingresar stock (compra a proveedor) o retirar
/// stock (merma, daño o caducidad) con motivo obligatorio. La escritura
/// valida el stock disponible antes de aplicar la salida.
class MovementFormScreen extends StatefulWidget {
  const MovementFormScreen({super.key});

  @override
  State<MovementFormScreen> createState() => _MovementFormScreenState();
}

class _MovementFormScreenState extends State<MovementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();

  MovementType _type = MovementType.entry;
  String? _productId;
  String? _reasonPreset;
  bool _saving = false;

  static const _entryReasons = ['Compra a proveedor', 'Devolución de cliente'];
  static const _exitReasons = [
    'Merma',
    'Producto dañado',
    'Caducidad',
    'Ajuste de inventario',
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final reason = [
      ?_reasonPreset,
      if (_reasonController.text.trim().isNotEmpty)
        _reasonController.text.trim(),
    ].join(': ');

    if (reason.isEmpty) {
      showErrorSnackBar(context, 'El motivo es obligatorio');
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<InventoryRepository>();
    final user = context.read<AuthService>().currentUser!;

    final error = await repo.registerMovement(
      productId: _productId!,
      type: _type,
      quantity: int.parse(_quantityController.text.trim()),
      reason: reason,
      userName: user.name,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      showErrorSnackBar(context, error);
      return;
    }
    Navigator.of(context).pop();
    showSuccessSnackBar(
      context,
      _type == MovementType.entry ? 'Entrada registrada' : 'Salida registrada',
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final product = _productId == null ? null : repo.productById(_productId!);
    final reasons =
        _type == MovementType.entry ? _entryReasons : _exitReasons;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar movimiento')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(context.pagePadding),
              children: [
                SegmentedButton<MovementType>(
                  segments: const [
                    ButtonSegment(
                      value: MovementType.entry,
                      icon: Icon(Icons.arrow_downward),
                      label: Text('Entrada'),
                    ),
                    ButtonSegment(
                      value: MovementType.exit,
                      icon: Icon(Icons.arrow_upward),
                      label: Text('Salida'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) => setState(() {
                    _type = selection.first;
                    _reasonPreset = null;
                  }),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Producto',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: [
                    for (final p in repo.products)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name} (stock: ${p.stock})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _productId = value),
                  validator: (v) =>
                      v == null ? 'Selecciona un producto' : null,
                ),
                if (product != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Stock actual: ${product.stock}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      StockStatusChip(status: product.stockStatus),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa la cantidad';
                    final quantity = int.tryParse(text);
                    if (quantity == null || quantity <= 0) {
                      return 'Cantidad no válida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Motivo (obligatorio)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reason in reasons)
                      ChoiceChip(
                        label: Text(reason),
                        selected: _reasonPreset == reason,
                        onSelected: (selected) => setState(
                          () => _reasonPreset = selected ? reason : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Detalle del motivo',
                    hintText: 'Ej. factura #123 del proveedor…',
                  ),
                  validator: (v) {
                    if (_reasonPreset == null &&
                        (v == null || v.trim().isEmpty)) {
                      return 'Selecciona un motivo o descríbelo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: _type == MovementType.exit
                      ? FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        )
                      : null,
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
                      : Icon(
                          _type == MovementType.entry
                              ? Icons.add_box_outlined
                              : Icons.indeterminate_check_box_outlined,
                        ),
                  label: Text(
                    _type == MovementType.entry
                        ? 'Registrar entrada'
                        : 'Registrar salida',
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
