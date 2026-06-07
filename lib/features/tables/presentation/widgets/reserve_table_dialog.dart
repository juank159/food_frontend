import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/table_status.dart';
import '../../domain/enums/table_capacity.dart';

/// Dialog para reservar una mesa. Mismo lenguaje visual que `OccupyTableDialog`
/// — header tintado de naranja (warning) por ser una acción de futuro.
class ReserveTableDialog extends StatefulWidget {
  final TableStatusEntity tableStatus;
  final Function(int partySize, String? reservationId, DateTime? reservedFor,
      String? notes) onReserve;

  const ReserveTableDialog({
    super.key,
    required this.tableStatus,
    required this.onReserve,
  });

  @override
  State<ReserveTableDialog> createState() => _ReserveTableDialogState();
}

class _ReserveTableDialogState extends State<ReserveTableDialog> {
  final _formKey = GlobalKey<FormState>();
  int _partySize = 2;
  final _reservationIdController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _reservedFor;

  @override
  void dispose() {
    _reservationIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final capacity = widget.tableStatus.tableCapacity?.toCapacityNumber();
    final maxPartySize = capacity ?? 20;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: AppColors.cardBackground,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                if (capacity != null) ...[
                  _CapacityHint(
                    capacity: capacity,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 18),
                ],
                _buildPartyStepper(maxPartySize),
                const SizedBox(height: 18),
                _buildReservationIdField(),
                const SizedBox(height: 14),
                _buildDateTimeField(),
                const SizedBox(height: 14),
                _buildNotesField(),
                const SizedBox(height: 24),
                _buildActions(),
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
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.event,
            color: AppColors.warning,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reservar ${widget.tableStatus.tableLabel ?? "mesa"}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Bloqueá la mesa para una reserva futura',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          color: AppColors.textSecondary,
          onPressed: () => Get.back(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildPartyStepper(int maxPartySize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Número de personas',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepperButton(
              icon: Icons.remove,
              enabled: _partySize > 1,
              onTap: () => setState(() => _partySize--),
            ),
            const SizedBox(width: 16),
            Container(
              width: 88,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                _partySize.toString(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _StepperButton(
              icon: Icons.add,
              enabled: _partySize < maxPartySize,
              onTap: () => setState(() => _partySize++),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReservationIdField() {
    return _LabeledField(
      label: 'ID de reservación (opcional)',
      child: TextFormField(
        controller: _reservationIdController,
        decoration: _inputDecoration('Ej: RES-12345'),
      ),
    );
  }

  Widget _buildDateTimeField() {
    final df = DateFormat('dd MMM yyyy · HH:mm');
    return _LabeledField(
      label: 'Fecha y hora',
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _reservedFor == null
                        ? 'Seleccionar fecha y hora'
                        : df.format(_reservedFor!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _reservedFor == null
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                      fontWeight: _reservedFor == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (_reservedFor != null)
                  GestureDetector(
                    onTap: () => setState(() => _reservedFor = null),
                    child: const Icon(
                      Icons.clear,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return _LabeledField(
      label: 'Notas (opcional)',
      child: TextFormField(
        controller: _notesController,
        maxLines: 3,
        decoration: _inputDecoration('Ocasión especial, peticiones…'),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onReserve(
                _partySize,
                _reservationIdController.text.isEmpty
                    ? null
                    : _reservationIdController.text,
                _reservedFor,
                _notesController.text.isEmpty ? null : _notesController.text,
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text(
            'Reservar mesa',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _reservedFor = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textHint,
        fontSize: 13,
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _CapacityHint extends StatelessWidget {
  final int capacity;
  final Color color;
  const _CapacityHint({required this.capacity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Capacidad sugerida: $capacity ${capacity == 1 ? "persona" : "personas"}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? AppColors.border : AppColors.divider,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
