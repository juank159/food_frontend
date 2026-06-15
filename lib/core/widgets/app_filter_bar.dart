import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';
import '../utils/date_period.dart';

/// Descriptor de un filtro activo, mostrado como chip removible en la
/// fila de resumen. `onRemove` lo quita; `color` opcional lo tematiza.
@immutable
class ActiveFilterChipData {
  final String label;
  final VoidCallback onRemove;
  final Color? color;
  const ActiveFilterChipData({
    required this.label,
    required this.onRemove,
    this.color,
  });
}

/// Barra de filtros COMPACTA y REUTILIZABLE.
///
/// Diseñada para vivir arriba de cualquier lista (órdenes, reportes,
/// caja, productos…) ocupando lo mínimo:
///
///   • **Una sola fila** por defecto: búsqueda + pill de período + botón
///     de filtros avanzados (con badge de conteo).
///   • Una **segunda fila** de chips removibles aparece SOLO cuando hay
///     filtros activos — así el estado por defecto no roba espacio.
///
/// Todo es opcional: si no pasás `period` no se muestra el selector de
/// período; si no pasás `onOpenFilters` no se muestra el botón de filtros;
/// si `activeChips` está vacío no se muestra la fila de resumen.
class AppFilterBar extends StatelessWidget {
  // ── Búsqueda ──
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;

  // ── Período (opcional) ──
  final DatePeriod? period;
  final ValueChanged<DatePeriod>? onPeriodSelected;

  /// Se invoca cuando el usuario elige "Rango personalizado…". La pantalla
  /// abre el date range picker y aplica el resultado (necesita context +
  /// lógica propia), por eso no lo resolvemos acá.
  final Future<void> Function()? onPickCustomRange;

  /// Texto a mostrar en el pill cuando `period == DatePeriod.custom`
  /// (ej. "12/06 – 14/06"). Si es null, usa el label del período.
  final String? customRangeLabel;

  /// Período considerado "default" (no resalta el pill). Normalmente hoy.
  final DatePeriod defaultPeriod;

  // ── Filtros avanzados (opcional) ──
  final int activeFilterCount;
  final VoidCallback? onOpenFilters;

  // ── Resumen de filtros activos (opcional) ──
  final List<ActiveFilterChipData> activeChips;
  final VoidCallback? onClearAll;

  const AppFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    this.searchHint = 'Buscar…',
    this.period,
    this.onPeriodSelected,
    this.onPickCustomRange,
    this.customRangeLabel,
    this.defaultPeriod = DatePeriod.today,
    this.activeFilterCount = 0,
    this.onOpenFilters,
    this.activeChips = const [],
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(child: _buildSearch()),
              if (period != null) ...[
                const SizedBox(width: 8),
                _PeriodPill(
                  period: period!,
                  defaultPeriod: defaultPeriod,
                  customRangeLabel: customRangeLabel,
                  onSelected: onPeriodSelected,
                  onPickCustomRange: onPickCustomRange,
                ),
              ],
              if (onOpenFilters != null) ...[
                const SizedBox(width: 8),
                _FiltersButton(
                  count: activeFilterCount,
                  onTap: onOpenFilters!,
                ),
              ],
            ],
          ),
        ),
        if (activeChips.isNotEmpty) _buildActiveChips(),
      ],
    );
  }

  Widget _buildSearch() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: searchHint,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search, size: 19),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close, size: 17),
                splashRadius: 18,
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              );
            },
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: _border(AppColors.border),
          enabledBorder: _border(AppColors.border),
          focusedBorder: _border(AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildActiveChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 30,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final chip in activeChips) ...[
              _ActiveChip(data: chip),
              const SizedBox(width: 6),
            ],
            if (onClearAll != null)
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text(
                  'Limpiar',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

// ─────────────────────────── Period pill ───────────────────────────

class _PeriodPill extends StatelessWidget {
  final DatePeriod period;
  final DatePeriod defaultPeriod;
  final String? customRangeLabel;
  final ValueChanged<DatePeriod>? onSelected;
  final Future<void> Function()? onPickCustomRange;

  const _PeriodPill({
    required this.period,
    required this.defaultPeriod,
    required this.customRangeLabel,
    required this.onSelected,
    required this.onPickCustomRange,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = period != defaultPeriod;
    final label = (period == DatePeriod.custom && customRangeLabel != null)
        ? customRangeLabel!
        : period.shortLabel;

    return PopupMenuButton<DatePeriod>(
      tooltip: 'Período',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (p) async {
        if (p == DatePeriod.custom) {
          await onPickCustomRange?.call();
        } else {
          onSelected?.call(p);
        }
      },
      itemBuilder: (_) => [
        for (final p in const [
          DatePeriod.today,
          DatePeriod.yesterday,
          DatePeriod.last7Days,
          DatePeriod.thisMonth,
          DatePeriod.all,
        ])
          _menuItem(p, p.label),
        const PopupMenuDivider(),
        PopupMenuItem<DatePeriod>(
          value: DatePeriod.custom,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: period == DatePeriod.custom
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              const Text('Rango personalizado…'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_outlined,
              size: 16,
              color: highlighted ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: highlighted ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<DatePeriod> _menuItem(DatePeriod p, String label) {
    final selected = p == period;
    return PopupMenuItem<DatePeriod>(
      value: p,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.circle_outlined,
            size: 16,
            color: selected ? AppColors.primary : Colors.transparent,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Filters button ───────────────────────────

class _FiltersButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FiltersButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: active ? 10 : 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 18,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Active chip ───────────────────────────

class _ActiveChip extends StatelessWidget {
  final ActiveFilterChipData data;
  const _ActiveChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.color ?? AppColors.primary;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: data.onRemove,
        child: Container(
          height: 30,
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.close, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
