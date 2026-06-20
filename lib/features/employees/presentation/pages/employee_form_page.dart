import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/employee_role.dart';
import '../controllers/employee_form_controller.dart';

/// Formulario de creación/edición de empleados.
///
/// Mismo lenguaje que `CategoryFormPage` / `ProductFormPage` — gradient
/// header con back, secciones con `AppFormSection` + `appInputDecoration`,
/// barra fija de submit al pie.
class EmployeeFormPage extends GetView<EmployeeFormController> {
  const EmployeeFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Form(
                  key: controller.formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPersonalSection(),
                      const SizedBox(height: 14),
                      _buildAccessSection(),
                      const SizedBox(height: 14),
                      _buildStatusSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }),
            ),
            Obx(() => AppFormSubmitBar(
                  isSaving: controller.isSaving.value,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: controller.saveEmployee,
                  saveLabel: controller.isEditMode
                      ? 'Actualizar'
                      : 'Crear empleado',
                )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: controller.isEditMode ? 'Editar empleado' : 'Nuevo empleado',
      subtitle: 'Datos personales, rol y permisos de acceso',
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
    );
  }

  // ─────────────────────── Sección personal ───────────────────────

  Widget _buildPersonalSection() {
    return AppFormSection(
      title: 'Información personal',
      subtitle: 'Cómo identificamos al empleado.',
      icon: Icons.person_outline,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.firstNameController,
                decoration: appInputDecoration(
                  label: 'Nombre *',
                  hint: 'Ej: Juan',
                  prefixIcon: Icons.badge_outlined,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requerido';
                  }
                  if (value.trim().length < 2) {
                    return 'Mínimo 2 caracteres';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller.lastNameController,
                decoration: appInputDecoration(
                  label: 'Apellido',
                  hint: 'Ej: Pérez',
                  prefixIcon: Icons.badge_outlined,
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.emailController,
          decoration: appInputDecoration(
            label: 'Email *',
            hint: 'empleado@local.com',
            prefixIcon: Icons.alternate_email,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El email es requerido';
            }
            final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                .hasMatch(value.trim());
            if (!ok) return 'Email inválido';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.phoneController,
          decoration: appInputDecoration(
            label: 'Teléfono',
            hint: '+54 11 5555-5555',
            prefixIcon: Icons.phone_outlined,
            helperText: 'Formato internacional, opcional.',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.employeeCodeController,
          decoration: appInputDecoration(
            label: 'Código de empleado',
            hint: 'EMP-001',
            prefixIcon: Icons.qr_code_2_outlined,
            helperText: 'Sólo mayúsculas, números o guiones.',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  // ─────────────────────────── Acceso ───────────────────────────

  Widget _buildAccessSection() {
    return AppFormSection(
      title: 'Acceso',
      subtitle: 'Rol asignado y credenciales de inicio de sesión.',
      icon: Icons.lock_outline,
      accent: AppColors.info,
      children: [
        Obx(() {
          final roles = controller.availableRoles;
          return DropdownButtonFormField<String>(
            initialValue: controller.selectedRoleId.value,
            decoration: appInputDecoration(
              label: 'Rol *',
              hint: roles.isEmpty
                  ? 'No hay roles disponibles'
                  : 'Seleccioná un rol',
              prefixIcon: Icons.workspace_premium_outlined,
            ),
            items: [
              for (final EmployeeRole role in roles)
                DropdownMenuItem<String>(
                  value: role.id,
                  child: Text(role.name),
                ),
            ],
            onChanged: roles.isEmpty
                ? null
                : (value) => controller.selectedRoleId.value = value,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Seleccioná un rol';
              }
              return null;
            },
          );
        }),
        if (!controller.isEditMode) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.passwordController,
            decoration: appInputDecoration(
              label: 'Contraseña inicial',
              hint: 'Opcional — el admin puede setear luego',
              prefixIcon: Icons.password_outlined,
              helperText: 'Si se completa, debe tener al menos 8 caracteres.',
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              if (value.length < 8) return 'Mínimo 8 caracteres';
              return null;
            },
          ),
        ],
      ],
    );
  }

  // ─────────────────────────── Estado ───────────────────────────

  Widget _buildStatusSection() {
    return AppFormSection(
      title: 'Estado',
      subtitle: 'Habilitá o deshabilitá la cuenta del empleado.',
      icon: Icons.toggle_on_outlined,
      accent: AppColors.success,
      children: [
        Obx(() {
          final active = controller.isActive.value;
          return SwitchListTile.adaptive(
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(
              active ? 'Empleado activo' : 'Empleado inactivo',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              active
                  ? 'Puede ingresar a la app y operar.'
                  : 'No podrá iniciar sesión hasta reactivar.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (active ? AppColors.success : AppColors.textSecondary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                active ? Icons.check_circle : Icons.block,
                color:
                    active ? AppColors.success : AppColors.textSecondary,
                size: 18,
              ),
            ),
            value: active,
            onChanged: (value) => controller.isActive.value = value,
          );
        }),
      ],
    );
  }
}
