import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_form_section.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../controllers/edit_order_controller.dart';

/// Página para editar metadata de una orden existente.
///
/// Solo edita: instrucciones especiales, tiempo estimado, nombre de
/// cliente walk-in. Tabla, items y modifiers no son editables desde
/// acá — para esos casos hay que cancelar y recrear (limitación
/// conocida; el backend no expone aún `replaceItems`).
class EditOrderPage extends GetView<EditOrderController> {
  const EditOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        final order = controller.order.value;
        if (controller.isLoading.value && order == null) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.errorMessage.value.isNotEmpty && order == null) {
          return SafeArea(
            child: AppErrorState(
              message: controller.errorMessage.value,
              onRetry: controller.load,
            ),
          );
        }
        if (order == null) {
          return const SafeArea(
            child: Center(child: Text('Orden no encontrada')),
          );
        }

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppGradientHeader(
                title: 'Editar orden',
                subtitle: 'Orden ${order.orderNumber}',
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Form(
                  key: controller.formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildScopeBanner(),
                      AppFormSection(
                        title: 'Información general',
                        children: [
                          TextFormField(
                            controller: controller.customerNameController,
                            decoration: appInputDecoration(
                              label: 'Nombre del cliente',
                              hint: 'Para órdenes walk-in / takeout',
                              prefixIcon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: controller.estimatedTimeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: appInputDecoration(
                              label: 'Tiempo estimado (minutos)',
                              hint: 'Ej. 25',
                              prefixIcon: Icons.timer_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final n = int.tryParse(value.trim());
                              if (n == null || n < 0) {
                                return 'Tiempo inválido';
                              }
                              if (n > 600) {
                                return 'Máximo 600 min';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppFormSection(
                        title: 'Instrucciones especiales',
                        children: [
                          TextFormField(
                            controller:
                                controller.specialInstructionsController,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: appInputDecoration(
                              label: 'Notas para la cocina',
                              hint:
                                  'Ej. "Sin tomate", "Empacar para llevar"...',
                              prefixIcon: Icons.sticky_note_2_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Obx(() => AppFormSubmitBar(
                    isSaving: controller.isSaving.value,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: controller.save,
                    saveLabel: 'Guardar cambios',
                  )),
            ],
          ),
        );
      }),
    );
  }

  /// Banner que aclara el alcance limitado de esta edición. Sin esto el
  /// operario abre el form esperando poder cambiar items y se confunde.
  Widget _buildScopeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Solo se pueden modificar instrucciones, tiempo estimado y cliente. Para cambiar productos o cantidades, cancelá la orden y creá una nueva.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
