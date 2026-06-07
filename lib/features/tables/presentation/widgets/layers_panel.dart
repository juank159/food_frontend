// lib/features/tables/presentation/widgets/layers_panel.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/floor_plan_editor_controller.dart';

class LayersPanel extends GetView<FloorPlanEditorController> {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCompact = controller.isCompactMode.value;
      final panelWidth = isCompact ? 220.0 : 270.0;

      return Container(
        width: panelWidth,
        color: Colors.grey[100],
        child: Column(
          children: [
            _buildHeader(isCompact),

            // Layers list
            Expanded(
              child: Obx(() {
                final floorPlan = controller.currentFloorPlan.value;
                if (floorPlan == null) {
                  return const Center(child: Text('No hay plano cargado'));
                }

                final layers = floorPlan.getLayersByZIndex().reversed.toList();
                final selectedElement = controller.selectedElement.value;

                return ListView.builder(
                  itemCount: layers.length,
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    final isActive = controller.activeLayerId.value == layer.id;
                    final hasSelectedFromOtherLayer = selectedElement != null &&
                        selectedElement.layerId != layer.id;

                    return _LayerTile(
                      layerName: layer.name,
                      elementCount: layer.elements.length,
                      isActive: isActive,
                      isVisible: layer.isVisible,
                      isLocked: layer.isLocked,
                      isCompact: isCompact,
                      showMoveHere: hasSelectedFromOtherLayer && !layer.isLocked,
                      onTap: () => controller.setActiveLayer(layer.id),
                      onToggleVisibility: () =>
                          controller.toggleLayerVisibility(layer.id),
                      onToggleLock: () => controller.toggleLayerLock(layer.id),
                      onMoveHere: () =>
                          controller.moveSelectedElementToLayer(layer.id),
                    );
                  },
                );
              }),
            ),

            _buildFooter(isCompact),
          ],
        ),
      );
    });
  }

  /// Header con la capa activa visible para que el usuario sepa dónde van
  /// los elementos nuevos.
  Widget _buildHeader(bool isCompact) {
    return Obx(() {
      final fp = controller.currentFloorPlan.value;
      final activeId = controller.activeLayerId.value;
      final activeLayer = fp?.getLayer(activeId);
      final activeName = activeLayer?.name ?? '—';
      final count = activeLayer?.elements.length ?? 0;

      return Container(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          border: Border(bottom: BorderSide(color: Colors.blue.shade900)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers, size: isCompact ? 18 : 22, color: Colors.white),
                SizedBox(width: isCompact ? 6 : 8),
                Text(
                  'Capas',
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.adjust, size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Activa: $activeName · $count elementos',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFooter(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _onCreateLayer,
          icon: const Icon(Icons.add, size: 18),
          label: Text('Nueva capa', style: TextStyle(fontSize: isCompact ? 12 : 14)),
          style: TextButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Future<void> _onCreateLayer() async {
    final textController = TextEditingController();
    final name = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Nueva capa'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la capa',
            hintText: 'Ej. Mesas VIP, Cocina, Decoración',
          ),
          onSubmitted: (v) => Get.back(result: v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Get.back(result: textController.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      controller.createLayer(name);
    }
  }
}

/// Una fila del listado de capas. Extraída para mantener el build principal
/// liviano y para incluir el botón "Mover aquí" cuando aplique.
class _LayerTile extends StatelessWidget {
  final String layerName;
  final int elementCount;
  final bool isActive;
  final bool isVisible;
  final bool isLocked;
  final bool isCompact;
  final bool showMoveHere;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final VoidCallback onMoveHere;

  const _LayerTile({
    required this.layerName,
    required this.elementCount,
    required this.isActive,
    required this.isVisible,
    required this.isLocked,
    required this.isCompact,
    required this.showMoveHere,
    required this.onTap,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onMoveHere,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue[50] : Colors.white,
        border: Border.all(
          color: isActive ? Colors.blue : Colors.grey[300]!,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity:
                isCompact ? VisualDensity.compact : VisualDensity.standard,
            onTap: onTap,
            leading: Icon(
              isActive ? Icons.adjust : Icons.layers_outlined,
              size: isCompact ? 16 : 20,
              color: isActive ? Colors.blue : Colors.grey[600],
            ),
            title: Text(
              layerName,
              style: TextStyle(
                fontSize: isCompact ? 12 : 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isVisible ? null : Colors.grey,
                decoration: isVisible ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Text(
              '$elementCount elemento${elementCount == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    size: isCompact ? 16 : 20,
                    color: isVisible ? Colors.grey[700] : Colors.grey[400],
                  ),
                  padding: EdgeInsets.all(isCompact ? 4 : 8),
                  constraints: BoxConstraints(
                    minWidth: isCompact ? 28 : 36,
                    minHeight: isCompact ? 28 : 36,
                  ),
                  onPressed: onToggleVisibility,
                  tooltip: isVisible ? 'Ocultar capa' : 'Mostrar capa',
                ),
                IconButton(
                  icon: Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    size: isCompact ? 16 : 20,
                    color: isLocked ? Colors.orange[700] : Colors.grey[700],
                  ),
                  padding: EdgeInsets.all(isCompact ? 4 : 8),
                  constraints: BoxConstraints(
                    minWidth: isCompact ? 28 : 36,
                    minHeight: isCompact ? 28 : 36,
                  ),
                  onPressed: onToggleLock,
                  tooltip:
                      isLocked ? 'Desbloquear capa' : 'Bloquear capa',
                ),
              ],
            ),
          ),

          // Acción "Mover aquí" — visible solo cuando hay un elemento
          // seleccionado de OTRA capa y esta capa NO está bloqueada.
          if (showMoveHere)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onMoveHere,
                  icon: const Icon(Icons.subdirectory_arrow_right, size: 16),
                  label: Text(
                    'Mover selección aquí',
                    style: TextStyle(fontSize: isCompact ? 11 : 12),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
