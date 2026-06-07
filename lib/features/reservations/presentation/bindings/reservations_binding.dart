import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/delete_reservation_usecase.dart';
import '../../domain/usecases/get_reservations_usecase.dart';
import '../../domain/usecases/get_upcoming_reservations_usecase.dart';
import '../controllers/reservations_controller.dart';

/// Reservations Binding — inyecta `ReservationsController` con sus use cases.
class ReservationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReservationsController>(
      () => ReservationsController(
        getReservationsUseCase: sl<GetReservationsUseCase>(),
        getUpcomingReservationsUseCase: sl<GetUpcomingReservationsUseCase>(),
        deleteReservationUseCase: sl<DeleteReservationUseCase>(),
      ),
    );
  }
}
