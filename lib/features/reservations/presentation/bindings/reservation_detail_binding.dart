import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/cancel_reservation_usecase.dart';
import '../../domain/usecases/delete_reservation_usecase.dart';
import '../../domain/usecases/get_reservation_by_id_usecase.dart';
import '../../domain/usecases/update_reservation_status_usecase.dart';
import '../controllers/reservation_detail_controller.dart';

/// Reservation Detail Binding — inyecta `ReservationDetailController`
/// con todas las acciones que la pantalla necesita (load, transición,
/// cancelar, eliminar).
class ReservationDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReservationDetailController>(
      () => ReservationDetailController(
        getReservationByIdUseCase: sl<GetReservationByIdUseCase>(),
        updateReservationStatusUseCase: sl<UpdateReservationStatusUseCase>(),
        cancelReservationUseCase: sl<CancelReservationUseCase>(),
        deleteReservationUseCase: sl<DeleteReservationUseCase>(),
      ),
    );
  }
}
