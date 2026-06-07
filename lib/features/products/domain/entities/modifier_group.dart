import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import 'modifier.dart';

/// Modifier Group Entity
/// Agrupa modificadores relacionados para un producto
/// Ejemplos: "Proteína", "Extras", "Remover Ingredientes"
class ModifierGroup extends Equatable {
  /// ID único del grupo
  final String id;

  /// ID del producto al que pertenece
  final String productId;

  /// Nombre del grupo
  final String name;

  /// Descripción opcional del grupo
  final String? description;

  /// Tipo de selección (single o multiple)
  final SelectionType selectionType;

  /// Número mínimo de selecciones requeridas
  final int minSelections;

  /// Número máximo de selecciones permitidas (null = ilimitado)
  final int? maxSelections;

  /// Indica si es obligatorio seleccionar al menos una opción
  final bool isRequired;

  /// Orden de visualización
  final int sortOrder;

  /// Indica si el grupo está activo
  final bool isActive;

  /// Lista de modificadores en este grupo
  final List<Modifier> modifiers;

  const ModifierGroup({
    required this.id,
    required this.productId,
    required this.name,
    this.description,
    required this.selectionType,
    this.minSelections = 0,
    this.maxSelections,
    this.isRequired = false,
    this.sortOrder = 0,
    this.isActive = true,
    this.modifiers = const [],
  });

  /// Verifica si el grupo permite múltiples selecciones
  bool get allowsMultiple => selectionType == SelectionType.multiple;

  /// Verifica si el grupo permite solo una selección
  bool get allowsSingleOnly => selectionType == SelectionType.single;

  /// Obtiene el número de modificadores disponibles
  int get availableModifiersCount =>
      modifiers.where((m) => m.isAvailable).length;

  /// Verifica si tiene modificadores disponibles
  bool get hasAvailableModifiers => availableModifiersCount > 0;

  /// Obtiene texto descriptivo de las selecciones requeridas
  String get selectionHint {
    if (isRequired) {
      if (minSelections == maxSelections && minSelections == 1) {
        return 'Requerido - Selecciona 1';
      } else if (minSelections == maxSelections) {
        return 'Requerido - Selecciona $minSelections';
      } else if (maxSelections != null) {
        return 'Requerido - Selecciona entre $minSelections y $maxSelections';
      } else {
        return 'Requerido - Selecciona al menos $minSelections';
      }
    } else {
      if (maxSelections != null && maxSelections == 1) {
        return 'Opcional - Máximo 1';
      } else if (maxSelections != null) {
        return 'Opcional - Máximo $maxSelections';
      } else {
        return 'Opcional';
      }
    }
  }

  /// Valida si un número de selecciones es válido
  bool isValidSelectionCount(int count) {
    if (isRequired && count < minSelections) {
      return false;
    }
    if (maxSelections != null && count > maxSelections!) {
      return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        name,
        description,
        selectionType,
        minSelections,
        maxSelections,
        isRequired,
        sortOrder,
        isActive,
        modifiers,
      ];

  @override
  String toString() {
    return 'ModifierGroup(id: $id, name: $name, modifiers: ${modifiers.length})';
  }
}
