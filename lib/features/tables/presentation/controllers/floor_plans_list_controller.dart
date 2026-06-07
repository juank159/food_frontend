// lib/features/tables/presentation/controllers/floor_plans_list_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/routes/app_routes.dart';
import '../../domain/entities/floor_plan.dart';
import '../../domain/repositories/floor_plan_repository.dart';
import '../../../../core/utils/app_snackbar.dart';

class FloorPlansListController extends GetxController {
  final FloorPlanRepository repository;

  FloorPlansListController({required this.repository});

  // Lista de floor plans
  final RxList<FloorPlan> floorPlans = <FloorPlan>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadFloorPlans();
  }

  /// Cargar todos los floor plans del usuario
  Future<void> loadFloorPlans() async {
    try {
      isLoading.value = true;
      final plans = await repository.getFloorPlans();
      floorPlans.value = plans;
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Error al cargar planos: $e',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Ir directamente al servicio de un floor plan. Usa `AppRoutes` para
  /// construir la URL — `NavigationService` no acepta arguments adicionales,
  /// así que recurrimos a `Get.toNamed` con la constante de ruta.
  Future<void> goToService(FloorPlan floorPlan) async {
    Get.toNamed(
      AppRoutes.buildTableService(floorPlan.id),
      arguments: {'floorPlanName': floorPlan.name},
    );
  }

  /// Ir al editor para editar un floor plan existente.
  Future<void> editFloorPlan(FloorPlan floorPlan) async {
    Get.toNamed(
      AppRoutes.floorPlanEditor,
      arguments: {'floorPlanId': floorPlan.id},
    );
  }

  /// Crear un nuevo floor plan
  Future<void> createNewFloorPlan() async {
    try {
      isCreating.value = true;

      // Mostrar diálogo para nombre
      final name = await _showNameDialog();
      if (name == null || name.isEmpty) return;

      // Crear floor plan nuevo con el helper FloorPlan.empty
      final newFloorPlanTemplate = FloorPlan.empty(id: '', name: name);
      final newPlan = await repository.createFloorPlan(newFloorPlanTemplate);

      // Ir al editor con el nuevo plano.
      Get.toNamed(
        AppRoutes.floorPlanEditor,
        arguments: {'floorPlanId': newPlan.id},
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Error al crear plano: $e',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isCreating.value = false;
    }
  }

  /// Eliminar un floor plan
  Future<void> deleteFloorPlan(FloorPlan floorPlan) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Eliminar plano?'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${floorPlan.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repository.deleteFloorPlan(floorPlan.id);
      floorPlans.remove(floorPlan);
      AppSnackbar.show(
        'Éxito',
        'Plano eliminado exitosamente',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Error al eliminar plano: $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  /// Mostrar diálogo para ingresar el nombre
  Future<String?> _showNameDialog() async {
    String? name;
    return Get.dialog<String>(
      AlertDialog(
        title: const Text('Nuevo Plano'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre del plano (ej: Planta Baja)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => name = value,
          onSubmitted: (value) {
            name = value;
            Get.back(result: name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: name),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
