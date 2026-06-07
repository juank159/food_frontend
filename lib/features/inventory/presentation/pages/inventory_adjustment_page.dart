import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/inventory_item.dart';
import '../controllers/inventory_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Inventory Adjustment Page
///
/// Form de ajuste de stock para un item ya seleccionado por el listado.
/// Estructura:
///
///   - Header gradient con nombre del producto y stock actual.
///   - `AppFormSection` "Producto" (read-only, sólo informa).
///   - `AppFormSection` "Cantidad nueva" + umbral mínimo.
///   - `AppFormSection` "Motivo" — textarea libre que se manda al backend
///     como metadata.
///   - `AppFormSubmitBar` con Cancelar / Guardar.
///
/// Si llega aquí sin item seleccionado (deep-link manual), muestra un
/// estado vacío que invita a volver al listado.
class InventoryAdjustmentPage extends GetView<InventoryController> {
  const InventoryAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final item = controller.editingItem.value;
          if (item == null) {
            return Column(
              children: [
                AppGradientHeader(
                  title: 'Ajuste de stock',
                  subtitle: 'Sin producto seleccionado',
                  leading: IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const Expanded(
                  child: AppEmptyState(
                    icon: Icons.tune,
                    title: 'Elegí un producto',
                    message:
                        'Volvé al listado de inventario y tocá "Ajustar" en alguno de los productos.',
                  ),
                ),
              ],
            );
          }
          return _AdjustmentForm(item: item, controller: controller);
        }),
      ),
    );
  }
}

class _AdjustmentForm extends StatefulWidget {
  final InventoryItem item;
  final InventoryController controller;

  const _AdjustmentForm({required this.item, required this.controller});

  @override
  State<_AdjustmentForm> createState() => _AdjustmentFormState();
}

class _AdjustmentFormState extends State<_AdjustmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _stockCtrl = TextEditingController(
      text: (widget.item.currentStock ?? 0).toString(),
    );
    _minCtrl = TextEditingController(
      text: widget.item.minStockAlert?.toString() ?? '',
    );
    _reasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _stockCtrl.dispose();
    _minCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final stock = int.parse(_stockCtrl.text.trim());
    final minRaw = _minCtrl.text.trim();
    final min = minRaw.isEmpty ? null : int.tryParse(minRaw);
    final reason = _reasonCtrl.text.trim();
    final ok = await widget.controller.submitAdjustment(
      newStock: stock,
      minStockAlert: min,
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    if (ok) {
      Get.back();
      AppSnackbar.show(
        'Stock actualizado',
        'El inventario de "${widget.item.name}" se ajustó a $stock unidades.',
        backgroundColor: AppColors.success.withValues(alpha: 0.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } else {
      AppSnackbar.show(
        'No se pudo ajustar',
        widget.controller.saveError.value.isEmpty
            ? 'Intentá nuevamente en unos segundos.'
            : widget.controller.saveError.value,
        backgroundColor: AppColors.error.withValues(alpha: 0.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Column(
      children: [
        AppGradientHeader(
          title: 'Ajustar stock',
          subtitle: item.name,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          hero: AppKpiHero(
            icon: Icons.inventory_2_outlined,
            label: 'Stock actual',
            value: (item.currentStock ?? 0).toString(),
            hint: item.minStockAlert == null
                ? 'Sin umbral mínimo configurado'
                : 'Mínimo configurado: ${item.minStockAlert}',
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AppFormSection(
                  title: 'Producto',
                  subtitle: 'No editable desde acá. Para renombrar, usá Productos.',
                  icon: Icons.label_outline,
                  children: [
                    _ReadOnlyRow(label: 'Nombre', value: item.name),
                    const SizedBox(height: 8),
                    _ReadOnlyRow(
                      label: 'SKU',
                      value: (item.sku == null || item.sku!.isEmpty)
                          ? '—'
                          : item.sku!,
                    ),
                    const SizedBox(height: 8),
                    _ReadOnlyRow(
                      label: 'Trackea inventario',
                      value: item.trackInventory ? 'Sí' : 'No',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormSection(
                  title: 'Nuevo nivel de stock',
                  subtitle:
                      'El valor que ingreses reemplaza el actual (no se suma).',
                  icon: Icons.tune,
                  children: [
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: appInputDecoration(
                        label: 'Cantidad nueva',
                        prefixIcon: Icons.numbers,
                        helperText: 'Unidades disponibles después del ajuste',
                      ),
                      validator: (v) {
                        final raw = v?.trim() ?? '';
                        if (raw.isEmpty) return 'Ingresá la cantidad';
                        final n = int.tryParse(raw);
                        if (n == null) return 'Sólo números enteros';
                        if (n < 0) return 'No puede ser negativo';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: appInputDecoration(
                        label: 'Umbral de alerta (opcional)',
                        prefixIcon: Icons.warning_amber_rounded,
                        helperText:
                            'Si el stock cae a este valor o menos se marca como bajo',
                      ),
                      validator: (v) {
                        final raw = v?.trim() ?? '';
                        if (raw.isEmpty) return null;
                        final n = int.tryParse(raw);
                        if (n == null) return 'Sólo números enteros';
                        if (n < 0) return 'No puede ser negativo';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormSection(
                  title: 'Motivo del ajuste',
                  subtitle:
                      'Recomendado para auditoría: rotura, recepción, conteo manual, etc.',
                  icon: Icons.notes,
                  children: [
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 4,
                      maxLength: 280,
                      decoration: appInputDecoration(
                        label: 'Detalle (opcional)',
                        hint: 'Ej: Conteo de cierre — sobraban 3 unidades.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Obx(() => AppFormSubmitBar(
              onCancel: () => Get.back(),
              onSave: _submit,
              isSaving: widget.controller.isSaving.value,
              saveLabel: 'Guardar ajuste',
            )),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
