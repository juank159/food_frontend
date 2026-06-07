library;

/// Modifier Enums
/// Enumeraciones para tipos de modificadores y selección
/// Debe coincidir con los enums del backend

/// Tipo de modificador
enum ModifierType {
  /// Agregar ingrediente o extra
  addition('addition'),

  /// Remover ingrediente
  removal('removal'),

  /// Sustituir ingrediente
  substitution('substitution');

  final String value;
  const ModifierType(this.value);

  /// Crear desde string
  static ModifierType fromString(String value) {
    return ModifierType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ModifierType.addition,
    );
  }

  /// Obtener etiqueta en español
  String get label {
    switch (this) {
      case ModifierType.addition:
        return 'Agregar';
      case ModifierType.removal:
        return 'Remover';
      case ModifierType.substitution:
        return 'Sustituir';
    }
  }
}

/// Tipo de selección para grupos de modificadores
enum SelectionType {
  /// Solo se puede seleccionar un modificador del grupo
  single('single'),

  /// Se pueden seleccionar múltiples modificadores del grupo
  multiple('multiple');

  final String value;
  const SelectionType(this.value);

  /// Crear desde string
  static SelectionType fromString(String value) {
    return SelectionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SelectionType.multiple,
    );
  }

  /// Obtener etiqueta en español
  String get label {
    switch (this) {
      case SelectionType.single:
        return 'Selección única';
      case SelectionType.multiple:
        return 'Selección múltiple';
    }
  }
}
