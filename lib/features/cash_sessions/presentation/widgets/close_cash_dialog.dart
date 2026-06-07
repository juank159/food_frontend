import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../domain/entities/cash_session.dart';
import '../controllers/cash_session_controller.dart';

/// Dialog para cerrar caja con conteo de efectivo.
///
/// UX clave: el cajero ve EN VIVO la comparación entre lo contado y
/// lo esperado, con la diferencia destacada en color (rojo = falta,
/// verde = sobra, gris = cuadre). Si la diferencia es grande (>5%
/// del esperado) y intenta cerrar sin `force`, el backend devuelve
/// 400 y mostramos confirmación pidiendo que justifique.
class CloseCashDialog extends StatefulWidget {
  final CashSession session;
  const CloseCashDialog({super.key, required this.session});

  @override
  State<CloseCashDialog> createState() => _CloseCashDialogState();
}

class _CloseCashDialogState extends State<CloseCashDialog> {
  final _formKey = GlobalKey<FormState>();
  final _countedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _force = false;

  @override
  void dispose() {
    _countedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _counted =>
      (NumberFormatHelper.parseFormattedInt(_countedCtrl.text) ?? 0)
          .toDouble();

  double get _expected => widget.session.currentExpectedAmount;

  double get _difference => _counted - _expected;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = Get.find<CashSessionController>();

    // Primer intento sin force. Si el backend rechaza por diferencia
    // grande, mostramos confirmación y reintentamos con force=true.
    final ok = await controller.close(
      closingAmountCounted: _counted,
      closingNotes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      force: _force,
    );

    if (ok && mounted) {
      Get.back(result: true);
      return;
    }

    // Si la diferencia justificaba force, ofrecemos reintentar.
    if (!_force && mounted) {
      final shouldForce = await _confirmForceClose();
      if (shouldForce == true && mounted) {
        setState(() => _force = true);
        await _submit();
      }
    }
  }

  Future<bool?> _confirmForceClose() {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirmar cierre con diferencia'),
        content: Text(
          'La diferencia es de ${CurrencyFormatter.format(_difference.abs())}. '
          '${_difference < 0 ? "Falta efectivo en caja." : "Sobra efectivo en caja."}\n\n'
          'Si confirmás, la sesión se cerrará con esta diferencia '
          'registrada. Te recomendamos describir el motivo en las notas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Volver a contar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar cierre'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildExpectedSummary(),
                const SizedBox(height: 16),
                _label('Conteo (efectivo contado)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _countedCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: _inputDecoration(
                    prefix: '\$ ',
                    hint: 'Ingresá el efectivo contado',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Ingresá el monto contado';
                    }
                    final parsed = NumberFormatHelper.parseFormattedInt(v);
                    if (parsed == null) return 'Valor inválido';
                    if (parsed < 0) return 'No puede ser negativo';
                    return null;
                  },
                ),
                if (_countedCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDifferenceCard(),
                ],
                const SizedBox(height: 14),
                _label('Notas de cierre (opcional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    hint: _difference.abs() > 0.01
                        ? 'Justificá la diferencia: cambio dado sin ticket, etc.'
                        : 'Observaciones del cierre',
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() {
                  final loading =
                      Get.find<CashSessionController>().isMutating.value;
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
                            : const Icon(Icons.lock, size: 18),
                        label: Text(loading ? 'Cerrando…' : 'Cerrar caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lock_outline,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cerrar caja',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Contá el efectivo de la caja y registralo',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpectedSummary() {
    final s = widget.session;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _summaryRow('Fondo inicial', s.openingAmount),
          const SizedBox(height: 4),
          _summaryRow(
            'Cobros en efectivo (${s.totalPaymentsCount})',
            s.totalCashCollected,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _summaryRow(
            'Esperado en caja',
            _expected,
            isBold: true,
            accent: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double value, {
    bool isBold = false,
    Color? accent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: accent ?? AppColors.textPrimary,
          ),
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: FontWeight.w800,
            color: accent ?? AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDifferenceCard() {
    final isOk = _difference.abs() <= 0.01;
    final isMissing = _difference < 0;
    final color = isOk
        ? AppColors.success
        : (isMissing ? AppColors.error : AppColors.warning);
    final label = isOk
        ? 'Cuadre exacto'
        : (isMissing ? 'Faltante en caja' : 'Sobrante en caja');
    final icon = isOk
        ? Icons.check_circle
        : (isMissing ? Icons.error_outline : Icons.warning_amber_rounded);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  'Diferencia: ${_difference >= 0 ? "+" : ""}${CurrencyFormatter.format(_difference)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  InputDecoration _inputDecoration({String? prefix, String? hint}) =>
      InputDecoration(
        prefixText: prefix,
        hintText: hint,
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
