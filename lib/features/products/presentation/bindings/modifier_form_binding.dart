import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_modifier_usecase.dart';
import '../../domain/usecases/update_modifier_usecase.dart';
import '../controllers/modifier_form_controller.dart';

/// Modifier Form Binding
/// Inyecta las dependencias necesarias para ModifierFormController
class ModifierFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ModifierFormController>(
      () => ModifierFormController(
        createModifierUseCase: sl<CreateModifierUseCase>(),
        updateModifierUseCase: sl<UpdateModifierUseCase>(),
      ),
    );
  }
}
