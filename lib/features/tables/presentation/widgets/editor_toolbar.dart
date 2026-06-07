// lib/features/tables/presentation/widgets/editor_toolbar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/floor_plan_element.dart';
import '../../domain/enums/editor_tool.dart';
import '../../domain/enums/floor_plan_icons.dart';
import '../../domain/enums/table_capacity.dart';
import '../controllers/floor_plan_editor_controller.dart';
import 'icon_selector_dialog.dart';
import 'table_selector_dialog.dart';

class EditorToolbar extends GetView<FloorPlanEditorController> {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCompact = controller.isCompactMode.value;
      final toolbarWidth = isCompact ? 56.0 : 80.0;
      final iconSize = isCompact ? 20.0 : 28.0;
      final buttonSize = isCompact ? 40.0 : 56.0;

      return Container(
        width: toolbarWidth,
        color: Colors.grey[900],
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Logo o título (solo en modo no compacto)
            if (!isCompact) ...[
              const Text(
                'Editor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
            ],
            const Divider(color: Colors.grey, height: 1),

            // Sección scrollable con las herramientas
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Herramientas básicas
                    _buildToolButton(EditorTool.select, Icons.near_me, iconSize, buttonSize),
                    _buildToolButton(EditorTool.pan, Icons.pan_tool, iconSize, buttonSize),

                    const Divider(color: Colors.grey, height: 1),

                    // Herramientas de dibujo
                    _buildToolButton(EditorTool.polygon, Icons.pentagon_outlined, iconSize, buttonSize),
                    _buildToolButton(EditorTool.line, Icons.show_chart, iconSize, buttonSize),
                    _buildToolButton(EditorTool.rectangle, Icons.rectangle_outlined, iconSize, buttonSize),
                    _buildToolButton(EditorTool.text, Icons.text_fields, iconSize, buttonSize),

                    const Divider(color: Colors.grey, height: 1),

                    // Elementos predefinidos
                    _buildToolButton(EditorTool.door, Icons.door_sliding, iconSize, buttonSize),
                    _buildToolButton(EditorTool.bathroom, Icons.wc, iconSize, buttonSize),
                    _buildToolButton(EditorTool.kitchen, Icons.restaurant, iconSize, buttonSize), // Cambiado a restaurant
                    _buildToolButton(EditorTool.bar, Icons.local_bar, iconSize, buttonSize),
                    _buildToolButton(EditorTool.plant, Icons.local_florist, iconSize, buttonSize),
                    _buildToolButton(EditorTool.stairs, Icons.stairs, iconSize, buttonSize),
                    _buildToolButton(EditorTool.table, Icons.table_restaurant, iconSize, buttonSize),
                  ],
                ),
              ),
            ),

            // Controles adicionales (fijos al fondo)
            IconButton(
              icon: Icon(Icons.grid_on, color: Colors.white, size: iconSize),
              iconSize: iconSize,
              padding: EdgeInsets.all(isCompact ? 8 : 12),
              onPressed: controller.toggleGrid,
              tooltip: 'Cuadrícula',
            ),
            Obx(() => IconButton(
              icon: Icon(
                controller.snapToGrid.value ? Icons.grid_4x4 : Icons.grid_off,
                color: controller.snapToGrid.value ? Colors.blue : Colors.white,
                size: iconSize,
              ),
              iconSize: iconSize,
              padding: EdgeInsets.all(isCompact ? 8 : 12),
              onPressed: controller.toggleSnapToGrid,
              tooltip: 'Ajustar a cuadrícula',
            )),

            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  /// Tap en una herramienta de la toolbar.
  ///
  /// Tres caminos posibles:
  ///   1. Herramientas con galería de variantes (baños/puertas/cocina/bar/
  ///      plantas) → abre IconSelectorDialog y guarda la elección.
  ///   2. Mesa → abre TableSelectorDialog para elegir capacidad.
  ///   3. Escalera → no tiene variantes, entra directo a "modo colocación".
  ///   4. Otras herramientas (select, pan, polígono, línea, etc.) → solo
  ///      activan la tool sin pre-elección.
  Future<void> _onToolTap(EditorTool tool) async {
    controller.selectTool(tool);

    final iconCategory = _categoryFor(tool);
    if (iconCategory != null) {
      final selected = await Get.dialog<FloorPlanIconData>(
        IconSelectorDialog(category: iconCategory),
      );
      if (selected != null) {
        controller.setPendingIconChoice(_typeFor(tool), selected);
      }
      return;
    }

    if (tool == EditorTool.table) {
      final capacity = await Get.dialog<TableCapacity>(
        const TableSelectorDialog(),
      );
      if (capacity != null) {
        controller.setPendingTablePlacement(capacity);
      }
      return;
    }

    if (tool == EditorTool.stairs) {
      controller.setPendingStairsPlacement();
      return;
    }
  }

  String? _categoryFor(EditorTool tool) {
    switch (tool) {
      case EditorTool.bathroom:
        return 'bathroom';
      case EditorTool.kitchen:
        return 'kitchen';
      case EditorTool.door:
        return 'door';
      case EditorTool.bar:
        return 'bar';
      case EditorTool.plant:
        return 'decoration';
      default:
        return null;
    }
  }

  ElementType _typeFor(EditorTool tool) {
    switch (tool) {
      case EditorTool.bathroom:
        return ElementType.bathroom;
      case EditorTool.kitchen:
        return ElementType.kitchen;
      case EditorTool.door:
        return ElementType.door;
      case EditorTool.bar:
        return ElementType.bar;
      case EditorTool.plant:
        return ElementType.plant;
      case EditorTool.stairs:
        return ElementType.stairs;
      case EditorTool.table:
        return ElementType.table;
      default:
        return ElementType.table;
    }
  }

  Widget _buildToolButton(EditorTool tool, IconData icon, double iconSize, double buttonSize) {
    return Obx(() {
      final isSelected = controller.currentTool.value == tool;
      final isCompact = controller.isCompactMode.value;

      return Tooltip(
        message: isCompact ? tool.displayName : '${tool.displayName} (${tool.shortcut})',
        child: Container(
          margin: EdgeInsets.symmetric(vertical: isCompact ? 2 : 4, horizontal: isCompact ? 4 : 12),
          child: Material(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
            child: InkWell(
              onTap: () => _onToolTap(tool),
              borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
