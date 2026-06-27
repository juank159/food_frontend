// lib/features/tab_sessions/presentation/widgets/open_tabs_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/date_period.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../domain/entities/tab_session.dart';
import '../controllers/open_tabs_controller.dart';

/// Cuerpo reutilizable de "Cuentas abiertas" — SIN Scaffold ni header.
///
/// Vive en dos lugares con el MISMO código (una sola fuente de verdad):
///   1. `OpenTabsPage` (pantalla dedicada, con su header gradiente).
///   2. Embebido como segmento "Cuentas abiertas" dentro de la pantalla
///      de Órdenes — así el operario no salta entre pantallas distintas.
///
/// Muestra: barra de stats (cuentas / tickets / pendiente) + lista de
/// cuentas + botón "Abrir cuenta libre". Usa `OpenTabsController` (debe
/// estar registrado por quien lo monte: OpenTabsBinding o HomeBinding).
class OpenTabsView extends StatelessWidget {
  const OpenTabsView({super.key});

  OpenTabsController get _c => Get.find<OpenTabsController>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabsFilterBar(controller: _c),
        Expanded(
          child: Obx(() {
            if (_c.isLoading.value && _c.sessions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_c.sessions.isEmpty) {
              return _buildEmptyState();
            }
            final list = _c.filteredSessions;
            return RefreshIndicator(
              onRefresh: _c.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildStatsBar(),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          'Ninguna cuenta coincide con la búsqueda.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ...list.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TabCard(
                        session: s,
                        onTap: () => Get.toNamed(
                          AppRoutes.tabSessionDetail.replaceAll(':id', s.id),
                        )?.then((_) => _c.load()),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: () => _showOpenFreeAccountDialog(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'Abrir cuenta libre',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dialog mínimo: una etiqueta libre + cantidad de personas opcional.
  /// Al confirmar abre la cuenta y salta directo a agregar el primer
  /// ticket (`autoAddTicket`).
  Future<void> _showOpenFreeAccountDialog(BuildContext context) async {
    final labelCtrl = TextEditingController();
    final partySizeCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Abrir cuenta libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para clientes en zonas no registradas (césped, sillas zona verde, terraza).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Etiqueta',
                hintText: 'Ej. Césped #3, Silla árbol',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => Navigator.of(dialogCtx).pop(true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: partySizeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Personas (opcional)',
                prefixIcon: const Icon(Icons.group_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          Obx(() => FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                onPressed: _c.isOpening.value
                    ? null
                    : () => Navigator.of(dialogCtx).pop(true),
                child: _c.isOpening.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Abrir cuenta'),
              )),
        ],
      ),
    );
    if (result != true) return;

    final sessionId = await _c.openFreeAccount(
      label: labelCtrl.text,
      partySize: int.tryParse(partySizeCtrl.text.trim()),
    );
    if (sessionId == null) return;

    final route = AppRoutes.tabSessionDetail.replaceAll(':id', sessionId);
    await Get.toNamed<dynamic>(route, arguments: {'autoAddTicket': true});
    await _c.load();
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Cuentas',
              value: '${_c.sessions.length}',
              accent: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: _StatTile(
              label: 'Tickets',
              value: '${_c.totalTickets}',
              accent: AppColors.info,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: _StatTile(
              label: 'Pendiente',
              value: CurrencyFormatter.format(_c.totalPendingBalance),
              accent: _c.totalPendingBalance > 0
                  ? AppColors.error
                  : AppColors.success,
              valueSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // ListView (no Center) para que el RefreshIndicator/pull funcione
      // y para que el embebido no colapse de alto.
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin cuentas abiertas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cuando ocupes una mesa o abras una\ncuenta libre aparecerán acá.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Filter bar ───────────────────────

class _TabsFilterBar extends StatefulWidget {
  final OpenTabsController controller;
  const _TabsFilterBar({required this.controller});

  @override
  State<_TabsFilterBar> createState() => _TabsFilterBarState();
}

class _TabsFilterBarState extends State<_TabsFilterBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search =
        TextEditingController(text: widget.controller.searchQuery.value);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String? _customLabel() {
    final c = widget.controller;
    if (c.datePeriod.value != DatePeriod.custom) return null;
    final s = c.startDate.value;
    final e = c.endDate.value;
    if (s == null && e == null) return null;
    final sStr = s != null ? '${_two(s.day)}/${_two(s.month)}' : '—';
    final eStr = e != null ? '${_two(e.day)}/${_two(e.month)}' : '—';
    return '$sStr – $eStr';
  }

  Future<void> _pickCustomRange() async {
    final c = widget.controller;
    final now = DateTime.now();
    final current = (c.startDate.value != null && c.endDate.value != null)
        ? DateTimeRange(start: c.startDate.value!, end: c.endDate.value!)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current,
      helpText: 'Seleccioná un rango',
      saveText: 'Aplicar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      c.setDatePeriod(DatePeriod.custom,
          customStart: picked.start, customEnd: picked.end);
    }
  }

  List<ActiveFilterChipData> _activeChips() {
    final c = widget.controller;
    final chips = <ActiveFilterChipData>[];
    if (c.filterTabType.value != null) {
      chips.add(ActiveFilterChipData(
        label: c.filterTabType.value!.displayName,
        onRemove: () => c.filterByTabType(null),
      ));
    }
    if (c.filterBalance.value != null) {
      chips.add(ActiveFilterChipData(
        label: c.filterBalance.value!.displayName,
        color: c.filterBalance.value == BalanceFilter.withBalance
            ? AppColors.error
            : AppColors.success,
        onRemove: () => c.filterByBalance(null),
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Obx(() => AppFilterBar(
          searchController: _search,
          searchHint: 'Buscar cuenta por nombre…',
          onSearchChanged: c.setSearchQuery,
          period: c.datePeriod.value,
          defaultPeriod: DatePeriod.today,
          onPeriodSelected: (p) => c.setDatePeriod(p),
          onPickCustomRange: _pickCustomRange,
          customRangeLabel: _customLabel(),
          activeFilterCount: c.advancedFilterCount,
          onOpenFilters: () => AppDialog.bottomSheet(
            _TabsFiltersSheet(controller: c),
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
          ),
          activeChips: _activeChips(),
          onClearAll: c.advancedFilterCount > 0
              ? c.clearAdvancedFilters
              : null,
        ));
  }
}

class _TabsFiltersSheet extends StatelessWidget {
  final OpenTabsController controller;
  const _TabsFiltersSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Obx(() {
                if (controller.advancedFilterCount == 0) {
                  return const SizedBox.shrink();
                }
                return TextButton.icon(
                  onPressed: controller.clearAdvancedFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),

          // ── Tipo ──
          _sectionTitle('Tipo de cuenta'),
          Obx(() {
            final selected = controller.filterTabType.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppFilterChip(
                  label: 'Todas',
                  selected: selected == null,
                  onTap: () => controller.filterByTabType(null),
                ),
                for (final t in TabTypeFilter.values)
                  AppFilterChip(
                    label: t.displayName,
                    selected: selected == t,
                    onTap: () => controller.filterByTabType(
                        selected == t ? null : t),
                  ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // ── Saldo ──
          _sectionTitle('Saldo'),
          Obx(() {
            final selected = controller.filterBalance.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppFilterChip(
                  label: 'Todos',
                  selected: selected == null,
                  onTap: () => controller.filterByBalance(null),
                ),
                AppFilterChip(
                  label: BalanceFilter.withBalance.displayName,
                  selected: selected == BalanceFilter.withBalance,
                  accentColor: AppColors.error,
                  onTap: () => controller.filterByBalance(
                      selected == BalanceFilter.withBalance
                          ? null
                          : BalanceFilter.withBalance),
                ),
                AppFilterChip(
                  label: BalanceFilter.paid.displayName,
                  selected: selected == BalanceFilter.paid,
                  accentColor: AppColors.success,
                  onTap: () => controller.filterByBalance(
                      selected == BalanceFilter.paid
                          ? null
                          : BalanceFilter.paid),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Listo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final double valueSize;

  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    this.valueSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _TabCard extends StatelessWidget {
  final TabSession session;
  final VoidCallback onTap;

  const _TabCard({required this.session, required this.onTap});

  IconData _iconFor(TabSession s) {
    if (s.hasTable) return Icons.table_restaurant_outlined;
    if (s.notes != null && s.notes!.trim().isNotEmpty) {
      return Icons.chair_outlined;
    }
    return Icons.delivery_dining_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final hasBalance = session.hasPendingBalance;
    final accent = hasBalance ? AppColors.primary : AppColors.success;

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasBalance
                  ? accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: hasBalance ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(session), size: 22, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayLabel(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${session.totalOrders} ${session.totalOrders == 1 ? "ticket" : "tickets"}',
                        if (session.partySize != null && session.partySize! > 0)
                          '${session.partySize} pers.',
                        'desde ${DateFormat('HH:mm').format(session.openedAt)}',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(session.totalAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasBalance
                        ? 'Debe ${CurrencyFormatter.format(session.balance)}'
                        : 'Pagado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: hasBalance ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textHint, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
