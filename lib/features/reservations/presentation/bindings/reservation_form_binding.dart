import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/usecases/create_reservation_usecase.dart';
import '../../domain/usecases/update_reservation_usecase.dart';
import '../controllers/reservation_form_controller.dart';

/// Reservation Form Binding — construye el controller del form. Si la ruta
/// recibió una `Reservation` como argumento, la inyecta como
/// `reservationToEdit` para arrancar en modo edición.
class ReservationFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReservationFormController>(() {
      final controller = ReservationFormController(
        createReservationUseCase: sl<CreateReservationUseCase>(),
        updateReservationUseCase: sl<UpdateReservationUseCase>(),
      );
      final args = Get.arguments;
      if (args is Reservation) {
        controller.reservationToEdit = args;
      }
      return controller;
    });
  }
}
