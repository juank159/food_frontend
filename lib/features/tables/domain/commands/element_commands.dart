// lib/features/tables/domain/commands/element_commands.dart

import 'package:flutter/material.dart';
import 'floor_plan_command.dart';
import '../entities/floor_plan.dart';
import '../entities/floor_plan_element.dart';

/// Comando para agregar elemento
class AddElementCommand extends FloorPlanCommand {
  final String layerId;
  final FloorPlanElement element;

  AddElementCommand(this.layerId, this.element)
      : super('Agregar ${element.type.name}');

  @override
  FloorPlan execute(FloorPlan currentState) {
    final layer = currentState.getLayer(layerId);
    if (layer == null) return currentState;

    final updatedLayer = layer.addElement(element);
    return currentState.updateLayer(updatedLayer);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    final layer = currentState.getLayer(layerId);
    if (layer == null) return currentState;

    final updatedLayer = layer.removeElement(element.id);
    return currentState.updateLayer(updatedLayer);
  }
}

/// Comando para eliminar elemento
class DeleteElementCommand extends FloorPlanCommand {
  final String layerId;
  final FloorPlanElement element;

  DeleteElementCommand(this.layerId, this.element)
      : super('Eliminar ${element.type.name}');

  @override
  FloorPlan execute(FloorPlan currentState) {
    final layer = currentState.getLayer(layerId);
    if (layer == null) return currentState;

    final updatedLayer = layer.removeElement(element.id);
    return currentState.updateLayer(updatedLayer);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    final layer = currentState.getLayer(layerId);
    if (layer == null) return currentState;

    final updatedLayer = layer.addElement(element);
    return currentState.updateLayer(updatedLayer);
  }
}

/// Comando para mover elemento
class MoveElementCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final Offset oldPosition;
  final Offset newPosition;

  MoveElementCommand(
    this.layerId,
    this.elementId,
    this.oldPosition,
    this.newPosition,
  ) : super('Mover elemento');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updatePosition(currentState, newPosition);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updatePosition(currentState, oldPosition);
  }

  FloorPlan _updatePosition(FloorPlan state, Offset position) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null) return state;

    final updatedElement = element.copyWith(position: position);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para rotar elemento
class RotateElementCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final double oldRotation;
  final double newRotation;

  RotateElementCommand(
    this.layerId,
    this.elementId,
    this.oldRotation,
    this.newRotation,
  ) : super('Rotar elemento');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateRotation(currentState, newRotation);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateRotation(currentState, oldRotation);
  }

  FloorPlan _updateRotation(FloorPlan state, double rotation) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null) return state;

    final updatedElement = element.copyWith(rotation: rotation);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para redimensionar elemento
class ResizeElementCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final Map<String, dynamic> oldProperties;
  final Map<String, dynamic> newProperties;

  ResizeElementCommand(
    this.layerId,
    this.elementId,
    this.oldProperties,
    this.newProperties,
  ) : super('Redimensionar elemento');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateProperties(currentState, newProperties);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateProperties(currentState, oldProperties);
  }

  FloorPlan _updateProperties(FloorPlan state, Map<String, dynamic> properties) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null) return state;

    // Actualizar con las propiedades nuevas
    final updatedElement = _applyProperties(element, properties);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }

  FloorPlanElement _applyProperties(
    FloorPlanElement element,
    Map<String, dynamic> properties,
  ) {
    // Copiar elemento con las nuevas propiedades
    return element.copyWith(
      position: properties['position'] as Offset?,
      rotation: properties['rotation'] as double?,
    );
  }
}

/// Comando para actualizar propiedades de elemento
class UpdateElementPropertiesCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final Map<String, dynamic> oldProperties;
  final Map<String, dynamic> newProperties;

  UpdateElementPropertiesCommand(
    this.layerId,
    this.elementId,
    this.oldProperties,
    this.newProperties,
  ) : super('Actualizar propiedades');

  @override
  FloorPlan execute(FloorPlan currentState) {
    final layer = currentState.getLayer(layerId);
    if (layer == null) return currentState;

    final element = layer.getElement(elementId);
    if (element == null) return currentState;

    final updatedElement = _applyProperties(element, newProperties);
    final updatedLayer = layer.updateElement(updatedElement);
    return currentState.updateLayer(updatedLayer);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    final layer = currentState.getLayer(layerId);
    if (layer == null) return currentState;

    final element = layer.getElement(elementId);
    if (element == null) return currentState;

    final updatedElement = _applyProperties(element, oldProperties);
    final updatedLayer = layer.updateElement(updatedElement);
    return currentState.updateLayer(updatedLayer);
  }

  FloorPlanElement _applyProperties(
    FloorPlanElement element,
    Map<String, dynamic> properties,
  ) {
    return element.copyWith(
      isLocked: properties['isLocked'] as bool?,
      isVisible: properties['isVisible'] as bool?,
      metadata: properties['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Comando para redimensionar icono
class ResizeIconCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final double oldSize;
  final double newSize;

  ResizeIconCommand(
    this.layerId,
    this.elementId,
    this.oldSize,
    this.newSize,
  ) : super('Redimensionar icono');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateSize(currentState, newSize);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateSize(currentState, oldSize);
  }

  FloorPlan _updateSize(FloorPlan state, double size) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null || element is! IconElement) return state;

    final updatedElement = element.copyWith(size: size);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para redimensionar rectángulo
class ResizeRectangleCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final double oldWidth;
  final double oldHeight;
  final double newWidth;
  final double newHeight;

  ResizeRectangleCommand(
    this.layerId,
    this.elementId,
    this.oldWidth,
    this.oldHeight,
    this.newWidth,
    this.newHeight,
  ) : super('Redimensionar rectángulo');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateSize(currentState, newWidth, newHeight);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateSize(currentState, oldWidth, oldHeight);
  }

  FloorPlan _updateSize(FloorPlan state, double width, double height) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null || element is! RectangleElement) return state;

    final updatedElement = element.copyWith(width: width, height: height);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para redimensionar polígono
class ResizePolygonCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final List<Offset> oldPoints;
  final List<Offset> newPoints;

  ResizePolygonCommand(
    this.layerId,
    this.elementId,
    this.oldPoints,
    this.newPoints,
  ) : super('Redimensionar polígono');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updatePoints(currentState, newPoints);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updatePoints(currentState, oldPoints);
  }

  FloorPlan _updatePoints(FloorPlan state, List<Offset> points) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null || element is! PolygonElement) return state;

    final updatedElement = element.copyWith(points: List.from(points));
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para redimensionar línea
class ResizeLineCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final Offset oldStart;
  final Offset oldEnd;
  final Offset newStart;
  final Offset newEnd;

  ResizeLineCommand(
    this.layerId,
    this.elementId,
    this.oldStart,
    this.oldEnd,
    this.newStart,
    this.newEnd,
  ) : super('Redimensionar línea');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateEndpoints(currentState, newStart, newEnd);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateEndpoints(currentState, oldStart, oldEnd);
  }

  FloorPlan _updateEndpoints(FloorPlan state, Offset start, Offset end) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null || element is! LineElement) return state;

    final updatedElement = element.copyWith(start: start, end: end);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para redimensionar texto (cambiar tamaño de fuente)
class ResizeTextCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final double oldFontSize;
  final double newFontSize;

  ResizeTextCommand(
    this.layerId,
    this.elementId,
    this.oldFontSize,
    this.newFontSize,
  ) : super('Redimensionar texto');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateFontSize(currentState, newFontSize);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateFontSize(currentState, oldFontSize);
  }

  FloorPlan _updateFontSize(FloorPlan state, double fontSize) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null || element is! TextElement) return state;

    final updatedElement = element.copyWith(fontSize: fontSize);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para cambiar el zIndex de un elemento
class ChangeZIndexCommand extends FloorPlanCommand {
  final String layerId;
  final String elementId;
  final int oldZIndex;
  final int newZIndex;

  ChangeZIndexCommand(
    this.layerId,
    this.elementId,
    this.oldZIndex,
    this.newZIndex,
  ) : super('Cambiar orden de elemento');

  @override
  FloorPlan execute(FloorPlan currentState) {
    return _updateZIndex(currentState, newZIndex);
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    return _updateZIndex(currentState, oldZIndex);
  }

  FloorPlan _updateZIndex(FloorPlan state, int zIndex) {
    final layer = state.getLayer(layerId);
    if (layer == null) return state;

    final element = layer.getElement(elementId);
    if (element == null) return state;

    final updatedElement = element.copyWith(zIndex: zIndex);
    final updatedLayer = layer.updateElement(updatedElement);
    return state.updateLayer(updatedLayer);
  }
}

/// Comando para actualizar múltiples elementos (operaciones complejas)
class BatchUpdateCommand extends FloorPlanCommand {
  final List<FloorPlanCommand> commands;

  BatchUpdateCommand(this.commands, String description) : super(description);

  @override
  FloorPlan execute(FloorPlan currentState) {
    FloorPlan state = currentState;
    for (final command in commands) {
      state = command.execute(state);
    }
    return state;
  }

  @override
  FloorPlan undo(FloorPlan currentState) {
    FloorPlan state = currentState;
    for (final command in commands.reversed) {
      state = command.undo(state);
    }
    return state;
  }
}
