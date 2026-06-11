import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/utils/safe_get.dart';
import '../bindings/cash_session_binding.dart';
import '../controllers/cash_session_controller.dart';

/// Dialog para abrir caja con el fondo inicial.
class OpenCashDialog extends StatefulWidget {
  const OpenCashDialog({super.key});

  @override
  State<OpenCashDialog> createState() => _OpenCashDialogState();
}

class _OpenCashDialogState extends State<OpenCashDialog> {
  final _formKey = GlobalKey<FormState>();
  final _openingCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _openingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _openingAmount =>
      (NumberFormatHelper.parseFormattedInt(_openingCtrl.text) ?? 0)
          .toDouble();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Auto-binding: el dialog se puede abrir desde varios lugares.
    if (!Get.isRegistered<CashSessionController>()) {
      CashSessionBinding().dependencies();
    }
    final controller = Get.find<CashSessionController>();
    final ok = await controller.open(
      openingAmount: _openingAmount,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (ok && mounted) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.point_of_sale,
                        color: AppColors.success,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Abrir caja',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ingresá el efectivo con el que arranca la caja',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _label('Fondo inicial'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _openingCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: _inputDecoration(
                    prefix: '\$ ',
                    hint: '50.000',
                    helper:
                        'Efectivo ya disponible para dar cambio. 0 si no hay fondo.',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final parsed = NumberFormatHelper.parseFormattedInt(v);
                    if (parsed == null) return 'Valor inválido';
                    if (parsed < 0) return 'No puede ser negativo';
                    return null;
                  },
                ),
                if (_openingAmount > 0) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      'Equivale a ${CurrencyFormatter.format(_openingAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _label('Notas (opcional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    hint: 'Turno de la tarde, billetes de \$10.000…',
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() {
                  // Lectura opcional para el spinner del botón.
                  final loading =
                      SafeGet.find<CashSessionController>()?.isMutating.value ??
                          false;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            loading ? null : () => Get.back(result: false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: loading ? null : _submit,
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_open, size: 18),
                        label: Text(loading ? 'Abriendo…' : 'Abrir caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      );

  InputDecoration _inputDecoration({
    String? prefix,
    String? hint,
    String? helper,
  }) =>
      InputDecoration(
        prefixText: prefix,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
