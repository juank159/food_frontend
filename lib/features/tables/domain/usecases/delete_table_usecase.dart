import '../repositories/table_repository.dart';

/// Use case para eliminar una mesa
/// Sigue el patrón de Clean Architecture para mantener la lógica de negocio separada
class DeleteTableUseCase {
  final TableRepository repository;

  DeleteTableUseCase(this.repository);

  /// Ejecuta la eliminación de una mesa por ID
  ///
  /// Parámetros:
  /// - [tableId]: ID de la mesa a eliminar
  ///
  /// Retorna:
  /// - true si se eliminó exitosamente
  /// - false si no se encontró o hubo un error
  Future<bool> execute(String tableId) async {
    try {
      await repository.deleteTable(tableId);
      return true;
    } catch (e) {
      // Log del error (el repositorio ya lo maneja)
      return false;
    }
  }

  /// Ejecuta la eliminación de múltiples mesas
  /// Útil para operaciones en lote
  Future<Map<String, bool>> executeMultiple(List<String> tableIds) async {
    final results = <String, bool>{};

    for (final tableId in tableIds) {
      results[tableId] = await execute(tableId);
    }

    return results;
  }

  /// Valida si una mesa puede ser eliminada
  /// Verifica reglas de negocio antes de eliminar
  Future<bool> canDelete(String tableId) async {
    try {
      await repository.getTableById(tableId);

      // Regla de negocio: No se puede eliminar una mesa ocupada
      // (esto depende de tus reglas de negocio específicas)
      // Si la mesa existe y se obtiene sin error, se puede eliminar
      // Aquí se pueden agregar validaciones adicionales en el futuro

      return true;
    } catch (e) {
      return false;
    }
  }
}
