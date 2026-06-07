import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/delete_modifier_usecase.dart';
import '../../domain/usecases/get_modifiers_usecase.dart';
import '../controllers/modifiers_controller.dart';

/// Modifiers Binding
/// Inyecta las dependencias necesarias para ModifiersController
class ModifiersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ModifiersController>(
      () => ModifiersController(
        getModifiersUseCase: sl<GetModifiersUseCase>(),
        deleteModifierUseCase: sl<DeleteModifierUseCase>(),
      ),
    );
  }
}
