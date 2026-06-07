import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/usecases/delete_reservation_usecase.dart';
import '../../domain/usecases/get_reservations_usecase.dart';
import '../../domain/usecases/get_upcoming_reservations_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Filtro inline disponible en la lista. Mapea a un `ReservationStatus`
/// concreto o a una vista derivada (próximas / hoy / todas).
enum ReservationListFilter {
  all('Todas'),
  upcoming('Próximas'),
  today('Hoy'),
  pending('Pendientes'),
  confirmed('Confirmadas');

  final String label;
  const ReservationListFilter(this.label);
}

/// Reservations Controller — listado, KPIs y acciones rápidas (eliminar).
class ReservationsController extends GetxController {
  final GetReservationsUseCase getReservationsUseCase;
  final GetUpcomingReservationsUseCase getUpcomingReservationsUseCase;
  final DeleteReservationUseCase deleteReservationUseCase;

  ReservationsController({
    required this.getReservationsUseCase,
    required this.getUpcomingReservationsUseCase,
    required this.deleteReservationUseCase,
  });

  // Estado observable.
  final RxList<Reservation> reservations = <Reservation>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Filtro activo.
  final Rx<ReservationListFilter> filter =
      ReservationListFilter.all.obs;

  @override
  void onInit() {
    super.onInit();
    loadReservations();
  }

  /// Carga la lista aplicando el filtro activo. Usamos siempre el endpoint
  /// genérico `GET /reservations` con query params para mantener consistencia
  /// (excepto para "upcoming" que tiene endpoint dedicado más eficiente).
  Future<void> loadReservations() async {
    isLoading.value = true;
    errorMessage.value = '';

    final selected = filter.value;
    final result = await _fetchByFilter(selected);

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (list) {
        // Ordenamos por reservedFor ascendente — la primera es la más próxima.
        final sorted = [...list]
          ..sort((a, b) => a.reservedFor.compareTo(b.reservedFor));
        reservations.value = sorted;
        isLoading.value = false;
      },
    );
  }

  Future<Either<Failure, List<Reservation>>> _fetchByFilter(
    ReservationListFilter f,
  ) {
    switch (f) {
      case ReservationListFilter.upcoming:
        return getUpcomingReservationsUseCase(hours: 24);
      case ReservationListFilter.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return getReservationsUseCase(dateFrom: start, dateTo: end);
      case ReservationListFilter.pending:
        return getReservationsUseCase(status: ReservationStatus.pending);
      case ReservationListFilter.confirmed:
        return getReservationsUseCase(status: ReservationStatus.confirmed);
      case ReservationListFilter.all:
        return getReservationsUseCase();
    }
  }

  Future<void> refreshAll() => loadReservations();

  void setFilter(ReservationListFilter newFilter) {
    if (filter.value == newFilter) return;
    filter.value = newFilter;
    loadReservations();
  }

  /// Elimina una reserva (soft delete). Devuelve `true` si la eliminación
  /// fue exitosa para que la UI pueda decidir si cierra un sheet, etc.
  Future<bool> deleteReservation(String id) async {
    final result = await deleteReservationUseCase(id);
    return result.fold(
      (failure) {
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return false;
      },
      (_) async {
        await refreshAll();
        AppSnackbar.show(
          'Reserva eliminada',
          'La reservación fue eliminada correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        return true;
      },
    );
  }

  // ─────────────────────────── KPIs ───────────────────────────

  /// Reservas dentro de las próximas 24h (no canceladas/no_show/completed).
  int get upcomingCount =>
      reservations.where((r) => r.isWithinNext24Hours && r.isActive).length;

  int get todayCount =>
      reservations.where((r) => r.isToday && r.isActive).length;

  int get confirmedCount =>
      reservations.where((r) => r.isConfirmed).length;

  int get pendingCount => reservations.where((r) => r.isPending).length;

  bool get hasReservations => reservations.isNotEmpty;

  // Helper para depuración — visible si hay errores no controlados.
  void debugLog(String message) {
    debugPrint('ReservationsController: $message');
  }
}
