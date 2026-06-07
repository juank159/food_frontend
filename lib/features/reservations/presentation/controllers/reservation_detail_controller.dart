import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/usecases/cancel_reservation_usecase.dart';
import '../../domain/usecases/delete_reservation_usecase.dart';
import '../../domain/usecases/get_reservation_by_id_usecase.dart';
import '../../domain/usecases/update_reservation_status_usecase.dart';
import './reservations_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Estado de carga para el detalle.
enum ReservationDetailStatus { loading, loaded, error }

/// Reservation Detail Controller — encapsula la carga del detalle, las
/// transiciones de estado y la cancelación / eliminación.
class ReservationDetailController extends GetxController {
  final GetReservationByIdUseCase getReservationByIdUseCase;
  final UpdateReservationStatusUseCase updateReservationStatusUseCase;
  final CancelReservationUseCase cancelReservationUseCase;
  final DeleteReservationUseCase deleteReservationUseCase;

  ReservationDetailController({
    required this.getReservationByIdUseCase,
    required this.updateReservationStatusUseCase,
    required this.cancelReservationUseCase,
    required this.deleteReservationUseCase,
  });

  // ─────────────────────────── Estado ───────────────────────────

  final Rx<ReservationDetailStatus> status =
      ReservationDetailStatus.loading.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<Reservation> reservation = Rxn<Reservation>();
  final RxBool isMutating = false.obs;

  String? reservationId;

  @override
  void onInit() {
    super.onInit();
    reservationId = Get.parameters['id'];
    if (reservationId == null || reservationId!.isEmpty) {
      status.value = ReservationDetailStatus.error;
      errorMessage.value = 'No se pudo identificar la reserva';
      return;
    }
    loadReservation();
  }

  // ─────────────────────────── Carga ───────────────────────────

  Future<void> loadReservation() async {
    if (reservationId == null) return;
    status.value = ReservationDetailStatus.loading;
    errorMessage.value = '';

    final result = await getReservationByIdUseCase(reservationId!);
    result.fold(
      (failure) {
        status.value = ReservationDetailStatus.error;
        errorMessage.value = failure.message;
      },
      (loaded) {
        reservation.value = loaded;
        status.value = ReservationDetailStatus.loaded;
      },
    );
  }

  Future<void> refreshAll() => loadReservation();

  // ─────────────────────────── Acciones ───────────────────────────

  /// Aplica una transición de estado. Devuelve `true` si fue exitosa.
  Future<bool> changeStatus(
    ReservationStatus newStatus, {
    String? notes,
  }) async {
    if (reservationId == null) return false;
    isMutating.value = true;
    final result = await updateReservationStatusUseCase(
      id: reservationId!,
      status: newStatus,
      notes: notes,
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        _snack('Error', failure.message, error: true);
        return false;
      },
      (updated) {
        reservation.value = updated;
        _refreshListIfRegistered();
        _snack(
          'Estado actualizado',
          'La reserva ahora está ${newStatus.displayName}',
        );
        return true;
      },
    );
  }

  /// Cancela la reserva con razón opcional.
  Future<bool> cancel({String? reason}) async {
    if (reservationId == null) return false;
    isMutating.value = true;
    final result = await cancelReservationUseCase(
      id: reservationId!,
      reason: reason,
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        _snack('Error', failure.message, error: true);
        return false;
      },
      (updated) {
        reservation.value = updated;
        _refreshListIfRegistered();
        _snack('Reserva cancelada', 'Se canceló la reserva correctamente');
        return true;
      },
    );
  }

  /// Elimina (soft) la reserva. Devuelve `true` si fue exitosa — la UI
  /// llamará `Get.back()` para volver al listado.
  Future<bool> delete() async {
    if (reservationId == null) return false;
    isMutating.value = true;
    final result = await deleteReservationUseCase(reservationId!);
    isMutating.value = false;
    return result.fold(
      (failure) {
        _snack('Error', failure.message, error: true);
        return false;
      },
      (_) {
        _refreshListIfRegistered();
        _snack(
          'Reserva eliminada',
          'La reservación fue eliminada correctamente',
        );
        return true;
      },
    );
  }

  // ─────────────────────────── Helpers ───────────────────────────

  void _snack(String title, String message, {bool error = false}) {
    AppSnackbar.show(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: error ? AppColors.error : AppColors.primary,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _refreshListIfRegistered() {
    if (Get.isRegistered<ReservationsController>()) {
      Get.find<ReservationsController>().refreshAll();
    }
  }

  // ─────────────────────────── Derivados ───────────────────────────

  bool get isLoading => status.value == ReservationDetailStatus.loading;
  bool get hasError => status.value == ReservationDetailStatus.error;
  bool get isLoaded => status.value == ReservationDetailStatus.loaded;
}
