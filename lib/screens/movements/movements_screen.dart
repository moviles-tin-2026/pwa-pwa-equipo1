import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/inventory_repository.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';
import 'movement_form_screen.dart';

enum _DateFilterOption {
  all('Todas las fechas'),
  custom('Rango de fechas'),
  last7('Últimos 7 días'),
  last30('Últimos 30 días');

  const _DateFilterOption(this.label);
  final String label;
}

/// Módulo 3 — Historial de Movimientos (Ambos roles).
///
/// Bitácora de entradas y salidas con fecha, usuario responsable, tipo de
/// movimiento y cantidad. El botón "Registrar" abre el formulario ágil de
/// entrada/salida con motivo obligatorio.
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  MovementType? _typeFilter;
  String? _categoryId;
  _DateFilterOption _dateFilter = _DateFilterOption.all;
  DateTimeRange? _customDateRange;
  String? _userNameFilter;

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _categoryId != null ||
      _dateFilter != _DateFilterOption.all ||
      _userNameFilter != null;

  DateTimeRange? _effectiveDateRange() {
    final today = _today();
    switch (_dateFilter) {
      case _DateFilterOption.all:
        return null;
      case _DateFilterOption.custom:
        return _customDateRange;
      case _DateFilterOption.last7:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _DateFilterOption.last30:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
    }
  }

  List<StockMovement> _filter(InventoryRepository repo) {
    final dateRange = _effectiveDateRange();
    return repo.movements.where((m) {
      if (_typeFilter != null && m.type != _typeFilter) return false;
      if (_categoryId != null) {
        final categoryId = repo.productById(m.productId)?.categoryId;
        if (categoryId != _categoryId) return false;
      }
      if (dateRange != null) {
        final start = DateTime(
          dateRange.start.year,
          dateRange.start.month,
          dateRange.start.day,
        );
        final end = DateTime(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day,
        ).add(const Duration(days: 1));
        if (m.date.isBefore(start) || !m.date.isBefore(end)) return false;
      }
      if (_userNameFilter != null && m.userName != _userNameFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _movementUsers(InventoryRepository repo) {
    return repo.movements.map((m) => m.userName).toSet().toList()..sort();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      setState(() {
        _dateFilter = _DateFilterOption.custom;
        _customDateRange = picked;
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isDateRange(DateTimeRange range) {
    final effective = _effectiveDateRange();
    if (effective == null) return false;
    return _sameDay(effective.start, range.start) &&
        _sameDay(effective.end, range.end);
  }

  void _onDateRangeChanged(DateTimeRange? range) {
    setState(() {
      if (range == null) {
        _dateFilter = _DateFilterOption.all;
        _customDateRange = null;
        return;
      }
      final today = _today();
      final last7Start = today.subtract(const Duration(days: 6));
      final last30Start = today.subtract(const Duration(days: 29));

      if (_sameDay(range.start, today) && _sameDay(range.end, today)) {
        _dateFilter = _DateFilterOption.custom;
        _customDateRange = range;
      } else if (_sameDay(range.start, last7Start) &&
          _sameDay(range.end, today)) {
        _dateFilter = _DateFilterOption.last7;
        _customDateRange = null;
      } else if (_sameDay(range.start, last30Start) &&
          _sameDay(range.end, today)) {
        _dateFilter = _DateFilterOption.last30;
        _customDateRange = null;
      } else {
        _dateFilter = _DateFilterOption.custom;
        _customDateRange = range;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryId = null;
      _dateFilter = _DateFilterOption.all;
      _customDateRange = null;
      _userNameFilter = null;
    });
  }

  int get _activeFilterCount {
    var count = 0;
    if (_typeFilter != null) count++;
    if (_categoryId != null) count++;
    if (_dateFilter != _DateFilterOption.all) count++;
    if (_userNameFilter != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final padding = context.pagePadding;
    final movements = _filter(repo);
    final users = _movementUsers(repo);
    final wideLayout = !context.isMobile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MovementFormScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      // CustomScrollView en vez de Column+Expanded: el panel de filtros
      // (categoría + responsable apilados en móvil, rango de fechas) puede
      // superar la altura de pantallas chicas, así que todo el contenido
      // —filtros, contador y lista— comparte un solo scroll de página en
      // vez de desbordar quedando inalcanzable.
      body: PageContainer(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.merlot.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: AppTheme.merlot,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Filtros',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (_hasActiveFilters) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.peony,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_activeFilterCount activo${_activeFilterCount == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.cocoa,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Limpiar'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      const _FilterLabel(
                        icon: Icons.swap_vert,
                        label: 'Tipo de movimiento',
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<MovementType?>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(value: null, label: Text('Todos')),
                          ButtonSegment(
                            value: MovementType.entry,
                            icon: Icon(Icons.arrow_downward, size: 16),
                            label: Text('Entradas'),
                          ),
                          ButtonSegment(
                            value: MovementType.exit,
                            icon: Icon(Icons.arrow_upward, size: 16),
                            label: Text('Salidas'),
                          ),
                        ],
                        selected: {_typeFilter},
                        onSelectionChanged: (selection) =>
                            setState(() => _typeFilter = selection.first),
                      ),
                      const SizedBox(height: 20),
                      if (wideLayout)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _categoryDropdown(repo),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _userDropdown(users),
                            ),
                          ],
                        )
                      else ...[
                        _categoryDropdown(repo),
                        if (users.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _userDropdown(users),
                        ],
                      ],
                      const SizedBox(height: 20),
                      const _FilterLabel(
                        icon: Icons.calendar_month_outlined,
                        label: 'Período',
                      ),
                      const SizedBox(height: 10),
                      _DateFilterRow(
                        dateRange: _customDateRange,
                        today: _today(),
                        isDateRange: _isDateRange,
                        onPickRange: _pickDateRange,
                        onRangeChanged: _onDateRangeChanged,
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${movements.length} movimiento${movements.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
            if (movements.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.swap_vert,
                  title: repo.movements.isEmpty
                      ? 'Sin movimientos registrados'
                      : 'Sin resultados',
                  message: repo.movements.isEmpty
                      ? 'Registra entradas de compra o salidas por merma.'
                      : 'Ajusta los filtros para ver otros movimientos.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 96),
                sliver: SliverList.separated(
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _MovementCard(movement: movements[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryDropdown(InventoryRepository repo) {
    return DropdownButtonFormField<String?>(
      key: ValueKey('category-$_categoryId'),
      initialValue: _categoryId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Categoría',
        prefixIcon: Icon(Icons.category_outlined, size: 20),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Todas las categorías'),
        ),
        for (final category in repo.categories)
          DropdownMenuItem(
            value: category.id,
            child: Text(category.name),
          ),
      ],
      onChanged: (value) => setState(() => _categoryId = value),
    );
  }

  Widget _userDropdown(List<String> users) {
    if (users.isEmpty) {
      return DropdownButtonFormField<String?>(
        key: const ValueKey('user-empty'),
        initialValue: null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Responsable',
          prefixIcon: Icon(Icons.person_outline, size: 20),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(
            value: null,
            child: Text('Sin movimientos aún'),
          ),
        ],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<String?>(
      key: ValueKey('user-$_userNameFilter'),
      initialValue: _userNameFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Responsable',
        prefixIcon: Icon(Icons.person_outline, size: 20),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Todos los usuarios'),
        ),
        for (final userName in users)
          DropdownMenuItem(
            value: userName,
            child: Text(userName),
          ),
      ],
      onChanged: (value) => setState(() => _userNameFilter = value),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.mauve),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppTheme.mauve,
          ),
        ),
      ],
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({
    required this.dateRange,
    required this.today,
    required this.isDateRange,
    required this.onPickRange,
    required this.onRangeChanged,
  });

  final DateTimeRange? dateRange;
  final DateTime today;
  final bool Function(DateTimeRange range) isDateRange;
  final Future<void> Function() onPickRange;
  final ValueChanged<DateTimeRange?> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final presets = [
      (
        label: 'Hoy',
        range: DateTimeRange(start: today, end: today),
      ),
      (
        label: '7 días',
        range: DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      ),
      (
        label: '30 días',
        range: DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        ),
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            dateRange == null
                ? 'Rango personalizado'
                : '${formatDate(dateRange!.start)} – ${formatDate(dateRange!.end)}',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: dateRange != null ? AppTheme.merlot : null,
            side: BorderSide(
              color: dateRange != null
                  ? AppTheme.merlot.withValues(alpha: 0.5)
                  : AppTheme.borderColor,
            ),
          ),
        ),
        for (final preset in presets)
          ChoiceChip(
            label: Text(preset.label),
            selected: isDateRange(preset.range),
            selectedColor: AppTheme.peony,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isDateRange(preset.range)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: AppTheme.cocoa,
            ),
            onSelected: (selected) => onRangeChanged(
              selected ? preset.range : null,
            ),
          ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isEntry = movement.type == MovementType.entry;
    final color = isEntry ? AppTheme.success : AppTheme.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEntry ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movement.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDateTime(movement.date)} · ${movement.userName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isEntry ? '+' : '-'}${movement.quantity}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
