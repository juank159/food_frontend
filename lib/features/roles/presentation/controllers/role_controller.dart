import 'package:get/get.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/role.dart';
import '../../domain/usecases/role_usecases.dart';

class RoleController extends GetxController {
  final RoleUseCases useCases;
  RoleController({required this.useCases});

  final RxList<Role> roles = <Role>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isMutating = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.findAll();
    result.fold(
      (f) => errorMessage.value = f.message,
      (list) {
        // Copiamos a una lista mutable porque `sort()` falla si el repo
        // retornó una lista inmutable (const, UnmodifiableList, etc.).
        // Orden: sistemas primero, después por sort_order, después alfabético.
        final sorted = List<Role>.from(list)
          ..sort((a, b) {
            if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
            final s = a.sortOrder.compareTo(b.sortOrder);
            if (s != 0) return s;
            return a.name.compareTo(b.name);
          });
        roles.assignAll(sorted);
      },
    );
    isLoading.value = false;
  }

  Future<Role?> create({
    required String name,
    required String code,
    required Map<String, List<String>> permissions,
    String? description,
  }) async {
    if (isMutating.value) return null;
    isMutating.value = true;
    final result = await useCases.create(
      name: name,
      code: code,
      permissions: permissions,
      description: description,
    );
    isMutating.value = false;
    return result.fold(
      (f) {
        AppSnackbar.show('No se pudo crear', f.message);
        return null;
      },
      (r) {
        roles.add(r);
        roles.sort((a, b) {
          if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
          return a.name.compareTo(b.name);
        });
        AppSnackbar.show('Rol creado', r.name);
        return r;
      },
    );
  }

  Future<Role?> updateRole(
    String id, {
    String? name,
    String? description,
    Map<String, List<String>>? permissions,
    bool? isActive,
  }) async {
    if (isMutating.value) return null;
    isMutating.value = true;
    final result = await useCases.update(
      id,
      name: name,
      description: description,
      permissions: permissions,
      isActive: isActive,
    );
    isMutating.value = false;
    return result.fold(
      (f) {
        AppSnackbar.show('No se pudo actualizar', f.message);
        return null;
      },
      (r) {
        final i = roles.indexWhere((x) => x.id == id);
        if (i >= 0) roles[i] = r;
        roles.refresh();
        AppSnackbar.show('Rol actualizado', r.name);
        return r;
      },
    );
  }

  Future<bool> remove(Role role) async {
    if (isMutating.value) return false;
    if (role.isSystem) {
      AppSnackbar.show(
        'Rol del sistema',
        'Los roles base (admin, manager, etc.) no se pueden eliminar.',
      );
      return false;
    }
    isMutating.value = true;
    final result = await useCases.remove(role.id);
    isMutating.value = false;
    return result.fold(
      (f) {
        AppSnackbar.show('No se pudo eliminar', f.message);
        return false;
      },
      (_) {
        roles.removeWhere((x) => x.id == role.id);
        AppSnackbar.show('Rol eliminado', role.name);
        return true;
      },
    );
  }
}
