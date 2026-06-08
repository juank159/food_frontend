import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/menu_schedules_remote_datasource.dart';
import '../../data/models/menu_schedule_grid_item.dart';

class MenuSchedulesController extends GetxController {
  MenuSchedulesController({MenuSchedulesRemoteDataSource? dataSource})
      : _ds = dataSource ?? sl<MenuSchedulesRemoteDataSource>();

  final MenuSchedulesRemoteDataSource _ds;

  /// Fecha actualmente seleccionada (YYYY-MM-DD). Default = hoy.
  final Rx<String> selectedDate = Rx<String>(_todayString());

  final RxList<MenuScheduleGridItem> items =
      <MenuScheduleGridItem>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxSet<String> processingProductIds = <String>{}.obs;

  /// Búsqueda libre por nombre (no toca el servidor — filtra client-side).
  final RxString search = ''.obs;

  /// Filtra solo programados / no programados / todos.
  final RxString statusFilter = 'all'.obs; // all | programmed | not

  List<MenuScheduleGridItem> get visible {
    final q = search.value.trim().toLowerCase();
    final filter = statusFilter.value;

    return items.where((i) {
      if (q.isNotEmpty &&
          !i.product.name.toLowerCase().contains(q) &&
          !(i.product.categoryName?.toLowerCase().contains(q) ?? false)) {
        return false;
      }
      if (filter == 'programmed' && !i.isProgrammed) return false;
      if (filter == 'not' && i.isProgrammed) return false;
      return true;
    }).toList();
  }

  /// Conteo rápido para mostrar en el header ("12 de 47 programados").
  int get programmedCount =>
      items.where((i) => i.isProgrammed).length;
  int get totalCount => items.length;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    error.value = null;
    try {
      final result = await _ds.grid(date: selectedDate.value);
      items.assignAll(result);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  /// Cambia la fecha y refetch.
  Future<void> setDate(String date) async {
    if (selectedDate.value == date) return;
    selectedDate.value = date;
    await fetch();
  }

  /// Toggle on/off de un producto para la fecha actual.
  /// Optimistic: actualizamos el item local antes de la response.
  /// Si falla, recargamos para volver al estado real del servidor.
  Future<void> toggle(MenuScheduleGridItem item) async {
    if (processingProductIds.contains(item.product.id)) return;
    processingProductIds.add(item.product.id);

    // Estado previo para rollback.
    final wasProgrammed = item.isProgrammed;
    final idx = items.indexWhere((i) => i.product.id == item.product.id);
    if (idx < 0) {
      processingProductIds.remove(item.product.id);
      return;
    }

    // Optimistic: si estaba off, asumimos prendido (schedule mock con
    // is_active=true sin id real). Si estaba on, asumimos apagado.
    items[idx] = MenuScheduleGridItem(
      product: item.product,
      schedule: wasProgrammed
          ? null
          : ScheduleLite(
              id: '__optimistic__',
              isActive: true,
              availableFrom: null,
              availableTo: null,
              dailyQuantityLimit: null,
              specialPrice: null,
              badgeLabel: null,
            ),
    );

    try {
      final result = await _ds.toggle(
        productId: item.product.id,
        date: selectedDate.value,
      );
      // Reemplazar con la respuesta real del servidor.
      items[idx] = MenuScheduleGridItem(
        product: item.product,
        schedule: result.schedule,
      );
    } catch (e) {
      // Rollback: refetch (más simple que reconstruir el item).
      await fetch();
      AppSnackbar.show('No se pudo actualizar', e.toString());
    } finally {
      processingProductIds.remove(item.product.id);
    }
  }

  /// Programa TODOS los productos para la fecha actual.
  /// [replace] = true → borra existentes y crea desde cero.
  Future<void> programAll({bool replace = false}) async {
    loading.value = true;
    try {
      final result = await _ds.programAllForDay(
        date: selectedDate.value,
        replace: replace,
      );
      AppSnackbar.show(
        'Menú programado',
        '${result.created} nuevos, ${result.skipped} ya estaban'
            '${result.deleted > 0 ? ', ${result.deleted} reemplazados' : ''}',
      );
      await fetch();
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
    } finally {
      loading.value = false;
    }
  }

  /// Desprograma todos los productos del día (programmedCount = 0).
  /// Implementado client-side haciendo bulk toggle a is_active=false
  /// y luego refetch (más simple que un endpoint dedicado).
  Future<void> clearAll() async {
    final ids = items
        .where((i) => i.schedule != null)
        .map((i) => i.schedule!.id)
        .where((id) => id != '__optimistic__')
        .toList();

    if (ids.isEmpty) {
      AppSnackbar.show('Nada para limpiar', 'No hay productos programados.');
      return;
    }
    try {
      final n = await _ds.bulkToggle(ids: ids, isActive: false);
      AppSnackbar.show('Menú limpiado', '$n productos desactivados.');
      await fetch();
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
    }
  }

  // ----------------------------------------------------------------

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
