import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/entities/reservation_preorder.dart';
import '../../domain/usecases/cancel_reservation_usecase.dart';
import '../../domain/usecases/create_order_from_preorder_usecase.dart';
import '../../domain/usecases/delete_reservation_usecase.dart';
import '../../domain/usecases/get_or_create_preorder_link_usecase.dart';
import '../../domain/usecases/get_preorder_summary_usecase.dart';
import '../../domain/usecases/get_reservation_by_id_usecase.dart';
import '../../domain/usecases/set_preorder_lock_usecase.dart';
import '../../domain/usecases/update_reservation_status_usecase.dart';
import './reservations_controller.dart';
import '../../../../core/routes/app_routes.dart';
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
  final GetOrCreatePreorderLinkUseCase getOrCreatePreorderLinkUseCase;
  final SetPreorderLockUseCase setPreorderLockUseCase;
  final GetPreorderSummaryUseCase getPreorderSummaryUseCase;
  final CreateOrderFromPreorderUseCase createOrderFromPreorderUseCase;

  ReservationDetailController({
    required this.getReservationByIdUseCase,
    required this.updateReservationStatusUseCase,
    required this.cancelReservationUseCase,
    required this.deleteReservationUseCase,
    required this.getOrCreatePreorderLinkUseCase,
    required this.setPreorderLockUseCase,
    required this.getPreorderSummaryUseCase,
    required this.createOrderFromPreorderUseCase,
  });

  // ─────────────────────────── Estado ───────────────────────────

  final Rx<ReservationDetailStatus> status =
      ReservationDetailStatus.loading.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<Reservation> reservation = Rxn<Reservation>();
  final RxBool isMutating = false.obs;

  // ── Pre-pedido colaborativo ──────────────────────────────────────
  final Rxn<ReservationPreorderSummary> preorder =
      Rxn<ReservationPreorderSummary>();
  final RxBool isLoadingPreorder = false.obs;
  final RxBool isMutatingPreorder = false.obs;

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
    loadPreorder();
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

  Future<void> refreshAll() async {
    await Future.wait([loadReservation(), loadPreorder()]);
  }

  // ───────────────────── Pre-pedido colaborativo ───────────────────

  Future<void> loadPreorder() async {
    if (reservationId == null) return;
    isLoadingPreorder.value = true;
    final result = await getPreorderSummaryUseCase(reservationId!);
    isLoadingPreorder.value = false;
    result.fold(
      // Silencioso: si todavía no existe link, el backend igual devuelve
      // un resumen vacío (preorder_token null) — un error acá no debería
      // tapar el resto del detalle de la reserva.
      (failure) {},
      (summary) => preorder.value = summary,
    );
  }

  /// Genera (si hace falta) el link público y abre el panel nativo de
  /// "Compartir" (WhatsApp, Mensajes, etc.) — mismo mecanismo que ya usa
  /// "Compartir PDF" de la carta. También lo copia al portapapeles como
  /// respaldo, por si el usuario cierra el panel sin elegir nada.
  Future<void> shareOrCopyPreorderLink() async {
    if (reservationId == null) return;
    isMutatingPreorder.value = true;
    final result = await getOrCreatePreorderLinkUseCase(reservationId!);
    isMutatingPreorder.value = false;
    result.fold(
      (failure) => _snack('Error', failure.message, error: true),
      (link) async {
        await Clipboard.setData(ClipboardData(text: link.url));
        try {
          await SharePlus.instance.share(
            ShareParams(
              text:
                  'Reservaste con nosotros — elegí tus platos acá: ${link.url}',
              subject: 'Pre-pedido de la reserva',
            ),
          );
        } catch (_) {
          // Sin panel de compartir disponible (ej. desktop sin soporte) —
          // el link ya quedó copiado al portapapeles como respaldo.
          _snack(
            'Link copiado',
            'Compartilo con el grupo para que cada quién elija lo suyo',
          );
        }
        await loadPreorder();
      },
    );
  }

  /// Abre/cierra la recepción de nuevos items de invitados.
  Future<void> togglePreorderLock(bool open) async {
    if (reservationId == null) return;
    isMutatingPreorder.value = true;
    final result = await setPreorderLockUseCase(
      id: reservationId!,
      open: open,
    );
    isMutatingPreorder.value = false;
    result.fold(
      (failure) => _snack('Error', failure.message, error: true),
      (_) {
        _snack(
          open ? 'Pre-pedido abierto' : 'Pre-pedido cerrado',
          open
              ? 'Los invitados ya pueden volver a agregar platos'
              : 'Ya no se van a aceptar más platos de invitados',
        );
        loadPreorder();
      },
    );
  }

  /// Convierte el pre-pedido en una orden real (dine-in) y navega al
  /// detalle de esa orden. Paso manual y deliberado — recién disponible
  /// cuando la reserva ya está confirmada, para dejar margen a cambios
  /// de último momento del grupo antes de "cerrar" el pedido.
  Future<void> createOrderFromPreorder() async {
    if (reservationId == null) return;
    isMutatingPreorder.value = true;
    final result = await createOrderFromPreorderUseCase(reservationId!);
    isMutatingPreorder.value = false;
    await result.fold(
      (failure) async => _snack('Error', failure.message, error: true),
      (orderId) async {
        _snack('Orden creada', 'El pre-pedido ya quedó como una orden real');
        await loadPreorder();
        Get.toNamed(AppRoutes.buildOrderDetail(orderId));
      },
    );
  }

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
