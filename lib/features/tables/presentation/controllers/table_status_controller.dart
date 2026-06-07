import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/table_status.dart';
import '../../domain/entities/table_operations.dart';
import '../../data/repositories/table_status_repository.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../core/utils/logger.dart';
import '../../../../core/utils/app_snackbar.dart';

class TableStatusController extends GetxController {
  final TableStatusRepository repository;

  TableStatusController({required this.repository});

  // Estado observable
  final tableStatuses = <TableStatusEntity>[].obs;
  final selectedTableStatus = Rx<TableStatusEntity?>(null);
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // Filtros
  final filterStatus = Rx<TableStatus?>(null);
  final searchQuery = ''.obs;

  // Keys para SharedPreferences
  static const _keyFilterStatus = 'table_status_filter';
  static const _keySearchQuery = 'table_status_search';

  @override
  void onInit() {
    super.onInit();
    _restoreFilters();
  }

  /// Restaura los filtros guardados de SharedPreferences
  Future<void> _restoreFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Restaurar filtro de estado
      final savedStatus = prefs.getString(_keyFilterStatus);
      if (savedStatus != null && savedStatus.isNotEmpty) {
        filterStatus.value = TableStatus.values.firstWhere(
          (status) => status.name == savedStatus,
          orElse: () => TableStatus.available,
        );
      }

      // Restaurar búsqueda
      final savedSearch = prefs.getString(_keySearchQuery);
      if (savedSearch != null) {
        searchQuery.value = savedSearch;
      }

      tablesLogger.d(
        'Filtros restaurados: status=${filterStatus.value}, search="${searchQuery.value}"',
      );
    } catch (e) {
      tablesLogger.w('Error restaurando filtros', error: e);
    }
  }

  /// Guarda los filtros en SharedPreferences
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar filtro de estado
      if (filterStatus.value != null) {
        await prefs.setString(_keyFilterStatus, filterStatus.value!.name);
      } else {
        await prefs.remove(_keyFilterStatus);
      }

      // Guardar búsqueda
      await prefs.setString(_keySearchQuery, searchQuery.value);

      tablesLogger.d('Filtros guardados exitosamente');
    } catch (e) {
      tablesLogger.w('Error guardando filtros', error: e);
    }
  }

  /// Obtener todos los estados de mesas de un floor plan
  Future<void> loadTableStatuses(String floorPlanId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final statuses = await repository.getTableStatusByFloorPlan(floorPlanId);
      tableStatuses.value = statuses;
    } catch (e) {
      errorMessage.value = 'Error cargando estados de mesas: $e';
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Obtener estado de una mesa específica
  Future<void> loadTableStatus(String tableElementId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final status = await repository.getTableStatus(tableElementId);
      selectedTableStatus.value = status;

      // Actualizar en la lista si existe
      final index = tableStatuses.indexWhere(
        (ts) => ts.tableElementId == tableElementId,
      );
      if (index != -1) {
        tableStatuses[index] = status;
        tableStatuses.refresh();
      }
    } catch (e) {
      errorMessage.value = 'Error cargando estado de mesa: $e';
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Ocupar una mesa
  Future<bool> occupyTable({
    required String tableElementId,
    required int partySize,
    String? serverId,
    String? notes,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final dto = OccupyTableDto(
        partySize: partySize,
        serverId: serverId,
        notes: notes,
      );

      final updatedStatus = await repository.occupyTable(tableElementId, dto);

      // Actualizar en la lista
      final index = tableStatuses.indexWhere(
        (ts) => ts.tableElementId == tableElementId,
      );
      if (index != -1) {
        tableStatuses[index] = updatedStatus;
        tableStatuses.refresh();
      }

      selectedTableStatus.value = updatedStatus;

      AppSnackbar.show(
        'Éxito',
        'Mesa ocupada correctamente',
        snackPosition: SnackPosition.TOP,
      );

      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Reservar una mesa
  Future<bool> reserveTable({
    required String tableElementId,
    required int partySize,
    String? reservationId,
    DateTime? reservedFor,
    String? notes,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final dto = ReserveTableDto(
        partySize: partySize,
        reservationId: reservationId,
        reservedFor: reservedFor,
        notes: notes,
      );

      final updatedStatus = await repository.reserveTable(tableElementId, dto);

      // Actualizar en la lista
      final index = tableStatuses.indexWhere(
        (ts) => ts.tableElementId == tableElementId,
      );
      if (index != -1) {
        tableStatuses[index] = updatedStatus;
        tableStatuses.refresh();
      }

      selectedTableStatus.value = updatedStatus;

      AppSnackbar.show(
        'Éxito',
        'Mesa reservada correctamente',
        snackPosition: SnackPosition.TOP,
      );

      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Liberar una mesa (marcar como limpieza)
  Future<bool> releaseTable(String tableElementId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final updatedStatus = await repository.releaseTable(tableElementId);

      // Actualizar en la lista
      final index = tableStatuses.indexWhere(
        (ts) => ts.tableElementId == tableElementId,
      );
      if (index != -1) {
        tableStatuses[index] = updatedStatus;
        tableStatuses.refresh();
      }

      selectedTableStatus.value = updatedStatus;

      AppSnackbar.show(
        'Éxito',
        'Mesa liberada, marcada para limpieza',
        snackPosition: SnackPosition.TOP,
      );

      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Marcar mesa como disponible (después de limpieza)
  Future<bool> markAsAvailable(String tableElementId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final updatedStatus = await repository.markTableAsAvailable(
        tableElementId,
      );

      // Actualizar en la lista
      final index = tableStatuses.indexWhere(
        (ts) => ts.tableElementId == tableElementId,
      );
      if (index != -1) {
        tableStatuses[index] = updatedStatus;
        tableStatuses.refresh();
      }

      selectedTableStatus.value = updatedStatus;

      AppSnackbar.show(
        'Éxito',
        'Mesa marcada como disponible',
        snackPosition: SnackPosition.TOP,
      );

      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sincronizar estados de mesas con el floor plan
  Future<void> syncWithFloorPlan(String floorPlanId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await repository.syncWithFloorPlan(floorPlanId);

      AppSnackbar.show(
        'Sincronización completa',
        'Creadas: ${result['created']}, Eliminadas: ${result['deleted']}',
        snackPosition: SnackPosition.TOP,
      );

      // Recargar estados después de sincronizar
      await loadTableStatuses(floorPlanId);
    } catch (e) {
      errorMessage.value = 'Error sincronizando: $e';
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Filtrar mesas por estado
  void setStatusFilter(TableStatus? status) {
    filterStatus.value = status;
    _saveFilters(); // Guardar automáticamente
  }

  /// Establecer búsqueda
  void setSearchQuery(String query) {
    searchQuery.value = query;
    _saveFilters(); // Guardar automáticamente
  }

  /// Limpiar todos los filtros
  void clearFilters() {
    filterStatus.value = null;
    searchQuery.value = '';
    _saveFilters();
  }

  /// Obtener mesas filtradas
  List<TableStatusEntity> get filteredTableStatuses {
    var filtered = tableStatuses.toList();

    // Filtrar por estado
    if (filterStatus.value != null) {
      filtered = filtered
          .where((ts) => ts.status == filterStatus.value)
          .toList();
    }

    // Filtrar por búsqueda
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((ts) {
        final label = ts.tableLabel?.toLowerCase() ?? '';
        return label.contains(query);
      }).toList();
    }

    return filtered;
  }

  /// Obtener estadísticas de mesas
  Map<String, int> get statistics {
    return {
      'total': tableStatuses.length,
      'available': tableStatuses
          .where((ts) => ts.status == TableStatus.available)
          .length,
      'occupied': tableStatuses
          .where((ts) => ts.status == TableStatus.occupied)
          .length,
      'reserved': tableStatuses
          .where((ts) => ts.status == TableStatus.reserved)
          .length,
      'cleaning': tableStatuses
          .where((ts) => ts.status == TableStatus.cleaning)
          .length,
      'maintenance': tableStatuses
          .where((ts) => ts.status == TableStatus.maintenance)
          .length,
    };
  }

  /// Limpiar selección
  void clearSelection() {
    selectedTableStatus.value = null;
  }

  @override
  void onClose() {
    tableStatuses.clear();
    selectedTableStatus.value = null;
    super.onClose();
  }
}
