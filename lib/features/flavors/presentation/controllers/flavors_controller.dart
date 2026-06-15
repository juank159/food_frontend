import 'package:get/get.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/datasources/flavor_remote_datasource.dart';
import '../../domain/entities/flavor.dart';

/// Maneja el CRUD de cremas/sabores de una categoría.
class FlavorsController extends GetxController {
  final FlavorRemoteDataSource dataSource;
  FlavorsController(this.dataSource);

  final Rx<String?> categoryId = Rx<String?>(null);
  final RxList<Flavor> flavors = <Flavor>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  Future<void> selectCategory(String id) async {
    if (categoryId.value == id) return;
    categoryId.value = id;
    await load();
  }

  Future<void> load() async {
    if (categoryId.value == null) return;
    isLoading.value = true;
    try {
      flavors.value =
          await dataSource.getFlavors(categoryId: categoryId.value);
    } catch (e) {
      _err('No se pudieron cargar las cremas');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> add(String name) async {
    final n = name.trim();
    if (n.isEmpty || categoryId.value == null) return;
    isSaving.value = true;
    try {
      final created = await dataSource.createFlavor({
        'name': n,
        'category_id': categoryId.value,
        'sort_order': flavors.length,
      });
      flavors.add(created);
    } catch (e) {
      _err('No se pudo agregar la crema');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> rename(Flavor flavor, String name) async {
    final n = name.trim();
    if (n.isEmpty || n == flavor.name) return;
    try {
      await dataSource.updateFlavor(flavor.id, {'name': n});
      await load();
    } catch (e) {
      _err('No se pudo renombrar');
    }
  }

  Future<void> toggleAvailable(Flavor flavor) async {
    try {
      await dataSource
          .updateFlavor(flavor.id, {'is_available': !flavor.isAvailable});
      await load();
    } catch (e) {
      _err('No se pudo actualizar la disponibilidad');
    }
  }

  Future<void> remove(Flavor flavor) async {
    try {
      await dataSource.deleteFlavor(flavor.id);
      flavors.removeWhere((f) => f.id == flavor.id);
    } catch (e) {
      _err('No se pudo eliminar');
    }
  }

  void _err(String msg) {
    AppSnackbar.show('Error', msg, snackPosition: SnackPosition.TOP);
  }
}
