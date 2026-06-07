import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/customer_form_controller.dart';

/// Customer Form Page — crear o editar cliente.
///
/// Mismo lenguaje visual que `CategoryFormPage` y `ProductFormPage`:
///   - Header gradient con back y título dinámico (Crear vs Editar).
///   - Secciones con `AppFormSection` + `appInputDecoration`.
///   - Switch de estado activo/inactivo.
///   - `AppFormSubmitBar` fija al pie con loading state.
class CustomerFormPage extends GetView<CustomerFormController> {
  const CustomerFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: controller.formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildBasicSection(),
                    const SizedBox(height: 14),
                    _buildContactSection(),
                    const SizedBox(height: 14),
                    _buildNotesSection(),
                    const SizedBox(height: 14),
                    _buildStatusSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Obx(() => AppFormSubmitBar(
                  isSaving: controller.isSaving.value,
                  onCancel: () => Get.back<void>(),
                  onSave: controller.saveCustomer,
                  saveLabel: controller.isEditMode
                      ? 'Actualizar'
                      : 'Crear cliente',
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppGradientHeader(
      title: controller.isEditMode ? 'Editar cliente' : 'Nuevo cliente',
      subtitle: controller.isEditMode
          ? 'Actualizá la información de contacto'
          : 'Sumá un cliente a tu base',
      leading: GestureDetector(
        onTap: () => Get.back<void>(),
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
    );
  }

  Widget _buildBasicSection() {
    return AppFormSection(
      title: 'Información básica',
      subtitle: 'Datos principales del cliente.',
      icon: Icons.person_outline,
      children: [
        TextFormField(
          controller: controller.nameController,
          decoration: appInputDecoration(
            label: 'Nombre completo *',
            hint: 'Ej: María Pérez',
            prefixIcon: Icons.badge_outlined,
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'El nombre es requerido';
            if (v.length < 2) return 'Mínimo 2 caracteres';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return AppFormSection(
      title: 'Contacto',
      subtitle: 'Teléfono obligatorio. Email opcional.',
      icon: Icons.contact_phone_outlined,
      accent: AppColors.info,
      children: [
        TextFormField(
          controller: controller.phoneController,
          decoration: appInputDecoration(
            label: 'Teléfono *',
            hint: '+57 300 123 4567',
            prefixIcon: Icons.phone_outlined,
            helperText: 'Lo usamos para identificar al cliente al pedir',
          ),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
          ],
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'El teléfono es requerido';
            // Validación liviana — el backend hace la validación estricta
            // por país (IsPhoneNumber('CO')). Acá sólo nos aseguramos de
            // que haya al menos 7 dígitos.
            final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.length < 7) return 'Número demasiado corto';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.emailController,
          decoration: appInputDecoration(
            label: 'Email',
            hint: 'cliente@ejemplo.com',
            prefixIcon: Icons.email_outlined,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return null; // opcional
            final ok =
                RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v);
            if (!ok) return 'Email inválido';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return AppFormSection(
      title: 'Notas',
      subtitle: 'Preferencias, alergias, instrucciones especiales.',
      icon: Icons.sticky_note_2_outlined,
      accent: AppColors.warning,
      children: [
        TextFormField(
          controller: controller.notesController,
          decoration: appInputDecoration(
            label: 'Notas (opcional)',
            hint: 'Ej: Alérgico al maní. Le gusta sin cebolla.',
            prefixIcon: Icons.edit_note,
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          maxLength: 1000,
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return AppFormSection(
      title: 'Estado',
      icon: Icons.toggle_on_outlined,
      accent: AppColors.success,
      children: [
        Obx(() {
          final active = controller.isActive.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SwitchListTile.adaptive(
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: Text(
                active ? 'Cliente activo' : 'Cliente inactivo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                active
                    ? 'Aparece en búsquedas y puede recibir pedidos'
                    : 'Oculto del flujo de creación de órdenes',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      (active ? AppColors.success : AppColors.textSecondary)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  active ? Icons.visibility : Icons.visibility_off,
                  color:
                      active ? AppColors.success : AppColors.textSecondary,
                  size: 18,
                ),
              ),
              value: active,
              onChanged: (value) => controller.isActive.value = value,
            ),
          );
        }),
      ],
    );
  }
}
