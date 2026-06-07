// lib/features/tables/domain/entities/floor_plan_layer.dart

import 'floor_plan_element.dart';
import '../../core/utils/logger.dart';

/// Capa del plano (como en Photoshop/Figma)
class FloorPlanLayer {
  final String id;
  final String name;
  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final int zIndex; // Orden de renderizado (mayor = encima)
  final List<FloorPlanElement> elements;

  const FloorPlanLayer({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    this.zIndex = 0,
    this.elements = const [],
  });

  FloorPlanLayer copyWith({
    String? id,
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    int? zIndex,
    List<FloorPlanElement>? elements,
  }) {
    return FloorPlanLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      elements: elements ?? this.elements,
    );
  }

  /// Agregar elemento a la capa
  FloorPlanLayer addElement(FloorPlanElement element) {
    return copyWith(elements: [...elements, element]);
  }

  /// Remover elemento de la capa
  FloorPlanLayer removeElement(String elementId) {
    return copyWith(
      elements: elements.where((e) => e.id != elementId).toList(),
    );
  }

  /// Actualizar elemento en la capa
  FloorPlanLayer updateElement(FloorPlanElement element) {
    return copyWith(
      elements: elements.map((e) => e.id == element.id ? element : e).toList(),
    );
  }

  /// Obtener elemento por ID
  FloorPlanElement? getElement(String elementId) {
    try {
      return elements.firstWhere((e) => e.id == elementId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isVisible': isVisible,
      'isLocked': isLocked,
      'opacity': opacity,
      'zIndex': zIndex,
      'elements': elements.map((e) => e.toJson()).toList(),
    };
  }

  factory FloorPlanLayer.fromJson(Map<String, dynamic> json) {
    return FloorPlanLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      zIndex: json['zIndex'] as int? ?? 0,
      elements: (json['elements'] as List<dynamic>?)
              ?.map((e) => _elementFromJson(e as Map<String, dynamic>))
              .whereType<FloorPlanElement>()
              .toList() ??
          [],
    );
  }

  static FloorPlanElement? _elementFromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'polygon':
        return PolygonElement.fromJson(json);
      case 'zone':
        return RectangleElement.fromJson(json);
      case 'line':
        return LineElement.fromJson(json);
      case 'text':
        return TextElement.fromJson(json);
      // Elementos con íconos (mesas, puertas, baños, cocinas, etc.)
      case 'table':
      case 'door':
      case 'window':
      case 'bathroom':
      case 'kitchen':
      case 'bar':
      case 'plant':
      case 'furniture':
      case 'stairs':
      case 'image':
        return IconElement.fromJson(json);
      default:
        // Log profesional para debug en desarrollo
        tablesLogger.w('Unknown element type "$type" in floor plan', error: 'Skipping element');
        return null;
    }
  }
}

/// Capas predefinidas estándar
class StandardLayers {
  static FloorPlanLayer background() => const FloorPlanLayer(
        id: 'layer_background',
        name: 'Fondo',
        zIndex: 0,
      );

  static FloorPlanLayer walls() => const FloorPlanLayer(
        id: 'layer_walls',
        name: 'Paredes',
        zIndex: 1,
      );

  static FloorPlanLayer services() => const FloorPlanLayer(
        id: 'layer_services',
        name: 'Servicios (Baños, Cocina)',
        zIndex: 2,
      );

  static FloorPlanLayer furniture() => const FloorPlanLayer(
        id: 'layer_furniture',
        name: 'Mobiliario',
        zIndex: 3,
      );

  static FloorPlanLayer tables() => const FloorPlanLayer(
        id: 'layer_tables',
        name: 'Mesas',
        zIndex: 4,
      );

  static FloorPlanLayer decoration() => const FloorPlanLayer(
        id: 'layer_decoration',
        name: 'Decoración',
        zIndex: 5,
      );

  static FloorPlanLayer labels() => const FloorPlanLayer(
        id: 'layer_labels',
        name: 'Etiquetas',
        zIndex: 6,
      );

  static List<FloorPlanLayer> defaults() => [
        background(),
        walls(),
        services(),
        furniture(),
        tables(),
        decoration(),
        labels(),
      ];
}
