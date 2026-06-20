// lib/features/tables/domain/entities/floor_plan_element.dart

import 'package:flutter/material.dart';

import '../enums/floor_plan_icons.dart';

/// Tipo de elemento en el plano
enum ElementType {
  // Estructurales
  wall,
  door,
  window,

  // Servicios
  bathroom,
  kitchen,
  bar,

  // Decoración
  plant,
  furniture,

  // Áreas
  polygon,
  zone,

  // Otros
  stairs,
  text,
  image,
  table, // Mesa de restaurant
}

/// Elemento base del plano
abstract class FloorPlanElement {
  final String id;
  final ElementType type;
  final String layerId;
  final Offset position;
  final double rotation; // En radianes
  final bool isLocked;
  final bool isVisible;
  final int zIndex; // Orden de apilamiento (mayor = más adelante)
  final Map<String, dynamic>? metadata;

  const FloorPlanElement({
    required this.id,
    required this.type,
    required this.layerId,
    required this.position,
    this.rotation = 0,
    this.isLocked = false,
    this.isVisible = true,
    this.zIndex = 0,
    this.metadata,
  });

  /// Obtener los bounds del elemento para detección de colisión
  Rect getBounds();

  /// Verificar si un punto está dentro del elemento
  bool containsPoint(Offset point);

  /// Crear copia con modificaciones
  FloorPlanElement copyWith({
    String? id,
    String? layerId,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    int? zIndex,
    Map<String, dynamic>? metadata,
  });

  /// Serializar a JSON
  Map<String, dynamic> toJson();
}

/// Polígono de forma libre
class PolygonElement extends FloorPlanElement {
  final List<Offset> points;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final String? name;

  const PolygonElement({
    required super.id,
    required super.layerId,
    required super.position,
    required this.points,
    this.fillColor = Colors.transparent,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.name,
    super.rotation,
    super.isLocked,
    super.isVisible,
    super.zIndex,
    super.metadata,
  }) : super(type: ElementType.polygon);

  @override
  Rect getBounds() {
    if (points.isEmpty) return Rect.zero;

    double minX = points[0].dx;
    double minY = points[0].dy;
    double maxX = points[0].dx;
    double maxY = points[0].dy;

    for (final point in points) {
      minX = minX < point.dx ? minX : point.dx;
      minY = minY < point.dy ? minY : point.dy;
      maxX = maxX > point.dx ? maxX : point.dx;
      maxY = maxY > point.dy ? maxY : point.dy;
    }

    return Rect.fromLTRB(
      position.dx + minX,
      position.dy + minY,
      position.dx + maxX,
      position.dy + maxY,
    );
  }

  @override
  bool containsPoint(Offset point) {
    // Algoritmo de ray casting para punto en polígono
    final relativePoint = point - position;
    int intersections = 0;

    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];

      if (p1.dy > relativePoint.dy != p2.dy > relativePoint.dy) {
        final slope = (relativePoint.dy - p1.dy) / (p2.dy - p1.dy);
        if (relativePoint.dx < p1.dx + slope * (p2.dx - p1.dx)) {
          intersections++;
        }
      }
    }

    return intersections.isOdd;
  }

  @override
  PolygonElement copyWith({
    String? id,
    String? layerId,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    int? zIndex,
    Map<String, dynamic>? metadata,
    List<Offset>? points,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    String? name,
  }) {
    return PolygonElement(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
      metadata: metadata ?? this.metadata,
      points: points ?? this.points,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'polygon',
      'layerId': layerId,
      'position': {'dx': position.dx, 'dy': position.dy},
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'zIndex': zIndex,
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'fillColor': fillColor.toARGB32(),
      'strokeColor': strokeColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'name': name,
      'metadata': metadata,
    };
  }

  factory PolygonElement.fromJson(Map<String, dynamic> json) {
    return PolygonElement(
      id: json['id'] as String,
      layerId: json['layerId'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      zIndex: json['zIndex'] as int? ?? 0,
      points: (json['points'] as List)
          .map((p) => Offset(
                (p['dx'] as num).toDouble(),
                (p['dy'] as num).toDouble(),
              ))
          .toList(),
      fillColor: Color(json['fillColor'] as int),
      strokeColor: Color(json['strokeColor'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      name: json['name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Elemento de ícono (baño, cocina, etc)
class IconElement extends FloorPlanElement {
  final IconData icon;
  final double size;
  final Color color;
  final String? label;

  const IconElement({
    required super.id,
    required super.type,
    required super.layerId,
    required super.position,
    required this.icon,
    this.size = 48.0,
    this.color = Colors.black,
    this.label,
    super.rotation,
    super.isLocked,
    super.isVisible,
    super.zIndex,
    super.metadata,
  });

  @override
  Rect getBounds() {
    // Si es una mesa con capacidad, usar las dimensiones reales basadas en el tamaño
    if (type == ElementType.table &&
        metadata != null &&
        metadata!.containsKey('tableCapacity')) {
      // Usamos dimensiones aproximadas basadas en el tamaño del elemento

      // Calcular dimensiones del bounds considerando las sillas
      // El tamaño del elemento ya incluye el área de las sillas
      final baseChairPadding = 20.0; // Espacio para sillas (8 distancia + 12 tamaño)
      final scaleFactor = size / 80.0; // 80 es el tamaño base de una mesa de 4
      final chairPadding = baseChairPadding * scaleFactor;

      return Rect.fromCenter(
        center: position,
        width: size + chairPadding * 2,
        height: size + chairPadding * 2,
      );
    }

    return Rect.fromCenter(
      center: position,
      width: size,
      height: size,
    );
  }

  @override
  bool containsPoint(Offset point) {
    return getBounds().contains(point);
  }

  @override
  IconElement copyWith({
    String? id,
    String? layerId,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    int? zIndex,
    Map<String, dynamic>? metadata,
    IconData? icon,
    double? size,
    Color? color,
    String? label,
  }) {
    return IconElement(
      id: id ?? this.id,
      type: type,
      layerId: layerId ?? this.layerId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
      metadata: metadata ?? this.metadata,
      icon: icon ?? this.icon,
      size: size ?? this.size,
      color: color ?? this.color,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'layerId': layerId,
      'position': {'dx': position.dx, 'dy': position.dy},
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'zIndex': zIndex,
      'icon': icon.codePoint,
      'size': size,
      'color': color.toARGB32(),
      'label': label,
      'metadata': metadata,
    };
  }

  factory IconElement.fromJson(Map<String, dynamic> json) {
    // Determinar el tipo de elemento basado en el campo 'type'
    final typeString = json['type'] as String;
    final elementType = ElementType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => ElementType.furniture, // Fallback para tipos desconocidos
    );

    return IconElement(
      id: json['id'] as String,
      type: elementType,
      layerId: json['layerId'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      zIndex: json['zIndex'] as int? ?? 0,
      // Reconstruimos el ícono desde un set const (no `IconData(dynamic)`)
      // para que el tree-shake de íconos del build release no falle.
      icon: floorPlanIconFromCodePoint(json['icon'] as int?),
      size: (json['size'] as num?)?.toDouble() ?? 48.0,
      color: Color(json['color'] as int),
      label: json['label'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Elemento de línea (para paredes, etc)
class LineElement extends FloorPlanElement {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  final String? label;

  const LineElement({
    required super.id,
    required super.layerId,
    required super.position,
    required this.start,
    required this.end,
    this.color = Colors.black,
    this.strokeWidth = 2.0,
    this.label,
    super.rotation,
    super.isLocked,
    super.isVisible,
    super.zIndex,
    super.metadata,
  }) : super(type: ElementType.wall);

  @override
  Rect getBounds() {
    final minX = start.dx < end.dx ? start.dx : end.dx;
    final minY = start.dy < end.dy ? start.dy : end.dy;
    final maxX = start.dx > end.dx ? start.dx : end.dx;
    final maxY = start.dy > end.dy ? start.dy : end.dy;

    return Rect.fromLTRB(
      position.dx + minX,
      position.dy + minY,
      position.dx + maxX,
      position.dy + maxY,
    );
  }

  @override
  bool containsPoint(Offset point) {
    final relativePoint = point - position;
    // Verificar si el punto está cerca de la línea (tolerancia de 5px)
    final tolerance = 5.0;

    final lineLength = (end - start).distance;
    if (lineLength == 0) return false;

    final t = ((relativePoint - start).dx * (end - start).dx +
               (relativePoint - start).dy * (end - start).dy) /
              (lineLength * lineLength);

    if (t < 0 || t > 1) return false;

    final projection = start + (end - start) * t;
    final distance = (relativePoint - projection).distance;

    return distance <= tolerance;
  }

  @override
  LineElement copyWith({
    String? id,
    String? layerId,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    int? zIndex,
    Map<String, dynamic>? metadata,
    Offset? start,
    Offset? end,
    Color? color,
    double? strokeWidth,
    String? label,
  }) {
    return LineElement(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
      metadata: metadata ?? this.metadata,
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'wall',
      'layerId': layerId,
      'position': {'dx': position.dx, 'dy': position.dy},
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'zIndex': zIndex,
      'start': {'dx': start.dx, 'dy': start.dy},
      'end': {'dx': end.dx, 'dy': end.dy},
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'label': label,
      'metadata': metadata,
    };
  }

  factory LineElement.fromJson(Map<String, dynamic> json) {
    return LineElement(
      id: json['id'] as String,
      layerId: json['layerId'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      zIndex: json['zIndex'] as int? ?? 0,
      start: Offset(
        (json['start']['dx'] as num).toDouble(),
        (json['start']['dy'] as num).toDouble(),
      ),
      end: Offset(
        (json['end']['dx'] as num).toDouble(),
        (json['end']['dy'] as num).toDouble(),
      ),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      label: json['label'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Elemento de rectángulo (para habitaciones, etc)
class RectangleElement extends FloorPlanElement {
  final double width;
  final double height;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final String? label;

  const RectangleElement({
    required super.id,
    required super.layerId,
    required super.position,
    required this.width,
    required this.height,
    this.fillColor = Colors.transparent,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.label,
    super.rotation,
    super.isLocked,
    super.isVisible,
    super.zIndex,
    super.metadata,
  }) : super(type: ElementType.zone);

  @override
  Rect getBounds() {
    return Rect.fromLTWH(position.dx, position.dy, width, height);
  }

  @override
  bool containsPoint(Offset point) {
    return getBounds().contains(point);
  }

  @override
  RectangleElement copyWith({
    String? id,
    String? layerId,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    int? zIndex,
    Map<String, dynamic>? metadata,
    double? width,
    double? height,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    String? label,
  }) {
    return RectangleElement(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
      metadata: metadata ?? this.metadata,
      width: width ?? this.width,
      height: height ?? this.height,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'zone',
      'layerId': layerId,
      'position': {'dx': position.dx, 'dy': position.dy},
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'zIndex': zIndex,
      'width': width,
      'height': height,
      'fillColor': fillColor.toARGB32(),
      'strokeColor': strokeColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'label': label,
      'metadata': metadata,
    };
  }

  factory RectangleElement.fromJson(Map<String, dynamic> json) {
    return RectangleElement(
      id: json['id'] as String,
      layerId: json['layerId'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      zIndex: json['zIndex'] as int? ?? 0,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      fillColor: Color(json['fillColor'] as int),
      strokeColor: Color(json['strokeColor'] as int),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      label: json['label'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Elemento de texto
class TextElement extends FloorPlanElement {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  const TextElement({
    required super.id,
    required super.layerId,
    required super.position,
    required this.text,
    this.fontSize = 16.0,
    this.color = Colors.black,
    this.fontWeight = FontWeight.normal,
    super.rotation,
    super.isLocked,
    super.isVisible,
    super.zIndex,
    super.metadata,
  }) : super(type: ElementType.text);

  @override
  Rect getBounds() {
    // Estimación aproximada del tamaño del texto
    final width = text.length * fontSize * 0.6;
    final height = fontSize * 1.2;
    return Rect.fromLTWH(position.dx, position.dy, width, height);
  }

  @override
  bool containsPoint(Offset point) {
    return getBounds().contains(point);
  }

  @override
  TextElement copyWith({
    String? id,
    String? layerId,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    int? zIndex,
    Map<String, dynamic>? metadata,
    String? text,
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextElement(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
      metadata: metadata ?? this.metadata,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'text',
      'layerId': layerId,
      'position': {'dx': position.dx, 'dy': position.dy},
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'zIndex': zIndex,
      'text': text,
      'fontSize': fontSize,
      'color': color.toARGB32(),
      // Guardamos el ÍNDICE del enum (0-8), no `.value` (100-900): el
      // fromJson lee `FontWeight.values[index]`. Cambiar a `.value`
      // rompería los planos ya guardados. Por eso ignoramos la
      // deprecación acá a propósito.
      // ignore: deprecated_member_use
      'fontWeight': fontWeight.index,
      'metadata': metadata,
    };
  }

  factory TextElement.fromJson(Map<String, dynamic> json) {
    return TextElement(
      id: json['id'] as String,
      layerId: json['layerId'] as String,
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      zIndex: json['zIndex'] as int? ?? 0,
      text: json['text'] as String,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      color: Color(json['color'] as int),
      fontWeight: FontWeight.values[json['fontWeight'] as int? ?? 3],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
