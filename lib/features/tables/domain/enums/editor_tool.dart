// lib/features/tables/domain/enums/editor_tool.dart

/// Herramientas del editor de planos
enum EditorTool {
  /// Seleccionar y mover elementos
  select,

  /// Pan (mover canvas)
  pan,

  /// Polígono de forma libre
  polygon,

  /// Línea/Pared
  line,

  /// Rectángulo
  rectangle,

  /// Texto
  text,

  /// Puerta
  door,

  /// Baño
  bathroom,

  /// Cocina
  kitchen,

  /// Bar
  bar,

  /// Planta/Decoración
  plant,

  /// Escaleras
  stairs,

  /// Mesa
  table,
}

extension EditorToolExtension on EditorTool {
  String get displayName {
    switch (this) {
      case EditorTool.select:
        return 'Seleccionar';
      case EditorTool.pan:
        return 'Mover Vista';
      case EditorTool.polygon:
        return 'Polígono';
      case EditorTool.line:
        return 'Línea/Pared';
      case EditorTool.rectangle:
        return 'Rectángulo';
      case EditorTool.text:
        return 'Texto';
      case EditorTool.door:
        return 'Puerta';
      case EditorTool.bathroom:
        return 'Baño';
      case EditorTool.kitchen:
        return 'Cocina';
      case EditorTool.bar:
        return 'Bar';
      case EditorTool.plant:
        return 'Planta';
      case EditorTool.stairs:
        return 'Escaleras';
      case EditorTool.table:
        return 'Mesa';
    }
  }

  String get description {
    switch (this) {
      case EditorTool.select:
        return 'Seleccionar, mover y editar elementos';
      case EditorTool.pan:
        return 'Mover la vista del canvas';
      case EditorTool.polygon:
        return 'Dibujar polígono de forma libre';
      case EditorTool.line:
        return 'Dibujar línea o pared';
      case EditorTool.rectangle:
        return 'Dibujar rectángulo';
      case EditorTool.text:
        return 'Agregar texto';
      case EditorTool.door:
        return 'Agregar puerta';
      case EditorTool.bathroom:
        return 'Agregar baño';
      case EditorTool.kitchen:
        return 'Agregar cocina';
      case EditorTool.bar:
        return 'Agregar bar';
      case EditorTool.plant:
        return 'Agregar planta decorativa';
      case EditorTool.stairs:
        return 'Agregar escaleras';
      case EditorTool.table:
        return 'Agregar mesa';
    }
  }

  String get shortcut {
    switch (this) {
      case EditorTool.select:
        return 'V';
      case EditorTool.pan:
        return 'H';
      case EditorTool.polygon:
        return 'P';
      case EditorTool.line:
        return 'L';
      case EditorTool.rectangle:
        return 'R';
      case EditorTool.text:
        return 'T';
      default:
        return '';
    }
  }
}
