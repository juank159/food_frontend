// lib/features/tables/domain/entities/floor_plan.dart

import 'package:flutter/material.dart';
import 'floor_plan_layer.dart';
import 'floor_plan_element.dart';

/// Plano completo de un piso/nivel
class FloorPlan {
  final String id;
  final String name;
  final int floorLevel; // 0 = planta baja, 1 = primer piso, -1 = sótano
  final List<FloorPlanLayer> layers;
  final double canvasWidth;
  final double canvasHeight;
  final double gridSize;
  final bool showGrid;
  final String? backgroundImageUrl;
  final Map<String, dynamic>? metadata;

  const FloorPlan({
    required this.id,
    required this.name,
    this.floorLevel = 0,
    required this.layers,
    this.canvasWidth = 1920,
    this.canvasHeight = 1080,
    this.gridSize = 20.0,
    this.showGrid = true,
    this.backgroundImageUrl,
    this.metadata,
  });

  FloorPlan copyWith({
    String? id,
    String? name,
    int? floorLevel,
    List<FloorPlanLayer>? layers,
    double? canvasWidth,
    double? canvasHeight,
    double? gridSize,
    bool? showGrid,
    String? backgroundImageUrl,
    Map<String, dynamic>? metadata,
  }) {
    return FloorPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      floorLevel: floorLevel ?? this.floorLevel,
      layers: layers ?? this.layers,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      gridSize: gridSize ?? this.gridSize,
      showGrid: showGrid ?? this.showGrid,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Obtener capa por ID
  FloorPlanLayer? getLayer(String layerId) {
    try {
      return layers.firstWhere((l) => l.id == layerId);
    } catch (_) {
      return null;
    }
  }

  /// Actualizar capa
  FloorPlan updateLayer(FloorPlanLayer layer) {
    return copyWith(
      layers: layers.map((l) => l.id == layer.id ? layer : l).toList(),
    );
  }

  /// Agregar capa
  FloorPlan addLayer(FloorPlanLayer layer) {
    return copyWith(layers: [...layers, layer]);
  }

  /// Remover capa
  FloorPlan removeLayer(String layerId) {
    return copyWith(
      layers: layers.where((l) => l.id != layerId).toList(),
    );
  }

  /// Obtener todas las capas ordenadas por z-index
  List<FloorPlanLayer> getLayersByZIndex() {
    final sortedLayers = List<FloorPlanLayer>.from(layers);
    sortedLayers.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sortedLayers;
  }

  /// Obtener todos los elementos de todas las capas visibles
  List<FloorPlanElement> getAllVisibleElements() {
    final List<FloorPlanElement> elements = [];
    for (final layer in getLayersByZIndex()) {
      if (layer.isVisible) {
        elements.addAll(layer.elements.where((e) => e.isVisible));
      }
    }
    return elements;
  }

  /// Encontrar elemento en cualquier capa por posición
  FloorPlanElement? findElementAtPosition(Offset position) {
    // Buscar de arriba hacia abajo (z-index mayor primero)
    final reversedLayers = getLayersByZIndex().reversed;

    for (final layer in reversedLayers) {
      if (!layer.isVisible) continue;

      // Buscar elementos de atrás hacia adelante en la capa
      for (final element in layer.elements.reversed) {
        if (element.isVisible && element.containsPoint(position)) {
          return element;
        }
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'floorLevel': floorLevel,
      'layers': layers.map((l) => l.toJson()).toList(),
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'gridSize': gridSize,
      'showGrid': showGrid,
      'backgroundImageUrl': backgroundImageUrl,
      'metadata': metadata,
    };
  }

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      floorLevel: json['floorLevel'] as int? ?? 0,
      layers: (json['layers'] as List<dynamic>?)
              ?.map((l) => FloorPlanLayer.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 1920,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 1080,
      gridSize: (json['gridSize'] as num?)?.toDouble() ?? 20.0,
      showGrid: json['showGrid'] as bool? ?? true,
      backgroundImageUrl: json['backgroundImageUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Crear un plano vacío con capas estándar
  factory FloorPlan.empty({
    required String id,
    required String name,
    int floorLevel = 0,
  }) {
    return FloorPlan(
      id: id,
      name: name,
      floorLevel: floorLevel,
      layers: StandardLayers.defaults(),
    );
  }
}
