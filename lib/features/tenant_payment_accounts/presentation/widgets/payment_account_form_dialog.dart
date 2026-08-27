import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/tenant_payment_account.dart';
import '../controllers/tenant_payment_account_controller.dart';

/// Diálogo para crear o editar una cuenta de pago del tenant.
class PaymentAccountFormDialog extends StatefulWidget {
  final TenantPaymentAccount? account;

  const PaymentAccountFormDialog({super.key, this.account});

  @override
  State<PaymentAccountFormDialog> createState() =>
      _PaymentAccountFormDialogState();
}

class _PaymentAccountFormDialogState extends State<PaymentAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _accountHolderCtrl;
  late final TextEditingController _notesCtrl;
  late PaymentMethod _category;
  late bool _isActive;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameCtrl = TextEditingController(text: acc?.name ?? '');
    _accountNumberCtrl =
        TextEditingController(text: acc?.accountNumber ?? '');
    _accountHolderCtrl =
        TextEditingController(text: acc?.accountHolder ?? '');
    _notesCtrl = TextEditingController(text: acc?.notes ?? '');
    // Nequi QR ya no es una categoría seleccionable (ver dropdown más abajo);
    // si una cuenta vieja quedó con esa categoría, caemos a digitalWallet
    // para no romper el dropdown al editarla.
    final initialCategory = acc?.category ?? PaymentMethod.digitalWallet;
    _category = initialCategory == PaymentMethod.nequi
        ? PaymentMethod.digitalWallet
        : initialCategory;
    _isActive = acc?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = Get.find<TenantPaymentAccountController>();

    final name = _nameCtrl.text.trim();
    final accountNumber = _accountNumberCtrl.text.trim().isEmpty
        ? null
        : _accountNumberCtrl.text.trim();
    final accountHolder = _accountHolderCtrl.text.trim().isEmpty
        ? null
        : _accountHolderCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final ok = _isEdit
        ? await controller.updateAccount(
            id: widget.account!.id,
            name: name,
            category: _category,
            accountNumber: accountNumber,
            accountHolder: accountHolder,
            notes: notes,
            isActive: _isActive,
          )
        : await controller.createAccount(
            name: name,
            category: _category,
            accountNumber: accountNumber,
            accountHolder: accountHolder,
            notes: notes,
            isActive: _isActive,
          );

    if (ok && mounted) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TenantPaymentAccountController>();

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Editar cuenta' : 'Nueva cuenta de pago',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Estos datos los verá el cajero al cobrar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                _label('Categoría'),
                const SizedBox(height: 6),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _category,
                  items: PaymentMethod.values
                      .where((m) => m != PaymentMethod.nequi)
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 14),
                _label('Nombre visible *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration(hint: 'Ej. Nequi Personal'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresá un nombre';
                    }
                    if (v.length > 100) return 'Máx. 100 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label('Titular'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _accountHolderCtrl,
                  decoration: _inputDecoration(hint: 'Ej. Juan Pérez'),
                  validator: (v) =>
                      (v != null && v.length > 150) ? 'Máx. 150' : null,
                ),
                const SizedBox(height: 14),
                _label('Número / Identificador'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _accountNumberCtrl,
                  decoration: _inputDecoration(hint: 'Ej. ***1234'),
                  validator: (v) =>
                      (v != null && v.length > 50) ? 'Máx. 50' : null,
                ),
                const SizedBox(height: 14),
                _label('Notas internas'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    hint: 'Ej. Solo aceptar antes de las 6 PM',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Switch.adaptive(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeThumbColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Activa para nuevos pagos',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => ElevatedButton(
                        onPressed:
                            controller.isSaving.value ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        child: controller.isSaving.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEdit ? 'Guardar' : 'Crear'),
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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
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
        isDense: true,
      );
}
