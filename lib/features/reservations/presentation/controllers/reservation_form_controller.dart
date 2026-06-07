import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/usecases/create_reservation_usecase.dart';
import '../../domain/usecases/update_reservation_usecase.dart';
import './reservations_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Reservation Form Controller — crea o edita una reservación.
///
/// La reserva a editar se inyecta vía `Get.arguments` (mismo patrón que
/// `CustomerFormController`).
class ReservationFormController extends GetxController {
  final CreateReservationUseCase createReservationUseCase;
  final UpdateReservationUseCase updateReservationUseCase;

  ReservationFormController({
    required this.createReservationUseCase,
    required this.updateReservationUseCase,
  });

  final formKey = GlobalKey<FormState>();

  /// Reserva a editar (null = modo creación).
  Reservation? reservationToEdit;
  bool get isEditMode => reservationToEdit != null;

  // Estado.
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  // Campos numéricos / fecha — observables para que la UI reaccione.
  final RxInt partySize = 2.obs;
  final RxInt durationMinutes = 90.obs;
  final Rx<DateTime?> reservedFor = Rx<DateTime?>(null);

  // Controllers de los campos de texto.
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController tableElementIdController;
  late final TextEditingController notesController;

  @override
  void onInit() {
    super.onInit();
    nameController = TextEditingController();
    phoneController = TextEditingController();
    emailController = TextEditingController();
    tableElementIdController = TextEditingController();
    notesController = TextEditingController();

    // Si vino una Reservation en arguments y el binding no la seteó,
    // la levantamos acá.
    if (reservationToEdit == null && Get.arguments is Reservation) {
      reservationToEdit = Get.arguments as Reservation;
    }

    if (reservationToEdit != null) {
      _hydrateFromReservation(reservationToEdit!);
    } else {
      // Default sensato para creación: hoy a las 20:00 (cena).
      final now = DateTime.now();
      final tonight = DateTime(now.year, now.month, now.day, 20);
      // Si ya pasaron las 20h, lo proyectamos al día siguiente.
      reservedFor.value =
          tonight.isAfter(now) ? tonight : tonight.add(const Duration(days: 1));
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    tableElementIdController.dispose();
    notesController.dispose();
    super.onClose();
  }

  void _hydrateFromReservation(Reservation r) {
    nameController.text = r.customerName;
    phoneController.text = r.customerPhone ?? '';
    emailController.text = r.customerEmail ?? '';
    tableElementIdController.text = r.tableElementId ?? '';
    notesController.text = r.notes ?? '';
    partySize.value = r.partySize;
    durationMinutes.value = r.durationMinutes;
    reservedFor.value = r.reservedFor;
  }

  // ─────────────────────────── Mutadores ───────────────────────────

  void incrementPartySize() {
    if (partySize.value < 99) partySize.value++;
  }

  void decrementPartySize() {
    if (partySize.value > 1) partySize.value--;
  }

  void incrementDuration() {
    durationMinutes.value =
        (durationMinutes.value + 15).clamp(15, 480);
  }

  void decrementDuration() {
    durationMinutes.value =
        (durationMinutes.value - 15).clamp(15, 480);
  }

  /// Combina la fecha actual de `reservedFor` con la nueva fecha (manteniendo
  /// la hora). Útil cuando el usuario sólo cambió la fecha en el picker.
  void setDate(DateTime date) {
    final base = reservedFor.value ?? DateTime.now();
    reservedFor.value = DateTime(
      date.year,
      date.month,
      date.day,
      base.hour,
      base.minute,
    );
  }

  /// Combina la hora actual de `reservedFor` con la nueva hora (manteniendo
  /// la fecha).
  void setTime(TimeOfDay time) {
    final base = reservedFor.value ?? DateTime.now();
    reservedFor.value = DateTime(
      base.year,
      base.month,
      base.day,
      time.hour,
      time.minute,
    );
  }

  // ─────────────────────────── Validación ───────────────────────────

  bool _validate() {
    errorMessage.value = '';
    final state = formKey.currentState;
    if (state == null || !state.validate()) {
      errorMessage.value = 'Por favor completá los campos requeridos';
      return false;
    }
    if (reservedFor.value == null) {
      errorMessage.value = 'Elegí la fecha y hora de la reserva';
      return false;
    }
    if (!isEditMode && reservedFor.value!.isBefore(DateTime.now())) {
      errorMessage.value = 'La fecha de reserva debe ser futura';
      return false;
    }
    return true;
  }

  // ─────────────────────────── Save ───────────────────────────

  Future<void> save() async {
    if (!_validate()) {
      AppSnackbar.show(
        'Validación',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    isSaving.value = true;
    errorMessage.value = '';

    try {
      if (isEditMode) {
        await _update();
      } else {
        await _create();
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _create() async {
    final result = await createReservationUseCase(
      customerName: nameController.text.trim(),
      partySize: partySize.value,
      reservedFor: reservedFor.value!,
      customerPhone: _emptyToNull(phoneController.text),
      customerEmail: _emptyToNull(emailController.text),
      tableElementId: _emptyToNull(tableElementIdController.text),
      durationMinutes: durationMinutes.value,
      notes: _emptyToNull(notesController.text),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
      },
      (reservation) {
        AppSnackbar.show(
          'Reserva creada',
          'La reserva de ${reservation.customerName} fue agendada correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        _refreshListIfRegistered();
        Get.back<Reservation>(result: reservation);
      },
    );
  }

  Future<void> _update() async {
    final result = await updateReservationUseCase(
      id: reservationToEdit!.id,
      customerName: nameController.text.trim(),
      partySize: partySize.value,
      reservedFor: reservedFor.value!,
      customerPhone: _emptyToNull(phoneController.text),
      customerEmail: _emptyToNull(emailController.text),
      tableElementId: _emptyToNull(tableElementIdController.text),
      durationMinutes: durationMinutes.value,
      notes: _emptyToNull(notesController.text),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
      },
      (reservation) {
        AppSnackbar.show(
          'Reserva actualizada',
          'La reserva fue actualizada correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        _refreshListIfRegistered();
        Get.back<Reservation>(result: reservation);
      },
    );
  }

  void _refreshListIfRegistered() {
    if (Get.isRegistered<ReservationsController>()) {
      Get.find<ReservationsController>().refreshAll();
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
