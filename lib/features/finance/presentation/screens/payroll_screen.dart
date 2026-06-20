import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/payroll_controller.dart';

/// Nómina: pagos a empleados por período. base + extras − deducciones = neto.
class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PayrollController());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(() => AppGradientHeader(
                  title: 'Nómina',
                  subtitle:
                      'Pendiente ${CurrencyFormatter.format(c.totalPending.value)} · '
                      'Pagado ${CurrencyFormatter.format(c.totalPaid.value)}',
                  leading: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                )),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value && c.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.payments_outlined,
                    title: 'Sin nómina',
                    message:
                        'Registrá los pagos a tu equipo por período para '
                        'contabilizarlos en la ganancia del negocio.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: c.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: c.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _tile(context, c, c.items[i]),
                  ),
                );
              }),
            ),
            _bottomBar(context, c),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, PayrollController c, PayrollEntry e) {
    return Dismissible(
      key: ValueKey('pay-${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await c.remove(e);
        return false;
      },
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openForm(context, c, entry: e),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.periodLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(e.netAmount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => c.togglePaid(e),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (e.isPaid
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          e.isPaid ? 'Pagado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: e.isPaid
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, PayrollController c) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: FilledButton.icon(
          onPressed: () => _openForm(context, c),
          icon: const Icon(Icons.add),
          label: const Text('Registrar pago'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, PayrollController c,
      {PayrollEntry? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PayrollForm(controller: c, entry: entry),
    );
  }
}

class _PayrollForm extends StatefulWidget {
  final PayrollController controller;
  final PayrollEntry? entry;
  const _PayrollForm({required this.controller, this.entry});

  @override
  State<_PayrollForm> createState() => _PayrollFormState();
}

class _PayrollFormState extends State<_PayrollForm> {
  late final TextEditingController _name;
  late final TextEditingController _period;
  late final TextEditingController _base;
  late final TextEditingController _additions;
  late final TextEditingController _deductions;
  late final TextEditingController _notes;
  late bool _isPaid;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _name = TextEditingController(text: e?.employeeName ?? '');
    _period = TextEditingController(
      text: e?.periodLabel ?? _defaultPeriod(),
    );
    _base = TextEditingController(
      text: e != null ? NumberFormatHelper.formatNumber(e.baseAmount.toInt()) : '',
    );
    _additions = TextEditingController(
      text: e != null && e.additions > 0
          ? NumberFormatHelper.formatNumber(e.additions.toInt())
          : '',
    );
    _deductions = TextEditingController(
      text: e != null && e.deductions > 0
          ? NumberFormatHelper.formatNumber(e.deductions.toInt())
          : '',
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _isPaid = e?.isPaid ?? false;
  }

  String _defaultPeriod() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  double _parse(TextEditingController c) =>
      (NumberFormatHelper.parseFormattedInt(c.text) ?? 0).toDouble();
  double get _net {
    final net = _parse(_base) + _parse(_additions) - _parse(_deductions);
    return net > 0 ? net : 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _period.dispose();
    _base.dispose();
    _additions.dispose();
    _deductions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _err('Escribí el nombre del empleado');
      return;
    }
    if (_period.text.trim().isEmpty) {
      _err('Indicá el período (ej. 2026-06)');
      return;
    }
    if (_parse(_base) <= 0) {
      _err('El salario base debe ser mayor a 0');
      return;
    }
    final ok = await widget.controller.save(
      id: widget.entry?.id,
      userId: widget.entry?.userId,
      employeeName: name,
      periodLabel: _period.text,
      baseAmount: _parse(_base),
      additions: _parse(_additions),
      deductions: _parse(_deductions),
      isPaid: _isPaid,
      notes: _notes.text,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: AppColors.error),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.entry == null ? 'Nuevo pago de nómina' : 'Editar pago',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Empleado',
                  hintText: 'Nombre del empleado',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _period,
                decoration: const InputDecoration(
                  labelText: 'Período',
                  hintText: 'Ej: 2026-06 o "Junio 2026 Q1"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _base,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Salario base',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _additions,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Extras',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _deductions,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Deducciones',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Neto a pagar',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(_net),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPaid,
                activeThumbColor: AppColors.success,
                title: const Text('Marcar como pagado'),
                onChanged: (v) => setState(() => _isPaid = v),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Obx(() => FilledButton(
                          onPressed:
                              widget.controller.isSaving.value ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: widget.controller.isSaving.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Guardar'),
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
