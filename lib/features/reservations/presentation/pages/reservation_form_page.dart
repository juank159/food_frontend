import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/reservation_form_controller.dart';

/// Reservation Form Page — crear o editar una reservación.
///
/// Mismo lenguaje visual que `CustomerFormPage`:
///   - Header gradient con back y título dinámico (Crear vs Editar).
///   - Secciones con `AppFormSection` + `appInputDecoration`.
///   - Steppers para party size y duration.
///   - DatePicker / TimePicker estándar.
///   - `AppFormSubmitBar` fija al pie con loading state.
class ReservationFormPage extends GetView<ReservationFormController> {
  const ReservationFormPage({super.key});

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
                    _buildCustomerSection(),
                    const SizedBox(height: 14),
                    _buildDetailsSection(context),
                    const SizedBox(height: 14),
                    _buildTableSection(),
                    const SizedBox(height: 14),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Obx(() => AppFormSubmitBar(
                  isSaving: controller.isSaving.value,
                  onCancel: () => Get.back<void>(),
                  onSave: controller.save,
                  saveLabel: controller.isEditMode
                      ? 'Actualizar reserva'
                      : 'Crear reserva',
                )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return AppGradientHeader(
      title: controller.isEditMode ? 'Editar reserva' : 'Nueva reserva',
      subtitle: controller.isEditMode
          ? 'Actualizá los detalles de la reserva'
          : 'Agendá una mesa para tu cliente',
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

  // ─────────────────────────── Customer ───────────────────────────

  Widget _buildCustomerSection() {
    return AppFormSection(
      title: 'Cliente',
      subtitle: 'Nombre obligatorio. Teléfono y email opcionales.',
      icon: Icons.person_outline,
      children: [
        TextFormField(
          controller: controller.nameController,
          decoration: appInputDecoration(
            label: 'Nombre completo *',
            hint: 'Ej: Juan Pérez',
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
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.phoneController,
          decoration: appInputDecoration(
            label: 'Teléfono',
            hint: '+57 300 123 4567',
            prefixIcon: Icons.phone_outlined,
            helperText: 'Opcional — útil para confirmar la reserva',
          ),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
          ],
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
            if (v.isEmpty) return null;
            final ok =
                RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v);
            if (!ok) return 'Email inválido';
            return null;
          },
        ),
      ],
    );
  }

  // ─────────────────────────── Details ───────────────────────────

  Widget _buildDetailsSection(BuildContext context) {
    return AppFormSection(
      title: 'Detalles de la reserva',
      subtitle: 'Cantidad de personas, fecha, hora y duración.',
      icon: Icons.event_outlined,
      accent: AppColors.info,
      children: [
        _buildPartySizeStepper(),
        const SizedBox(height: 12),
        _buildDateTimePickers(context),
        const SizedBox(height: 12),
        _buildDurationStepper(),
      ],
    );
  }

  Widget _buildPartySizeStepper() {
    return Obx(() {
      final value = controller.partySize.value;
      return _LabeledStepper(
        label: 'Cantidad de personas',
        icon: Icons.group_outlined,
        value: value.toString(),
        onDecrement: value > 1 ? controller.decrementPartySize : null,
        onIncrement: controller.incrementPartySize,
      );
    });
  }

  Widget _buildDurationStepper() {
    return Obx(() {
      final value = controller.durationMinutes.value;
      return _LabeledStepper(
        label: 'Duración estimada',
        icon: Icons.schedule,
        value: '$value min',
        onDecrement: value > 15 ? controller.decrementDuration : null,
        onIncrement: value < 480 ? controller.incrementDuration : null,
      );
    });
  }

  Widget _buildDateTimePickers(BuildContext context) {
    return Obx(() {
      final reservedFor = controller.reservedFor.value;
      final dateLabel = reservedFor != null
          ? '${reservedFor.day.toString().padLeft(2, '0')}/'
              '${reservedFor.month.toString().padLeft(2, '0')}/'
              '${reservedFor.year}'
          : 'Elegí fecha';
      final timeLabel = reservedFor != null
          ? '${reservedFor.hour.toString().padLeft(2, '0')}:'
              '${reservedFor.minute.toString().padLeft(2, '0')}'
          : 'Elegí hora';
      return Row(
        children: [
          Expanded(
            child: _PickerTile(
              icon: Icons.calendar_today_outlined,
              label: 'Fecha',
              value: dateLabel,
              onTap: () => _pickDate(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PickerTile(
              icon: Icons.access_time,
              label: 'Hora',
              value: timeLabel,
              onTap: () => _pickTime(context),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final base = controller.reservedFor.value ?? DateTime.now();
    final firstDate = controller.isEditMode
        ? base.subtract(const Duration(days: 365))
        : DateTime.now().subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) controller.setDate(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final base = controller.reservedFor.value ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (picked != null) controller.setTime(picked);
  }

  // ─────────────────────────── Table ───────────────────────────

  Widget _buildTableSection() {
    return AppFormSection(
      title: 'Mesa',
      subtitle:
          'Opcional. Podés asignar la mesa al momento de sentar al cliente.',
      icon: Icons.table_restaurant_outlined,
      accent: AppColors.warning,
      children: [
        TextFormField(
          controller: controller.tableElementIdController,
          decoration: appInputDecoration(
            label: 'ID de mesa (opcional)',
            hint: 'Ej: table-12 o T-04',
            prefixIcon: Icons.table_bar_outlined,
            helperText:
                'Identificador del elemento del plano. Lo asignás en el editor.',
          ),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  // ─────────────────────────── Notes ───────────────────────────

  Widget _buildNotesSection() {
    return AppFormSection(
      title: 'Notas',
      subtitle: 'Preferencias, cumpleaños, alergias, requerimientos.',
      icon: Icons.sticky_note_2_outlined,
      accent: AppColors.success,
      children: [
        TextFormField(
          controller: controller.notesController,
          decoration: appInputDecoration(
            label: 'Notas (opcional)',
            hint: 'Ej: Mesa cerca de la ventana. Cumpleaños del esposo.',
            prefixIcon: Icons.edit_note,
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          maxLength: 1000,
        ),
      ],
    );
  }
}

// ─────────────────────────── Sub-widgets ───────────────────────────

/// Tile clickable que muestra una etiqueta + valor — usado para fecha y hora.
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stepper compacto con etiqueta y valor central — usado para party size
/// y duration.
class _LabeledStepper extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _LabeledStepper({
    required this.label,
    required this.icon,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.remove,
            onTap: onDecrement,
          ),
          const SizedBox(width: 6),
          _StepperButton(
            icon: Icons.add,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.divider.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppColors.primary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
