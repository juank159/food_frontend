import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/utils/date_period.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/expenses_controller.dart';

/// Gastos del negocio (egresos). Alta/edición/borrado + total por período.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  static const _periods = [
    DatePeriod.today,
    DatePeriod.last7Days,
    DatePeriod.thisMonth,
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ExpensesController());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(() => AppGradientHeader(
                  title: 'Gastos',
                  subtitle: '${c.period.value.label} · '
                      '${CurrencyFormatter.format(c.total.value)}',
                  leading: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                )),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Obx(() => Row(
                    children: _periods
                        .map((p) => AppFilterChip(
                              label: p.label,
                              selected: c.period.value == p,
                              onTap: () => c.setPeriod(p),
                            ))
                        .toList(),
                  )),
            ),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value && c.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Sin gastos',
                    message:
                        'Registrá los egresos del negocio (arriendo, '
                        'servicios, insumos…) para saber tu ganancia real.',
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

  Widget _tile(BuildContext context, ExpensesController c, Expense e) {
    return Dismissible(
      key: ValueKey('exp-${e.id}'),
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
        return false; // la lista se recarga sola
      },
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openForm(context, c, expense: e),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.description,
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
                        '${expenseCategoryLabel(e.category)} · '
                        '${_fmtDate(e.expenseDate)}',
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
                Text(
                  CurrencyFormatter.format(e.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, ExpensesController c) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: FilledButton.icon(
          onPressed: () => _openForm(context, c),
          icon: const Icon(Icons.add),
          label: const Text('Agregar gasto'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, ExpensesController c, {Expense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _ExpenseForm(controller: c, expense: expense),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Formulario de gasto (alta/edición) en bottom sheet compacto y scrollable.
class _ExpenseForm extends StatefulWidget {
  final ExpensesController controller;
  final Expense? expense;
  const _ExpenseForm({required this.controller, this.expense});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final TextEditingController _desc;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late String _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _desc = TextEditingController(text: e?.description ?? '');
    _amount = TextEditingController(
      text: e != null ? NumberFormatHelper.formatNumber(e.amount.toInt()) : '',
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? 'supplies';
    _date = e?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _desc.text.trim();
    final amount =
        (NumberFormatHelper.parseFormattedInt(_amount.text) ?? 0).toDouble();
    if (desc.isEmpty) {
      _err('Escribí una descripción');
      return;
    }
    if (amount <= 0) {
      _err('El monto debe ser mayor a 0');
      return;
    }
    final ok = await widget.controller.save(
      id: widget.expense?.id,
      description: desc,
      category: _category,
      amount: amount,
      expenseDate: _date,
      notes: _notes.text,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: AppColors.error),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

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
                widget.expense == null ? 'Nuevo gasto' : 'Editar gasto',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Arriendo local, recibo de luz…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: kExpenseCategoryLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(ExpensesScreen._fmtDate(_date)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
