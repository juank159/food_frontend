// lib/features/tables/domain/commands/floor_plan_command.dart

import '../entities/floor_plan.dart';

/// Patrón Command para Undo/Redo profesional
abstract class FloorPlanCommand {
  final String description;

  const FloorPlanCommand(this.description);

  /// Ejecutar el comando
  FloorPlan execute(FloorPlan currentState);

  /// Deshacer el comando
  FloorPlan undo(FloorPlan currentState);
}

/// Historial de comandos para Undo/Redo
class CommandHistory {
  final List<FloorPlanCommand> _undoStack = [];
  final List<FloorPlanCommand> _redoStack = [];
  final int maxHistorySize;

  CommandHistory({this.maxHistorySize = 100});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String? get undoDescription =>
      canUndo ? _undoStack.last.description : null;
  String? get redoDescription =>
      canRedo ? _redoStack.last.description : null;

  /// Ejecutar y guardar comando
  FloorPlan executeCommand(FloorPlan currentState, FloorPlanCommand command) {
    _undoStack.add(command);
    _redoStack.clear();

    // Limitar tamaño del historial
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }

    return command.execute(currentState);
  }

  /// Deshacer último comando
  FloorPlan undo(FloorPlan currentState) {
    if (!canUndo) return currentState;

    final command = _undoStack.removeLast();
    _redoStack.add(command);

    return command.undo(currentState);
  }

  /// Rehacer último comando deshecho
  FloorPlan redo(FloorPlan currentState) {
    if (!canRedo) return currentState;

    final command = _redoStack.removeLast();
    _undoStack.add(command);

    return command.execute(currentState);
  }

  /// Limpiar historial
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
