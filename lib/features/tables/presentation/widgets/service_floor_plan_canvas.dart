// lib/features/tables/presentation/widgets/service_floor_plan_canvas.dart

import 'package:flutter/material.dart';
import '../../domain/entities/floor_plan.dart';
import '../../domain/entities/floor_plan_element.dart';
import '../../domain/entities/table_status.dart';
import '../../../../core/config/constants/table_enums.dart';
import 'floor_plan_canvas_painter.dart';

/// Widget especializado para renderizar el floor plan en modo servicio
/// Usa el mismo painter que el editor pero sin controles de edición
class ServiceFloorPlanCanvas extends StatefulWidget {
  final FloorPlan floorPlan;
  final List<TableStatusEntity> tableStatuses;
  final Function(String tableElementId)? onTableTap;
  final double zoom;
  final Offset pan;

  const ServiceFloorPlanCanvas({
    super.key,
    required this.floorPlan,
    required this.tableStatuses,
    this.onTableTap,
    this.zoom = 1.0,
    this.pan = Offset.zero,
  });

  @override
  State<ServiceFloorPlanCanvas> createState() => _ServiceFloorPlanCanvasState();
}

class _ServiceFloorPlanCanvasState extends State<ServiceFloorPlanCanvas> {
  String? _hoveredTableId;

  @override
  Widget build(BuildContext context) {
    // Crear un mapa separado de estados por tableElementId (sin mutar entidades)
    final tableStatesMap = _createTableStatesMap();

    // Crear FloorPlan modificado solo con metadata de estados
    final floorPlanWithStates = _injectTableStatesIntoFloorPlan(tableStatesMap);

    return MouseRegion(
      onHover: (event) {
        final position = event.localPosition;
        _handleHover(position, widget.floorPlan);
      },
      onExit: (_) {
        setState(() {
          _hoveredTableId = null;
        });
      },
      child: GestureDetector(
        onTapUp: (details) {
          if (widget.onTableTap != null) {
            _handleTap(details.localPosition, widget.floorPlan);
          }
        },
        child: Stack(
          children: [
            // Usar el painter ORIGINAL del editor para renderizar TODO
            CustomPaint(
              painter: FloorPlanCanvasPainter(
                floorPlan: floorPlanWithStates,
                showGrid: false,
                gridSize: 20,
                zoom: widget.zoom,
                pan: widget.pan,
              ),
              size: Size.infinite,
            ),
            // Solo agregar efecto hover encima
            if (_hoveredTableId != null)
              CustomPaint(
                painter: HoverEffectPainter(
                  floorPlan: widget.floorPlan,
                  hoveredTableId: _hoveredTableId!,
                  zoom: widget.zoom,
                  pan: widget.pan,
                ),
                size: Size.infinite,
              ),
          ],
        ),
      ),
    );
  }

  void _handleHover(Offset position, FloorPlan floorPlan) {
    // Convertir posición de pantalla a coordenadas del canvas
    final canvasPosition = _screenToCanvasPosition(position);

    // Buscar si hay una mesa en esa posición
    String? tableId;
    for (final layer in floorPlan.layers.reversed) {
      if (!layer.isVisible) continue;

      for (final element in layer.elements.reversed) {
        if (element.type == ElementType.table &&
            element.isVisible &&
            element.containsPoint(canvasPosition)) {
          tableId = element.id;
          break;
        }
      }
      if (tableId != null) break;
    }

    if (tableId != _hoveredTableId) {
      setState(() {
        _hoveredTableId = tableId;
      });
    }
  }

  Offset _screenToCanvasPosition(Offset screenPosition) {
    // Convertir de coordenadas de pantalla a coordenadas del canvas
    // Primero restar el pan, luego dividir por zoom
    final x = (screenPosition.dx - widget.pan.dx) / widget.zoom;
    final y = (screenPosition.dy - widget.pan.dy) / widget.zoom;
    return Offset(x, y);
  }

  /// Crea un mapa de estados de mesas por tableElementId
  /// Este approach evita mutar las entidades de dominio
  Map<String, TableStatus> _createTableStatesMap() {
    return {
      for (var status in widget.tableStatuses)
        status.tableElementId: status.status,
    };
  }

  /// Inyecta los estados de las mesas en el metadata del floor plan
  /// Solo para visualización - no muta las entidades originales
  FloorPlan _injectTableStatesIntoFloorPlan(Map<String, TableStatus> tableStatesMap) {
    // Modificar las capas agregando el estado en metadata
    final modifiedLayers = widget.floorPlan.layers.map((layer) {
      final modifiedElements = layer.elements.map((element) {
        // Solo modificar elementos tipo mesa
        if (element.type == ElementType.table) {
          final status = tableStatesMap[element.id];
          if (status != null) {
            // Agregar el estado al metadata (solo para visualización)
            final newMetadata = Map<String, dynamic>.from(element.metadata ?? {});
            newMetadata['tableStatus'] = status.name;

            return element.copyWith(metadata: newMetadata);
          }
        }
        return element;
      }).toList();

      return layer.copyWith(elements: modifiedElements);
    }).toList();

    return widget.floorPlan.copyWith(layers: modifiedLayers);
  }

  /// Maneja el tap en el canvas para detectar si se tocó una mesa
  void _handleTap(Offset position, FloorPlan floorPlan) {
    final canvasPosition = _screenToCanvasPosition(position);

    // Buscar si se hizo clic en una mesa
    for (final layer in floorPlan.layers) {
      for (final element in layer.elements) {
        if (element.type == ElementType.table && element.containsPoint(canvasPosition)) {
          widget.onTableTap?.call(element.id);
          return;
        }
      }
    }
  }
}

/// Painter SOLO para el efecto hover - no renderiza nada más
class HoverEffectPainter extends CustomPainter {
  final FloorPlan floorPlan;
  final String hoveredTableId;
  final double zoom;
  final Offset pan;

  HoverEffectPainter({
    required this.floorPlan,
    required this.hoveredTableId,
    required this.zoom,
    required this.pan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    // Buscar el elemento hovereado
    FloorPlanElement? hoveredElement;
    for (final layer in floorPlan.layers) {
      for (final element in layer.elements) {
        if (element.id == hoveredTableId) {
          hoveredElement = element;
          break;
        }
      }
      if (hoveredElement != null) break;
    }

    if (hoveredElement != null && hoveredElement is IconElement) {
      final center = hoveredElement.position;
      final radius = hoveredElement.size / 2;

      // Sombra de hover
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center.translate(2, 2), radius + 3, shadowPaint);

      // Anillo de highlight brillante
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius + 5, highlightPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(HoverEffectPainter oldDelegate) {
    return oldDelegate.hoveredTableId != hoveredTableId ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}
