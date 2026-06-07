// lib/features/tables/presentation/widgets/floor_plan_canvas_painter.dart

import 'package:flutter/material.dart';
import '../../domain/entities/floor_plan.dart';
import '../../domain/entities/floor_plan_element.dart';
import '../../domain/enums/table_capacity.dart';

class FloorPlanCanvasPainter extends CustomPainter {
  final FloorPlan floorPlan;
  final FloorPlanElement? selectedElement;
  final bool showGrid;
  final double gridSize;
  final List<Offset> currentPolygonPoints;
  final double zoom;
  final Offset pan;
  final Offset? currentLineStart;
  final Offset? currentLineEnd;
  final Offset? currentRectStart;
  final Offset? currentRectEnd;
  final ElementType? draggingIconType;
  final Offset? draggingIconPosition;
  final bool isResizing;
  final bool isRotating;

  // Ghost: icono pre-seleccionado siguiendo al cursor mientras el usuario
  // está en "modo colocación" tras elegir variante en el toolbar.
  final IconData? ghostIcon;
  final Offset? ghostPosition;

  FloorPlanCanvasPainter({
    required this.floorPlan,
    this.selectedElement,
    required this.showGrid,
    required this.gridSize,
    this.currentPolygonPoints = const [],
    required this.zoom,
    required this.pan,
    this.currentLineStart,
    this.currentLineEnd,
    this.currentRectStart,
    this.currentRectEnd,
    this.draggingIconType,
    this.draggingIconPosition,
    this.isResizing = false,
    this.isRotating = false,
    this.ghostIcon,
    this.ghostPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Aplicar transformaciones (pan y zoom)
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    // Dibujar grid
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Dibujar elementos por capas (en orden de z-index)
    final layers = floorPlan.getLayersByZIndex();
    for (final layer in layers) {
      if (!layer.isVisible) continue;

      final opacity = layer.opacity;

      // Ordenar elementos por zIndex dentro de la capa (menor a mayor = atrás a adelante)
      final sortedElements = List<FloorPlanElement>.from(layer.elements)
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

      for (final element in sortedElements) {
        if (!element.isVisible) continue;

        // Verificar si este elemento está seleccionado
        final isSelected = selectedElement != null && element.id == selectedElement!.id;

        _drawElement(canvas, element, opacity, isSelected: isSelected);
      }
    }

    // Dibujar polígono en progreso
    if (currentPolygonPoints.isNotEmpty) {
      _drawCurrentPolygon(canvas);
    }

    // Dibujar preview de línea
    if (currentLineStart != null && currentLineEnd != null) {
      _drawLinePreview(canvas);
    }

    // Dibujar preview de rectángulo
    if (currentRectStart != null && currentRectEnd != null) {
      _drawRectanglePreview(canvas);
    }

    // Dibujar preview de icono arrastrado
    if (draggingIconType != null && draggingIconPosition != null) {
      _drawDraggingIconPreview(canvas);
    }

    // Ghost preview del icono pre-seleccionado, siguiendo al cursor.
    if (ghostIcon != null && ghostPosition != null) {
      _drawGhostIcon(canvas);
    }

    canvas.restore();
  }

  /// Dibuja el icono ghost (semi-transparente) en la posición del cursor para
  /// indicar dónde quedaría colocado al hacer tap.
  void _drawGhostIcon(Canvas canvas) {
    const ghostSize = 48.0;
    final position = ghostPosition!;

    // Círculo de fondo discreto
    canvas.drawCircle(
      position,
      ghostSize / 2 + 2,
      Paint()..color = Colors.blue.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      position,
      ghostSize / 2 + 2,
      Paint()
        ..color = Colors.blue.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / zoom,
    );

    // El icono semi-transparente
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(ghostIcon!.codePoint),
        style: TextStyle(
          fontSize: ghostSize * 0.7,
          fontFamily: ghostIcon!.fontFamily,
          package: ghostIcon!.fontPackage,
          color: Colors.blue.shade700.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    // Líneas verticales
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Líneas horizontales
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawElement(Canvas canvas, FloorPlanElement element, double opacity, {bool isSelected = false}) {
    canvas.save();
    canvas.translate(element.position.dx, element.position.dy);
    canvas.rotate(element.rotation);

    if (element is PolygonElement) {
      _drawPolygon(canvas, element, opacity);
    } else if (element is TextElement) {
      _drawText(canvas, element, opacity);
    } else if (element is LineElement) {
      _drawLine(canvas, element, opacity);
    } else if (element is RectangleElement) {
      _drawRectangle(canvas, element, opacity);
    } else if (element is IconElement) {
      _drawIcon(canvas, element, opacity);
    }

    // Dibujar handles de selección ANTES de restore (con la rotación aplicada)
    if (isSelected) {
      _drawSelectionHandles(canvas, element);
    }

    canvas.restore();
  }

  void _drawPolygon(Canvas canvas, PolygonElement polygon, double opacity) {
    if (polygon.points.isEmpty) return;

    final path = Path();
    path.moveTo(polygon.points[0].dx, polygon.points[0].dy);
    for (int i = 1; i < polygon.points.length; i++) {
      path.lineTo(polygon.points[i].dx, polygon.points[i].dy);
    }
    path.close();

    // Relleno
    if (polygon.fillColor != Colors.transparent) {
      final fillPaint = Paint()
        ..color = polygon.fillColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Borde
    final strokePaint = Paint()
      ..color = polygon.strokeColor.withValues(alpha: opacity)
      ..strokeWidth = polygon.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);

    // Nombre
    if (polygon.name != null && polygon.name!.isNotEmpty) {
      _drawLabel(canvas, polygon.name!, polygon.getBounds().center);
    }
  }

  void _drawText(Canvas canvas, TextElement text, double opacity) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.text,
        style: TextStyle(
          fontSize: text.fontSize,
          color: text.color.withValues(alpha: opacity),
          fontWeight: text.fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }

  void _drawLine(Canvas canvas, LineElement line, double opacity) {
    final paint = Paint()
      ..color = line.color.withValues(alpha: opacity)
      ..strokeWidth = line.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(line.start, line.end, paint);

    // Dibujar etiqueta si existe
    if (line.label != null && line.label!.isNotEmpty) {
      final midPoint = Offset(
        (line.start.dx + line.end.dx) / 2,
        (line.start.dy + line.end.dy) / 2,
      );
      _drawLabel(canvas, line.label!, midPoint);
    }
  }

  void _drawRectangle(Canvas canvas, RectangleElement rectangle, double opacity) {
    final rect = Rect.fromLTWH(0, 0, rectangle.width, rectangle.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // EFECTO 3D - Sombras múltiples para profundidad
    final deepShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final midShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final contactShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Dibujar sombras
    final deepShadowRect = RRect.fromRectAndRadius(
      rect.shift(const Offset(3, 4)),
      const Radius.circular(8),
    );
    canvas.drawRRect(deepShadowRect, deepShadowPaint);

    final midShadowRect = RRect.fromRectAndRadius(
      rect.shift(const Offset(2, 3)),
      const Radius.circular(8),
    );
    canvas.drawRRect(midShadowRect, midShadowPaint);

    final contactShadowRect = RRect.fromRectAndRadius(
      rect.shift(const Offset(1, 1.5)),
      const Radius.circular(8),
    );
    canvas.drawRRect(contactShadowRect, contactShadowPaint);

    // Relleno con gradiente sutil para efecto 3D
    if (rectangle.fillColor != Colors.transparent) {
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          rectangle.fillColor.withValues(alpha: opacity),
          rectangle.fillColor.withValues(alpha: opacity * 0.85),
        ],
      );

      final gradientPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, gradientPaint);
    }

    // Borde exterior
    final strokePaint = Paint()
      ..color = rectangle.strokeColor.withValues(alpha: opacity)
      ..strokeWidth = rectangle.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, strokePaint);

    // Borde interior claro para efecto biselado (highlight)
    if (rectangle.fillColor != Colors.transparent) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.2)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final innerRect = RRect.fromRectAndRadius(
        rect.deflate(rectangle.strokeWidth + 1),
        const Radius.circular(6),
      );
      canvas.drawRRect(innerRect, highlightPaint);
    }

    // Etiqueta
    if (rectangle.label != null && rectangle.label!.isNotEmpty) {
      _drawLabel(canvas, rectangle.label!, rect.center);
    }
  }

  void _drawIcon(Canvas canvas, IconElement iconElement, double opacity) {
    // Verificar si es una mesa con capacidad definida en metadata
    if (iconElement.type == ElementType.table &&
        iconElement.metadata != null &&
        iconElement.metadata?.containsKey('tableCapacity') == true) {
      _drawCustomTable(canvas, iconElement, opacity);
      return;
    }

    // Dibujar ícono estándar usando TextPainter para renderizar el IconData
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconElement.icon.codePoint),
        style: TextStyle(
          fontSize: iconElement.size,
          fontFamily: iconElement.icon.fontFamily,
          package: iconElement.icon.fontPackage,
          color: iconElement.color.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Centrar el ícono en la posición
    textPainter.paint(
      canvas,
      Offset(-iconElement.size / 2, -iconElement.size / 2),
    );

    // Dibujar etiqueta debajo del ícono
    if (iconElement.label != null && iconElement.label!.isNotEmpty) {
      _drawLabel(
        canvas,
        iconElement.label!,
        Offset(0, iconElement.size / 2 + 10),
      );
    }
  }

  void _drawCustomTable(Canvas canvas, IconElement iconElement, double opacity) {
    // Obtener capacidad de la mesa desde metadata (con validación)
    final capacityName = iconElement.metadata?['tableCapacity'] as String?;
    final capacity = capacityName != null
        ? TableCapacity.values.firstWhere(
            (c) => c.name == capacityName,
            orElse: () => TableCapacity.four,
          )
        : TableCapacity.four;

    // Obtener estado de la mesa desde metadata (si existe)
    final tableStatus = iconElement.metadata?['tableStatus'] as String?;

    // Dimensiones de la mesa - usar el tamaño del elemento para hacerlo responsivo
    final baseWidth = capacity.visualWidth;
    final baseHeight = capacity.visualHeight;
    final aspectRatio = baseWidth / baseHeight;

    // Calcular dimensiones finales basadas en el tamaño del elemento
    double width, height;
    if (aspectRatio >= 1.0) {
      width = iconElement.size;
      height = iconElement.size / aspectRatio;
    } else {
      height = iconElement.size;
      width = iconElement.size * aspectRatio;
    }

    final shape = capacity.shape;

    // COLORES SEGÚN ESTADO - Diseño con paleta de colores por estado
    Color tableSurfaceColor;
    Color tableGradientColor;
    Color tableBorderColor;
    Color highlightColor;

    // Definir colores según el estado de la mesa
    switch (tableStatus) {
      case 'available':
        // Verde suave - Mesa disponible
        tableSurfaceColor = const Color(0xFF7FB3D5).withValues(alpha: opacity);
        tableGradientColor = const Color(0xFF5DADE2).withValues(alpha: opacity);
        tableBorderColor = const Color(0xFF2874A6).withValues(alpha: opacity);
        highlightColor = const Color(0xFFAED6F1).withValues(alpha: opacity * 0.4);
        break;
      case 'occupied':
        // Rojo/Coral - Mesa ocupada
        tableSurfaceColor = const Color(0xFFE74C3C).withValues(alpha: opacity);
        tableGradientColor = const Color(0xFFC0392B).withValues(alpha: opacity);
        tableBorderColor = const Color(0xFF922B21).withValues(alpha: opacity);
        highlightColor = const Color(0xFFF1948A).withValues(alpha: opacity * 0.4);
        break;
      case 'reserved':
        // Amarillo/Dorado - Mesa reservada
        tableSurfaceColor = const Color(0xFFF39C12).withValues(alpha: opacity);
        tableGradientColor = const Color(0xFFD68910).withValues(alpha: opacity);
        tableBorderColor = const Color(0xFFB9770E).withValues(alpha: opacity);
        highlightColor = const Color(0xFFF8C471).withValues(alpha: opacity * 0.4);
        break;
      case 'cleaning':
        // Azul claro - En limpieza
        tableSurfaceColor = const Color(0xFF3498DB).withValues(alpha: opacity);
        tableGradientColor = const Color(0xFF2E86C1).withValues(alpha: opacity);
        tableBorderColor = const Color(0xFF1B4F72).withValues(alpha: opacity);
        highlightColor = const Color(0xFF85C1E9).withValues(alpha: opacity * 0.4);
        break;
      case 'maintenance':
        // Morado - En mantenimiento
        tableSurfaceColor = const Color(0xFF9B59B6).withValues(alpha: opacity);
        tableGradientColor = const Color(0xFF7D3C98).withValues(alpha: opacity);
        tableBorderColor = const Color(0xFF4A235A).withValues(alpha: opacity);
        highlightColor = const Color(0xFFD2B4DE).withValues(alpha: opacity * 0.4);
        break;
      default:
        // Gris - Estado por defecto o desconocido
        tableSurfaceColor = const Color(0xFF95A5A6).withValues(alpha: opacity);
        tableGradientColor = const Color(0xFF7F8C8D).withValues(alpha: opacity);
        tableBorderColor = const Color(0xFF566573).withValues(alpha: opacity);
        highlightColor = const Color(0xFFBDC3C7).withValues(alpha: opacity * 0.3);
    }

    // Colores de sillas (siempre gris oscuro elegante)
    final chairColor = const Color(0xFF5D6D7E).withValues(alpha: opacity);
    final chairBorderColor = const Color(0xFF34495E).withValues(alpha: opacity);

    final tableRect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );

    // EFECTO 3D MEJORADO - Múltiples capas de sombra para profundidad
    // Sombra externa profunda
    final deepShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Sombra intermedia
    final midShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Sombra cercana (contacto con superficie)
    final contactShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Dibujar mesa según su forma con efectos 3D mejorados
    switch (shape) {
      case TableShape.square:
        // Sombras múltiples para efecto 3D
        final deepShadowRect = RRect.fromRectAndRadius(
          tableRect.shift(const Offset(4, 6)),
          const Radius.circular(8),
        );
        canvas.drawRRect(deepShadowRect, deepShadowPaint);

        final midShadowRect = RRect.fromRectAndRadius(
          tableRect.shift(const Offset(2, 4)),
          const Radius.circular(8),
        );
        canvas.drawRRect(midShadowRect, midShadowPaint);

        final contactShadowRect = RRect.fromRectAndRadius(
          tableRect.shift(const Offset(1, 2)),
          const Radius.circular(8),
        );
        canvas.drawRRect(contactShadowRect, contactShadowPaint);

        // Mesa con gradiente
        final rrect = RRect.fromRectAndRadius(tableRect, const Radius.circular(8));

        // Gradiente radial para efecto 3D
        final gradient = RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [tableGradientColor, tableSurfaceColor],
        );

        final gradientPaint = Paint()
          ..shader = gradient.createShader(tableRect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rrect, gradientPaint);

        // Borde exterior oscuro
        final borderPaint = Paint()
          ..color = tableBorderColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(rrect, borderPaint);

        // Borde interior claro para efecto biselado
        final innerBorderPaint = Paint()
          ..color = highlightColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final innerRect = RRect.fromRectAndRadius(
          tableRect.deflate(2),
          const Radius.circular(6),
        );
        canvas.drawRRect(innerRect, innerBorderPaint);
        break;

      case TableShape.round:
        // Sombras múltiples circulares para efecto 3D
        canvas.drawCircle(const Offset(4, 6), width / 2, deepShadowPaint);
        canvas.drawCircle(const Offset(2, 4), width / 2, midShadowPaint);
        canvas.drawCircle(const Offset(1, 2), width / 2, contactShadowPaint);

        // Gradiente radial
        final gradient = RadialGradient(
          center: Alignment.topLeft,
          radius: 1.0,
          colors: [tableGradientColor, tableSurfaceColor],
        );

        final gradientPaint = Paint()
          ..shader = gradient.createShader(tableRect)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset.zero, width / 2, gradientPaint);

        // Borde exterior
        final borderPaint = Paint()
          ..color = tableBorderColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset.zero, width / 2, borderPaint);

        // Borde interior
        final innerBorderPaint = Paint()
          ..color = highlightColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset.zero, width / 2 - 2, innerBorderPaint);
        break;

      case TableShape.rectangular:
        // Sombras múltiples para efecto 3D
        final deepShadowRect = RRect.fromRectAndRadius(
          tableRect.shift(const Offset(4, 6)),
          const Radius.circular(12),
        );
        canvas.drawRRect(deepShadowRect, deepShadowPaint);

        final midShadowRect = RRect.fromRectAndRadius(
          tableRect.shift(const Offset(2, 4)),
          const Radius.circular(12),
        );
        canvas.drawRRect(midShadowRect, midShadowPaint);

        final contactShadowRect = RRect.fromRectAndRadius(
          tableRect.shift(const Offset(1, 2)),
          const Radius.circular(12),
        );
        canvas.drawRRect(contactShadowRect, contactShadowPaint);

        // Mesa con gradiente
        final rrect = RRect.fromRectAndRadius(tableRect, const Radius.circular(12));

        final gradient = RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [tableGradientColor, tableSurfaceColor],
        );

        final gradientPaint = Paint()
          ..shader = gradient.createShader(tableRect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rrect, gradientPaint);

        // Borde exterior
        final borderPaint = Paint()
          ..color = tableBorderColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(rrect, borderPaint);

        // Borde interior
        final innerBorderPaint = Paint()
          ..color = highlightColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final innerRect = RRect.fromRectAndRadius(
          tableRect.deflate(2),
          const Radius.circular(10),
        );
        canvas.drawRRect(innerRect, innerBorderPaint);
        break;

      case TableShape.oval:
        // Sombras múltiples para efecto 3D
        canvas.drawOval(tableRect.shift(const Offset(4, 6)), deepShadowPaint);
        canvas.drawOval(tableRect.shift(const Offset(2, 4)), midShadowPaint);
        canvas.drawOval(tableRect.shift(const Offset(1, 2)), contactShadowPaint);

        // Gradiente
        final gradient = RadialGradient(
          center: Alignment.topLeft,
          radius: 1.0,
          colors: [tableGradientColor, tableSurfaceColor],
        );

        final gradientPaint = Paint()
          ..shader = gradient.createShader(tableRect)
          ..style = PaintingStyle.fill;

        canvas.drawOval(tableRect, gradientPaint);

        // Borde exterior
        final borderPaint = Paint()
          ..color = tableBorderColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawOval(tableRect, borderPaint);

        // Borde interior
        final innerBorderPaint = Paint()
          ..color = highlightColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawOval(tableRect.deflate(2), innerBorderPaint);
        break;
    }

    // Dibujar sillas modernas alrededor de la mesa
    _drawModernChairs(canvas, capacity, width, height, chairColor, chairBorderColor, opacity);

    // Dibujar indicador del número de mesa en el centro (moderno y responsive)
    _drawTableNumberIndicator(canvas, iconElement.label, opacity, width, height);
  }

  // Método moderno para dibujar sillas
  void _drawModernChairs(Canvas canvas, TableCapacity capacity, double tableWidth, double tableHeight, Color chairColor, Color chairBorderColor, double opacity) {
    final seats = capacity.seats;

    // Escalar proporcionalmente
    final baseTableSize = 80.0;
    final baseChairSize = 14.0; // Más grande para mejor visibilidad
    final baseChairDistance = 10.0;

    final scaleFactor = (tableWidth + tableHeight) / (baseTableSize * 2);
    final chairSize = baseChairSize * scaleFactor;
    final chairDistance = baseChairDistance * scaleFactor;

    // Distribuir sillas según capacidad
    switch (capacity.shape) {
      case TableShape.square:
      case TableShape.rectangular:
        _drawChairsAroundRectangularTable(
          canvas,
          tableWidth,
          tableHeight,
          seats,
          chairSize,
          chairDistance,
          chairColor,
          chairBorderColor,
          opacity,
        );
        break;

      case TableShape.round:
      case TableShape.oval:
        // Por si se necesitan en el futuro
        break;
    }
  }

  void _drawChairsAroundRectangularTable(
    Canvas canvas,
    double tableWidth,
    double tableHeight,
    int seats,
    double chairSize,
    double chairDistance,
    Color chairColor,
    Color chairBorderColor,
    double opacity,
  ) {
    // Estrategia inteligente de distribución
    final isHorizontal = tableWidth >= tableHeight;

    List<Offset> chairPositions = [];

    if (seats == 2) {
      // Mesa para 2: uno en cada extremo (lados cortos)
      if (isHorizontal) {
        // Horizontal: izquierda y derecha
        chairPositions = [
          Offset(-tableWidth / 2 - chairDistance - chairSize / 2, 0),
          Offset(tableWidth / 2 + chairDistance + chairSize / 2, 0),
        ];
      } else {
        // Vertical: arriba y abajo
        chairPositions = [
          Offset(0, -tableHeight / 2 - chairDistance - chairSize / 2),
          Offset(0, tableHeight / 2 + chairDistance + chairSize / 2),
        ];
      }
    } else if (seats == 4) {
      // Mesa para 4: una en cada lado
      chairPositions = [
        Offset(0, -tableHeight / 2 - chairDistance - chairSize / 2), // Arriba
        Offset(tableWidth / 2 + chairDistance + chairSize / 2, 0),   // Derecha
        Offset(0, tableHeight / 2 + chairDistance + chairSize / 2),  // Abajo
        Offset(-tableWidth / 2 - chairDistance - chairSize / 2, 0),  // Izquierda
      ];
    } else if (seats == 6) {
      // Mesa para 6: 2 en cada lado largo, 1 en cada lado corto
      if (isHorizontal) {
        // 2 arriba
        chairPositions.add(Offset(-tableWidth / 4, -tableHeight / 2 - chairDistance - chairSize / 2));
        chairPositions.add(Offset(tableWidth / 4, -tableHeight / 2 - chairDistance - chairSize / 2));
        // 2 abajo
        chairPositions.add(Offset(-tableWidth / 4, tableHeight / 2 + chairDistance + chairSize / 2));
        chairPositions.add(Offset(tableWidth / 4, tableHeight / 2 + chairDistance + chairSize / 2));
        // 1 izquierda
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, 0));
        // 1 derecha
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, 0));
      } else {
        // 2 izquierda
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, -tableHeight / 4));
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, tableHeight / 4));
        // 2 derecha
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, -tableHeight / 4));
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, tableHeight / 4));
        // 1 arriba
        chairPositions.add(Offset(0, -tableHeight / 2 - chairDistance - chairSize / 2));
        // 1 abajo
        chairPositions.add(Offset(0, tableHeight / 2 + chairDistance + chairSize / 2));
      }
    } else if (seats == 8) {
      // Mesa para 8: 3 en cada lado largo, 1 en cada lado corto
      if (isHorizontal) {
        // 3 arriba
        chairPositions.add(Offset(-tableWidth / 3, -tableHeight / 2 - chairDistance - chairSize / 2));
        chairPositions.add(Offset(0, -tableHeight / 2 - chairDistance - chairSize / 2));
        chairPositions.add(Offset(tableWidth / 3, -tableHeight / 2 - chairDistance - chairSize / 2));
        // 3 abajo
        chairPositions.add(Offset(-tableWidth / 3, tableHeight / 2 + chairDistance + chairSize / 2));
        chairPositions.add(Offset(0, tableHeight / 2 + chairDistance + chairSize / 2));
        chairPositions.add(Offset(tableWidth / 3, tableHeight / 2 + chairDistance + chairSize / 2));
        // 1 izquierda
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, 0));
        // 1 derecha
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, 0));
      } else {
        // 3 izquierda
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, -tableHeight / 3));
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, 0));
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, tableHeight / 3));
        // 3 derecha
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, -tableHeight / 3));
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, 0));
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, tableHeight / 3));
        // 1 arriba
        chairPositions.add(Offset(0, -tableHeight / 2 - chairDistance - chairSize / 2));
        // 1 abajo
        chairPositions.add(Offset(0, tableHeight / 2 + chairDistance + chairSize / 2));
      }
    } else if (seats == 10) {
      // Mesa para 10: 3 en cada lado largo, 2 en cada lado corto
      if (isHorizontal) {
        // 3 arriba
        chairPositions.add(Offset(-tableWidth / 3, -tableHeight / 2 - chairDistance - chairSize / 2));
        chairPositions.add(Offset(0, -tableHeight / 2 - chairDistance - chairSize / 2));
        chairPositions.add(Offset(tableWidth / 3, -tableHeight / 2 - chairDistance - chairSize / 2));
        // 3 abajo
        chairPositions.add(Offset(-tableWidth / 3, tableHeight / 2 + chairDistance + chairSize / 2));
        chairPositions.add(Offset(0, tableHeight / 2 + chairDistance + chairSize / 2));
        chairPositions.add(Offset(tableWidth / 3, tableHeight / 2 + chairDistance + chairSize / 2));
        // 2 izquierda
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, -tableHeight / 4));
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, tableHeight / 4));
        // 2 derecha
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, -tableHeight / 4));
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, tableHeight / 4));
      } else {
        // 3 izquierda
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, -tableHeight / 3));
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, 0));
        chairPositions.add(Offset(-tableWidth / 2 - chairDistance - chairSize / 2, tableHeight / 3));
        // 3 derecha
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, -tableHeight / 3));
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, 0));
        chairPositions.add(Offset(tableWidth / 2 + chairDistance + chairSize / 2, tableHeight / 3));
        // 2 arriba
        chairPositions.add(Offset(-tableWidth / 4, -tableHeight / 2 - chairDistance - chairSize / 2));
        chairPositions.add(Offset(tableWidth / 4, -tableHeight / 2 - chairDistance - chairSize / 2));
        // 2 abajo
        chairPositions.add(Offset(-tableWidth / 4, tableHeight / 2 + chairDistance + chairSize / 2));
        chairPositions.add(Offset(tableWidth / 4, tableHeight / 2 + chairDistance + chairSize / 2));
      }
    }

    // Dibujar cada silla con estilo moderno
    for (final position in chairPositions) {
      _drawModernChair(canvas, position, chairSize, chairColor, chairBorderColor, opacity);
    }
  }

  void _drawModernChair(Canvas canvas, Offset position, double size, Color chairColor, Color borderColor, double opacity) {
    // Sombra de la silla
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: position.translate(1, 1), width: size, height: size),
      Radius.circular(size * 0.25),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // Cuerpo de la silla con gradiente
    final chairRect = Rect.fromCenter(center: position, width: size, height: size);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        chairColor.withValues(alpha: opacity),
        chairColor.withValues(alpha: opacity * 0.8),
      ],
    );

    final chairPaint = Paint()
      ..shader = gradient.createShader(chairRect)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      chairRect,
      Radius.circular(size * 0.25),
    );

    canvas.drawRRect(rrect, chairPaint);

    // Borde
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, borderPaint);

    // Detalle central (respaldo de la silla)
    final detailRect = Rect.fromCenter(
      center: position,
      width: size * 0.4,
      height: size * 0.6,
    );

    final detailPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(detailRect, Radius.circular(size * 0.1)),
      detailPaint,
    );
  }

  void _drawTableNumberIndicator(Canvas canvas, String? tableNumber, double opacity, double tableWidth, double tableHeight) {
    // Si no hay número de mesa, no dibujar nada
    if (tableNumber == null || tableNumber.isEmpty) {
      return;
    }

    // TAMAÑO RESPONSIVE - El indicador escala según el tamaño de la mesa
    final minDimension = tableWidth < tableHeight ? tableWidth : tableHeight;

    // Radio del indicador: entre 15% y 30% de la dimensión menor de la mesa
    // Mínimo 12px, máximo 35px
    double indicatorRadius = (minDimension * 0.22).clamp(12.0, 35.0);

    // Tamaño de fuente responsive: entre 40% y 50% del radio
    double fontSize = (indicatorRadius * 0.75).clamp(10.0, 22.0);

    // Sombra 3D del indicador
    final indicatorShadow = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(const Offset(2, 3), indicatorRadius, indicatorShadow);

    // Círculo de fondo con gradiente elegante
    final gradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.2,
      colors: [
        Colors.white.withValues(alpha: opacity * 0.95),
        Colors.white.withValues(alpha: opacity * 0.85),
      ],
    );

    final indicatorRect = Rect.fromCenter(
      center: Offset.zero,
      width: indicatorRadius * 2,
      height: indicatorRadius * 2,
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(indicatorRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, indicatorRadius, gradientPaint);

    // Borde exterior (sutil)
    final outerBorderPaint = Paint()
      ..color = Colors.grey.shade300.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset.zero, indicatorRadius, outerBorderPaint);

    // Borde interior (brillo)
    final innerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset.zero, indicatorRadius - 2, innerBorderPaint);

    // Número de mesa con estilo moderno
    final tableNumberText = TextPainter(
      text: TextSpan(
        text: tableNumber,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.grey.shade800.withValues(alpha: opacity),
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: opacity * 0.8),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
            Shadow(
              color: Colors.black.withValues(alpha: opacity * 0.15),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tableNumberText.layout();
    tableNumberText.paint(
      canvas,
      Offset(-tableNumberText.width / 2, -tableNumberText.height / 2),
    );
  }

  void _drawLabel(Canvas canvas, String label, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  void _drawSelectionHandles(Canvas canvas, FloorPlanElement element) {
    // Obtener bounds en coordenadas locales (relativas al elemento)
    Rect localBounds;

    if (element is IconElement) {
      // Para IconElement, centrar en 0,0
      final width = element.size;
      final height = element.size;
      localBounds = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    } else if (element is RectangleElement) {
      localBounds = Rect.fromLTWH(0, 0, element.width, element.height);
    } else if (element is LineElement) {
      final minX = element.start.dx < element.end.dx ? element.start.dx : element.end.dx;
      final minY = element.start.dy < element.end.dy ? element.start.dy : element.end.dy;
      final maxX = element.start.dx > element.end.dx ? element.start.dx : element.end.dx;
      final maxY = element.start.dy > element.end.dy ? element.start.dy : element.end.dy;
      localBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    } else if (element is TextElement) {
      final width = element.text.length * element.fontSize * 0.6;
      final height = element.fontSize * 1.2;
      localBounds = Rect.fromLTWH(0, 0, width, height);
    } else {
      // Default: usar bounds globales pero convertirlos a locales
      final globalBounds = element.getBounds();
      localBounds = Rect.fromLTWH(
        globalBounds.left - element.position.dx,
        globalBounds.top - element.position.dy,
        globalBounds.width,
        globalBounds.height,
      );
    }

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(localBounds, paint);

    // Mostrar handles de redimensionamiento para todos los elementos
    // excepto para LineElement que solo usa handles de esquina
    if (element is LineElement) {
      _drawLineResizeHandlesLocal(canvas, element);
    } else {
      _drawResizeHandles(canvas, localBounds);
      // Agregar handle de rotación
      _drawRotationHandle(canvas, localBounds);
    }
  }

  void _drawLineResizeHandlesLocal(Canvas canvas, LineElement line) {
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Tamaño responsivo al zoom - más grande cuando hay zoom out
    final handleSize = 8.0 / zoom.clamp(0.5, 2.0);

    // Dibujar handles en los extremos de la línea (coordenadas locales)
    final handles = [
      line.start,
      line.end,
    ];

    for (final handle in handles) {
      canvas.drawCircle(handle, handleSize / 2, handlePaint);
      canvas.drawCircle(
        handle,
        handleSize / 2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawRotationHandle(Canvas canvas, Rect bounds) {
    // HANDLE DE ROTACIÓN MÁS GRANDE Y VISIBLE
    final rotationHandleDistance = 40.0; // Aumentado de 30 a 40
    // Tamaño responsivo al zoom - más grande cuando hay zoom out
    final handleRadius = 14.0 / zoom.clamp(0.5, 2.0); // Aumentado de 5 a 14

    final rotationHandlePosition = Offset(
      bounds.center.dx,
      bounds.top - rotationHandleDistance,
    );

    // Sombra del handle para mayor visibilidad
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(
      rotationHandlePosition.translate(2, 2),
      handleRadius,
      shadowPaint,
    );

    // Línea conectora más gruesa y visible
    final linePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.7)
      ..strokeWidth = 3.0 // Aumentado de 2 a 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(bounds.center.dx, bounds.top),
      rotationHandlePosition,
      linePaint,
    );

    // Círculo exterior con gradiente
    final gradient = RadialGradient(
      colors: [
        const Color(0xFF4CAF50), // Verde brillante
        const Color(0xFF2E7D32), // Verde oscuro
      ],
    );

    final gradientRect = Rect.fromCircle(
      center: rotationHandlePosition,
      radius: handleRadius,
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(gradientRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(rotationHandlePosition, handleRadius, gradientPaint);

    // Borde blanco grueso para contraste
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0 // Aumentado de 2 a 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(rotationHandlePosition, handleRadius, borderPaint);

    // Borde exterior verde oscuro para aún más contraste
    final outerBorderPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(rotationHandlePosition, handleRadius + 1.5, outerBorderPaint);

    // Icono de rotación más grande y visible
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.rotate_right.codePoint), // Cambiado a rotate_right
        style: TextStyle(
          fontSize: handleRadius * 1.5, // Más grande
          fontFamily: Icons.rotate_right.fontFamily,
          color: Colors.white,
          shadows: [
            const Shadow(
              color: Colors.black38,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        rotationHandlePosition.dx - iconPainter.width / 2,
        rotationHandlePosition.dy - iconPainter.height / 2,
      ),
    );

    // Pulso animado (círculo exterior que sugiere interactividad)
    final pulsePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(rotationHandlePosition, handleRadius + 4, pulsePaint);
  }


  void _drawResizeHandles(Canvas canvas, Rect bounds) {
    // HANDLES MÁS GRANDES Y VISIBLES
    // Tamaño responsivo al zoom - más grande cuando hay zoom out
    final handleRadius = 6.0 / zoom.clamp(0.5, 2.0); // Aumentado de 4 a 6

    final handles = [
      bounds.topLeft,
      bounds.topCenter,
      bounds.topRight,
      bounds.centerRight,
      bounds.bottomRight,
      bounds.bottomCenter,
      bounds.bottomLeft,
      bounds.centerLeft,
    ];

    for (final handle in handles) {
      // Sombra del handle
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(handle.translate(1, 1), handleRadius, shadowPaint);

      // Gradiente azul
      final gradient = RadialGradient(
        colors: [
          const Color(0xFF2196F3), // Azul claro
          const Color(0xFF1976D2), // Azul oscuro
        ],
      );

      final gradientRect = Rect.fromCircle(center: handle, radius: handleRadius);
      final gradientPaint = Paint()
        ..shader = gradient.createShader(gradientRect)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(handle, handleRadius, gradientPaint);

      // Borde blanco grueso
      canvas.drawCircle(
        handle,
        handleRadius,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      // Borde exterior azul oscuro
      canvas.drawCircle(
        handle,
        handleRadius + 1.0,
        Paint()
          ..color = const Color(0xFF0D47A1)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawCurrentPolygon(Canvas canvas) {
    if (currentPolygonPoints.length < 2) {
      // Solo dibujar puntos
      for (final point in currentPolygonPoints) {
        canvas.drawCircle(
          point,
          5,
          Paint()..color = Colors.blue,
        );
      }
      return;
    }

    // Dibujar líneas conectando los puntos
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(currentPolygonPoints[0].dx, currentPolygonPoints[0].dy);
    for (int i = 1; i < currentPolygonPoints.length; i++) {
      path.lineTo(currentPolygonPoints[i].dx, currentPolygonPoints[i].dy);
    }

    canvas.drawPath(path, paint);

    // Dibujar puntos
    for (final point in currentPolygonPoints) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.blue);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawLinePreview(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(currentLineStart!, currentLineEnd!, paint);

    // Dibujar puntos en los extremos
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(currentLineStart!, 5, pointPaint);
    canvas.drawCircle(currentLineEnd!, 5, pointPaint);
  }

  void _drawRectanglePreview(Canvas canvas) {
    final minX = currentRectStart!.dx < currentRectEnd!.dx
        ? currentRectStart!.dx
        : currentRectEnd!.dx;
    final minY = currentRectStart!.dy < currentRectEnd!.dy
        ? currentRectStart!.dy
        : currentRectEnd!.dy;
    final width = (currentRectEnd!.dx - currentRectStart!.dx).abs();
    final height = (currentRectEnd!.dy - currentRectStart!.dy).abs();

    final rect = Rect.fromLTWH(minX, minY, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Sombra suave para el preview
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadowRect = RRect.fromRectAndRadius(
      rect.shift(const Offset(2, 2)),
      const Radius.circular(8),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // Dibujar relleno semitransparente con gradiente
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFE8EAF6).withValues(alpha: 0.4), // Indigo claro
        const Color(0xFFE8EAF6).withValues(alpha: 0.2),
      ],
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, gradientPaint);

    // Dibujar borde con efecto brillante
    final strokePaint = Paint()
      ..color = const Color(0xFF5C6BC0).withValues(alpha: 0.7) // Indigo
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, strokePaint);

    // Borde interior brillante
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final innerRect = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(6),
    );
    canvas.drawRRect(innerRect, highlightPaint);

    // Dibujar puntos en las esquinas con efecto glow
    final glowPaint = Paint()
      ..color = const Color(0xFF5C6BC0).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(currentRectStart!, 8, glowPaint);
    canvas.drawCircle(currentRectEnd!, 8, glowPaint);

    final pointPaint = Paint()
      ..color = const Color(0xFF5C6BC0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentRectStart!, 5, pointPaint);
    canvas.drawCircle(currentRectEnd!, 5, pointPaint);

    // Borde blanco en los puntos
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(currentRectStart!, 5, pointBorderPaint);
    canvas.drawCircle(currentRectEnd!, 5, pointBorderPaint);
  }

  void _drawDraggingIconPreview(Canvas canvas) {
    canvas.save();
    canvas.translate(draggingIconPosition!.dx, draggingIconPosition!.dy);

    IconData icon;
    String previewText = '';

    switch (draggingIconType!) {
      case ElementType.table:
        icon = Icons.table_restaurant;
        previewText = 'Mesa';
        break;
      case ElementType.door:
        icon = Icons.door_sliding;
        break;
      case ElementType.bathroom:
        icon = Icons.wc;
        break;
      case ElementType.kitchen:
        icon = Icons.restaurant; // Cambiado a restaurant (tenedor y cuchillo)
        break;
      case ElementType.bar:
        icon = Icons.local_bar;
        break;
      case ElementType.plant:
        icon = Icons.local_florist;
        break;
      case ElementType.stairs:
        icon = Icons.stairs;
        break;
      default:
        icon = Icons.help_outline;
    }

    final iconSize = 48.0;

    // Dibujar círculo de fondo semitransparente
    canvas.drawCircle(
      Offset.zero,
      iconSize / 2 + 4,
      Paint()
        ..color = Colors.blue.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );

    // Dibujar icono
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.blue.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Centrar el ícono
    textPainter.paint(
      canvas,
      Offset(-iconSize / 2, -iconSize / 2),
    );

    // Si es una mesa, mostrar texto indicando que se mostrará un diálogo
    if (draggingIconType == ElementType.table && previewText.isNotEmpty) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: previewText,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(-labelPainter.width / 2, iconSize / 2 + 8),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(FloorPlanCanvasPainter oldDelegate) {
    return oldDelegate.floorPlan != floorPlan ||
        oldDelegate.selectedElement != selectedElement ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.currentPolygonPoints.length != currentPolygonPoints.length ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.currentLineStart != currentLineStart ||
        oldDelegate.currentLineEnd != currentLineEnd ||
        oldDelegate.currentRectStart != currentRectStart ||
        oldDelegate.currentRectEnd != currentRectEnd ||
        oldDelegate.draggingIconType != draggingIconType ||
        oldDelegate.draggingIconPosition != draggingIconPosition ||
        oldDelegate.isResizing != isResizing ||
        oldDelegate.isRotating != isRotating ||
        oldDelegate.ghostIcon != ghostIcon ||
        oldDelegate.ghostPosition != ghostPosition;
  }
}
