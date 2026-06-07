import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../domain/entities/table.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Draggable Table Widget
/// Widget que representa una mesa arrastrable en el mapa visual
class DraggableTableWidget extends StatefulWidget {
  final RestaurantTable table;
  final Offset initialPosition;
  final double rotation;
  final Function(Offset) onPositionChanged;
  final VoidCallback? onRotate;

  const DraggableTableWidget({
    super.key,
    required this.table,
    required this.initialPosition,
    this.rotation = 0.0,
    required this.onPositionChanged,
    this.onRotate,
  });

  @override
  State<DraggableTableWidget> createState() => _DraggableTableWidgetState();
}

class _DraggableTableWidgetState extends State<DraggableTableWidget> {
  late Offset position;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
  }

  @override
  void didUpdateWidget(DraggableTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPosition != widget.initialPosition) {
      setState(() {
        position = widget.initialPosition;
      });
    }
  }

  Color _getStatusColor() {
    switch (widget.table.status) {
      case TableStatus.available:
        return Colors.green;
      case TableStatus.occupied:
        return Colors.orange;
      case TableStatus.reserved:
        return Colors.purple;
      case TableStatus.cleaning:
        return Colors.blue;
      case TableStatus.maintenance:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onLongPress: () {
          // Mostrar menú contextual
          _showContextMenu(context);
        },
        child: Draggable(
          feedback: Material(
            color: Colors.transparent,
            child: Transform.rotate(
              angle: widget.rotation * 3.14159 / 180,
              child: _buildTableShape(isDragging: true),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: Transform.rotate(
              angle: widget.rotation * 3.14159 / 180,
              child: _buildTableShape(),
            ),
          ),
          onDragEnd: (details) {
            setState(() {
              position = details.offset;
            });
            widget.onPositionChanged(position);
          },
          child: Transform.rotate(
            angle: widget.rotation * 3.14159 / 180,
            child: _buildTableShape(),
          ),
        ),
      ),
    );
  }

  Widget _buildTableShape({bool isDragging = false}) {
    final color = _getStatusColor();
    final size = Size(widget.table.width, widget.table.height);

    return GestureDetector(
      onTap: () {
        // Mostrar detalles de la mesa
        _showTableDetails(context);
      },
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: isDragging ? color.withValues(alpha: 0.7) : color.withValues(alpha: 0.3),
          border: Border.all(
            color: color,
            width: 2,
          ),
          borderRadius: widget.table.shapeType == 'circle'
              ? BorderRadius.circular(size.width / 2)
              : widget.table.shapeType == 'square'
                  ? BorderRadius.circular(8)
                  : BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDragging ? 0.4 : 0.2),
              blurRadius: isDragging ? 8 : 4,
              offset: Offset(isDragging ? 4 : 2, isDragging ? 4 : 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.table.tableNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (widget.table.capacity > 0)
                Text(
                  '${widget.table.capacity}p',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              if (widget.rotation != 0)
                Icon(
                  Icons.rotate_right,
                  size: 12,
                  color: color.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mesa ${widget.table.tableNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rotate_right),
              title: const Text('Rotar 45°'),
              onTap: () {
                Get.back();
                if (widget.onRotate != null) {
                  widget.onRotate!();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Ver detalles'),
              onTap: () {
                Get.back();
                _showTableDetails(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showTableDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mesa ${widget.table.tableNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Estado', widget.table.statusDisplay),
              _buildDetailRow('Capacidad', '${widget.table.capacity} personas'),
              if (widget.table.minCapacity > 0)
                _buildDetailRow(
                    'Cap. Mínima', '${widget.table.minCapacity} personas'),
              if (widget.table.zone != null)
                _buildDetailRow('Zona', widget.table.zone!),
              if (widget.table.section != null)
                _buildDetailRow('Sección', widget.table.section!),
              if (widget.table.isOccupied &&
                  widget.table.occupationDuration != null)
                _buildDetailRow(
                  'Ocupada desde',
                  widget.table.occupationDurationFormatted,
                ),
              if (widget.table.assignedTo != null)
                _buildDetailRow('Asignada a', widget.table.assignedTo!),
              const Divider(),
              _buildDetailRow('Posición X', '${position.dx.round()}px'),
              _buildDetailRow('Posición Y', '${position.dy.round()}px'),
              _buildDetailRow('Rotación', '${widget.rotation.round()}°'),
              _buildDetailRow('Forma', widget.table.shapeType),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (widget.table.isAvailable)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // El editor de planos es para diseñar el layout, no para
                // operar el servicio. Para ocupar una mesa el flujo correcto
                // es la pantalla de servicio (TableStatusPage), donde el
                // dialog `OccupyTableDialog` corre con el estado real
                // (party size, server, etc).
                AppSnackbar.show(
                  'Ocupar mesa',
                  'Disponible solo desde la pantalla de servicio',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              child: const Text('Ocupar'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
