// lib/features/tables/presentation/pages/floor_plan_editor_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../domain/entities/floor_plan_element.dart';
import '../../domain/enums/editor_tool.dart';
import '../controllers/floor_plan_editor_controller.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/layers_panel.dart';
import '../widgets/floor_plan_canvas_painter.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/app_dialog.dart';

class FloorPlanEditorPage extends StatefulWidget {
  const FloorPlanEditorPage({super.key});

  @override
  State<FloorPlanEditorPage> createState() => _FloorPlanEditorPageState();
}

class _FloorPlanEditorPageState extends State<FloorPlanEditorPage> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  FloorPlanEditorController get controller => Get.find<FloorPlanEditorController>();

  @override
  Widget build(BuildContext context) {
    // Detectar si es móvil automáticamente
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Actualizar modo compacto automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMobile || isTablet) {
        controller.setCompactMode(true);
        // En móvil, ocultar panel de capas por defecto
        if (isMobile && controller.showLayersPanel.value) {
          controller.showLayersPanel.value = false;
        }
      } else {
        controller.setCompactMode(false);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          controller.currentFloorPlan.value?.name ?? 'Editor de Planos',
          style: TextStyle(fontSize: isMobile ? 16 : 20),
        )),
        actions: [
          // Toggle Toolbar (móvil)
          if (isMobile)
            Obx(() => IconButton(
              icon: Icon(controller.showToolbar.value ? Icons.close_fullscreen : Icons.open_in_full),
              onPressed: controller.toggleToolbar,
              tooltip: 'Barra de herramientas',
            )),
          // Undo/Redo
          Obx(() {
            controller.historyVersion.value;
            return IconButton(
              icon: Icon(Icons.undo, size: isMobile ? 18 : 20),
              onPressed: controller.commandHistory.canUndo ? controller.undo : null,
              tooltip: 'Deshacer',
            );
          }),
          Obx(() {
            controller.historyVersion.value;
            return IconButton(
              icon: Icon(Icons.redo, size: isMobile ? 18 : 20),
              onPressed: controller.commandHistory.canRedo ? controller.redo : null,
              tooltip: 'Rehacer',
            );
          }),
          // Layer ordering controls
          if (!isMobile)
            Obx(() => PopupMenuButton<String>(
              icon: Icon(Icons.flip_to_front, size: 20),
              tooltip: 'Ordenar capas',
              enabled: controller.selectedElement.value != null,
              onSelected: (value) {
                switch (value) {
                  case 'bring_to_front':
                    controller.bringToFront();
                    break;
                  case 'bring_forward':
                    controller.bringForward();
                    break;
                  case 'send_backward':
                    controller.sendBackward();
                    break;
                  case 'send_to_back':
                    controller.sendToBack();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'bring_to_front',
                  child: Row(
                    children: [
                      Icon(Icons.flip_to_front, size: 18),
                      SizedBox(width: 12),
                      Text('Traer al frente'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'bring_forward',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 18),
                      SizedBox(width: 12),
                      Text('Subir un nivel'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'send_backward',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, size: 18),
                      SizedBox(width: 12),
                      Text('Bajar un nivel'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'send_to_back',
                  child: Row(
                    children: [
                      Icon(Icons.flip_to_back, size: 18),
                      SizedBox(width: 12),
                      Text('Enviar atrás'),
                    ],
                  ),
                ),
              ],
            )),
          // Zoom
          if (!isMobile) ...[
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 20),
              onPressed: controller.zoomOut,
              tooltip: 'Alejar',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              onPressed: controller.zoomIn,
              tooltip: 'Acercar',
            ),
          ],
          // Toggle Layers Panel
          Obx(() => IconButton(
            icon: Icon(
              controller.showLayersPanel.value ? Icons.layers : Icons.layers_outlined,
              size: isMobile ? 18 : 20,
            ),
            onPressed: controller.toggleLayersPanel,
            tooltip: 'Capas',
          )),
          // Save
          Obx(() => controller.isSaving.value
              ? Padding(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                  child: SizedBox(
                    width: isMobile ? 16 : 20,
                    height: isMobile ? 16 : 20,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<String>(
                  icon: Icon(Icons.save, size: isMobile ? 18 : 20),
                  tooltip: 'Guardar',
                  onSelected: (value) async {
                    if (value == 'save') {
                      await controller.saveFloorPlan();
                    } else if (value == 'save_and_service') {
                      await controller.saveFloorPlan();
                      if (controller.currentFloorPlan.value != null) {
                        Get.toNamed(
                          AppRoutes.buildTableService(
                            controller.currentFloorPlan.value!.id,
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(Icons.save, size: 18),
                          SizedBox(width: 12),
                          Text('Guardar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'save_and_service',
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu, size: 18),
                          SizedBox(width: 12),
                          Text('Guardar e Ir a Servicio'),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
          SizedBox(width: isMobile ? 8 : 16),
        ],
      ),
      body: Obx(() => controller.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : controller.currentFloorPlan.value == null
              ? const Center(child: Text('No hay plano cargado'))
              : _buildEditorLayout()),
      floatingActionButton: _buildMobileControls(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget? _buildMobileControls(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (!isMobile) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom In
        FloatingActionButton.small(
          heroTag: 'zoom_in',
          onPressed: controller.zoomIn,
          tooltip: 'Acercar',
          child: const Icon(Icons.zoom_in, size: 20),
        ),
        const SizedBox(height: 8),
        // Zoom Out
        FloatingActionButton.small(
          heroTag: 'zoom_out',
          onPressed: controller.zoomOut,
          tooltip: 'Alejar',
          child: const Icon(Icons.zoom_out, size: 20),
        ),
      ],
    );
  }

  Widget _buildEditorLayout() {
    // Usamos Focus + onKeyEvent (no RawKeyboardListener) porque RawKeyboardListener.onKey
    // es void y no consume el evento — el ESC se propaga al sistema operativo
    // y en macOS dispara "salir de fullscreen" achicando la ventana.
    // onKeyEvent retorna KeyEventResult.handled para evitarlo.
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // ESC: cancelar modo colocación si aplica, y SIEMPRE consumir el
        // evento para que macOS no salga del fullscreen / achique la ventana.
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (controller.pendingIconChoice.value != null) {
            controller.cancelPendingIconChoice();
          } else if (controller.selectedElement.value != null) {
            controller.selectedElement.value = null;
          }
          return KeyEventResult.handled;
        }

        final isCtrl = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        controller.handleKeyboardShortcut(
          event.logicalKey.keyLabel,
          ctrl: isCtrl,
        );
        return KeyEventResult.ignored;
      },
      child: Obx(() => Row(
        children: [
          // Toolbar izquierda (colapsable)
          if (controller.showToolbar.value) const EditorToolbar(),

          // Canvas central
          Expanded(
            child: _buildCanvas(),
          ),

          // Panel de capas derecha (colapsable)
          if (controller.showLayersPanel.value) const LayersPanel(),
        ],
      )),
    );
  }

  Widget _buildCanvas() {
    return Container(
      color: Colors.grey[300],
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Obx(() {
            final floorPlan = controller.currentFloorPlan.value;
            if (floorPlan == null) return const SizedBox();

            // Calcular viewport inicial si es necesario
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.calculateInitialViewport(
                constraints.maxWidth,
                constraints.maxHeight,
              );
            });

            final hasPendingIcon = controller.pendingIconChoice.value != null;

            return Stack(
              children: [
                MouseRegion(
                  cursor: hasPendingIcon
                      ? SystemMouseCursors.precise
                      : SystemMouseCursors.basic,
                  onHover: (event) {
                    controller.hoverWorldPosition.value =
                        _canvasToWorldPosition(event.localPosition);
                  },
                  onExit: (_) {
                    controller.hoverWorldPosition.value = null;
                  },
                  child: GestureDetector(
                    onTapDown: (details) => _handleTapDown(details.localPosition),
                    onPanStart: (details) => _handlePanStart(details.localPosition),
                    onPanUpdate: (details) =>
                        _handlePanUpdate(details.localPosition, details.delta),
                    onPanEnd: (details) => _handlePanEnd(),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: FloorPlanCanvasPainter(
                        floorPlan: floorPlan,
                        selectedElement: controller.selectedElement.value,
                        showGrid: controller.showGrid.value,
                        gridSize: controller.gridSize.value,
                        currentPolygonPoints: controller.currentPolygonPoints.toList(),
                        zoom: controller.zoomLevel.value,
                        pan: controller.panOffset.value,
                        currentLineStart: controller.currentLineStart.value,
                        currentLineEnd: controller.currentLineEnd.value,
                        currentRectStart: controller.currentRectStart.value,
                        currentRectEnd: controller.currentRectEnd.value,
                        draggingIconType: controller.draggingIconType.value,
                        draggingIconPosition: controller.draggingIconPosition.value,
                        isResizing: controller.isResizingElement.value,
                        isRotating: controller.isRotatingElement.value,
                        ghostIcon: hasPendingIcon
                            ? controller.pendingIconChoice.value!.icon
                            : null,
                        ghostPosition: hasPendingIcon
                            ? controller.hoverWorldPosition.value
                            : null,
                      ),
                    ),
                  ),
                ),

                // Banner persistente cuando hay un icono listo para colocar.
                if (hasPendingIcon)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _PlacementBanner(
                      iconData: controller.pendingIconChoice.value!,
                      onCancel: controller.cancelPendingIconChoice,
                    ),
                  ),
              ],
            );
          });
        },
      ),
    );
  }

  Offset? _dragStartPosition;
  Offset? _elementStartPosition;
  Offset? _lineStartPosition;
  Offset? _rectangleStartPosition;

  // Cuando se arrastra un contenedor (rectángulo/polígono), guardamos los
  // elementos que están adentro y sus posiciones iniciales para moverlos
  // junto al contenedor con el mismo delta.
  List<FloorPlanElement>? _groupedElements;
  List<Offset>? _groupedStartPositions;
  Offset? _currentDragPosition;

  void _handleTapDown(Offset position) {
    final tool = controller.currentTool.value;

    // Convertir a coordenadas del mundo
    final worldPosition = _canvasToWorldPosition(position);

    // Si hay un icono pre-elegido en la toolbar, el usuario está en "modo
    // colocación" — cualquier tap en el canvas coloca uno nuevo,
    // ignorando elementos existentes. Esto es lo que se espera de Figma/Miro.
    if (controller.pendingIconChoice.value != null &&
        controller.pendingIconType.value != null &&
        _isIconTool(tool)) {
      // Mesa con capacidad pre-elegida: usar el flow específico para crear
      // la mesa con la capacidad seleccionada en el toolbar (sin re-abrir
      // el dialog de capacidad).
      if (controller.pendingIconType.value == ElementType.table &&
          controller.pendingTableCapacity.value != null) {
        controller.placePendingTable(worldPosition);
      } else {
        controller.addIconElement(worldPosition, controller.pendingIconType.value!);
      }
      return;
    }

    // Verificar si la capa activa está bloqueada
    final activeLayer = controller.currentFloorPlan.value?.getLayer(controller.activeLayerId.value);
    if (activeLayer?.isLocked == true && tool != EditorTool.select && tool != EditorTool.pan) {
      AppSnackbar.show('Error', 'La capa activa está bloqueada');
      return;
    }

    // Si hay un elemento seleccionado y estamos en modo select, verificar handles primero
    if (tool == EditorTool.select && controller.selectedElement.value != null) {
      final selectedElem = controller.selectedElement.value!;

      // Verificar si está sobre el handle de rotación
      if (controller.detectRotationHandle(worldPosition, selectedElem)) {
        // No hacer nada aquí, _handlePanStart se encargará
        return;
      }

      // Verificar si está sobre un handle de resize
      if (controller.detectResizeHandle(worldPosition, selectedElem) != null) {
        // No hacer nada aquí, _handlePanStart se encargará
        return;
      }

      // Verificar si está sobre el mismo elemento seleccionado
      if (selectedElem.containsPoint(worldPosition)) {
        // Está sobre el elemento seleccionado, no hacer nada
        // (permitir que _handlePanStart maneje el drag)
        return;
      }
    }

    // Intentar seleccionar elemento en cualquier caso
    final elementAtPosition = controller.currentFloorPlan.value?.findElementAtPosition(worldPosition);

    if (elementAtPosition != null) {
      // Hay un elemento, seleccionarlo (esto cambiará automáticamente a Select tool)
      controller.selectElementAtPosition(worldPosition);
      return;
    }

    // Si no hay elemento, proceder con la herramienta actual
    if (tool == EditorTool.polygon) {
      if (!controller.isDrawingPolygon.value) {
        controller.startPolygon();
      }
      controller.addPolygonPoint(worldPosition);
    } else if (tool == EditorTool.select) {
      // Deseleccionar si no hay elemento
      controller.selectedElement.value = null;
    } else if (tool == EditorTool.text) {
      _showTextInputDialog(worldPosition);
    } else if (_isIconTool(tool)) {
      // Tap simple coloca el icono en esa posición. Si la toolbar pre-eligió
      // una variante (pendingIconChoice) se usa; si no, addIconElement abre
      // el picker en _showIconSelector.
      controller.addIconElement(worldPosition, _toolToElementType(tool));
    }
  }

  void _showTextInputDialog(Offset position) {
    final textController = TextEditingController();

    AppDialog.show(
      Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 600;
          final isSmallMobile = screenSize.width < 360;
          final safePadding = MediaQuery.of(context).padding;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 40,
              vertical: isMobile ? safePadding.top + 20 : 60,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
              ),
              decoration: BoxDecoration(
                color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMobile ? 20 : 24),
                        topRight: Radius.circular(isMobile ? 20 : 24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_fields,
                          color: theme.colorScheme.onPrimary,
                          size: isSmallMobile ? 24 : (isMobile ? 28 : 32),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        Expanded(
                          child: Text(
                            'Agregar Texto',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onPrimary,
                            size: isMobile ? 20 : 24,
                          ),
                          onPressed: () => Get.back(),
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    child: TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: isMobile ? 2 : 3,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: isMobile ? 15 : 16,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Texto',
                        hintText: 'Ingrese el texto',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          controller.addText(position, value);
                          Get.back();
                        }
                      },
                    ),
                  ),

                  // Footer
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 24,
                              vertical: isMobile ? 12 : 16,
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        ElevatedButton(
                          onPressed: () {
                            final text = textController.text;
                            if (text.trim().isNotEmpty) {
                              controller.addText(position, text);
                              Get.back();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 20 : 28,
                              vertical: isMobile ? 12 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Agregar',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePanStart(Offset position) {
    final tool = controller.currentTool.value;

    // Si hay un elemento seleccionado, permitir drag/handle independiente de
    // qué herramienta esté activa. Antes solo entraba si tool==select, así que
    // si el usuario cambiaba a otra tool tras seleccionar, no podía moverlo.
    if (controller.selectedElement.value != null) {
      final selectedElem = controller.selectedElement.value!;

      // Validar que la capa del elemento no esté bloqueada antes de mover.
      final layer = controller.currentFloorPlan.value?.getLayer(selectedElem.layerId);
      if (layer?.isLocked != true) {
        // Convertir la posición del canvas (con zoom y pan) a coordenadas del mundo
        final worldPosition = _canvasToWorldPosition(position);

        // Si el tap cae en el INTERIOR del elemento (con un margen pensado
        // para los handles), priorizar SIEMPRE el drag sobre el resize.
        // Esto arregla el problema de "no puedo mover elementos chicos
        // porque siempre activo un handle". Solo el anillo exterior (~25%
        // del lado más corto) actúa como zona de resize.
        if (selectedElem.containsPoint(worldPosition)) {
          final bounds = selectedElem.getBounds();
          final shortest = bounds.shortestSide;
          // Margen de handles: lo más chico entre 18px (en world space) y
          // 1/3 del lado más corto. Para elementos diminutos esto evita que
          // los handles ocupen todo el área.
          final handleMargin = math.min(
            18.0 / controller.zoomLevel.value.clamp(0.5, 2.0),
            shortest / 3,
          );
          final inner = bounds.deflate(handleMargin);

          if (inner.contains(worldPosition)) {
            // Centro del elemento → drag inmediato, sin probar handles.
            _dragStartPosition = worldPosition;
            _elementStartPosition = selectedElem.position;
            _captureGroupForDrag(selectedElem);
            return;
          }
        }

        // Tap en el borde del elemento o cerca: probar handles primero.
        final isOnRotationHandle = controller.detectRotationHandle(
          worldPosition,
          selectedElem,
        );

        if (isOnRotationHandle) {
          controller.startRotation(worldPosition);
          return;
        }

        final resizeHandle = controller.detectResizeHandle(
          worldPosition,
          selectedElem,
        );

        if (resizeHandle != null) {
          controller.startResize(resizeHandle);
          return;
        }

        // Si no fue handle pero el tap igual cae sobre el elemento, drag.
        if (selectedElem.containsPoint(worldPosition)) {
          _dragStartPosition = worldPosition;
          _elementStartPosition = selectedElem.position;
          _captureGroupForDrag(selectedElem);
          return;
        }
      }
    }

    if (tool == EditorTool.pan) {
      _dragStartPosition = position;
    } else if (tool == EditorTool.line) {
      final worldPos = _canvasToWorldPosition(position);
      _lineStartPosition = worldPos;
      controller.startLinePreview(worldPos);
    } else if (tool == EditorTool.rectangle) {
      final worldPos = _canvasToWorldPosition(position);
      _rectangleStartPosition = worldPos;
      controller.startRectanglePreview(worldPos);
    } else if (_isIconTool(tool)) {
      // Iniciar arrastre de icono
      final worldPos = _canvasToWorldPosition(position);
      controller.startIconDrag(_toolToElementType(tool));
      controller.updateIconDragPosition(worldPos);
    }
  }

  bool _isIconTool(EditorTool tool) {
    return tool == EditorTool.table ||
        tool == EditorTool.door ||
        tool == EditorTool.bathroom ||
        tool == EditorTool.kitchen ||
        tool == EditorTool.bar ||
        tool == EditorTool.plant ||
        tool == EditorTool.stairs;
  }

  ElementType _toolToElementType(EditorTool tool) {
    switch (tool) {
      case EditorTool.table:
        return ElementType.table;
      case EditorTool.door:
        return ElementType.door;
      case EditorTool.bathroom:
        return ElementType.bathroom;
      case EditorTool.kitchen:
        return ElementType.kitchen;
      case EditorTool.bar:
        return ElementType.bar;
      case EditorTool.plant:
        return ElementType.plant;
      case EditorTool.stairs:
        return ElementType.stairs;
      default:
        return ElementType.table; // Fallback
    }
  }

  void _handlePanUpdate(Offset position, Offset delta) {
    final tool = controller.currentTool.value;

    // Convertir posición a coordenadas del mundo
    final worldPosition = _canvasToWorldPosition(position);

    // Manejar rotación
    if (controller.isRotatingElement.value) {
      controller.updateRotation(worldPosition);
      return;
    }

    // Manejar redimensionamiento
    if (controller.isResizingElement.value) {
      controller.updateResize(worldPosition);
      return;
    }

    if (_dragStartPosition != null && _elementStartPosition != null) {
      // Mover elemento seleccionado independiente de la herramienta activa.
      // Lo importante es que _handlePanStart ya guardó las posiciones de inicio
      // (eso solo pasa si había un elemento seleccionado y no estaba en capa bloqueada).
      final delta = worldPosition - _dragStartPosition!;
      final newPosition = _elementStartPosition! + delta;
      controller.moveSelectedElement(newPosition);

      // Si el elemento es un contenedor (rectángulo/polígono) llevamos
      // también los elementos que estaban adentro al inicio del drag.
      if (_groupedElements != null && _groupedStartPositions != null) {
        controller.moveElementsByDelta(
          _groupedElements!,
          _groupedStartPositions!,
          delta,
        );
      }
    } else if (tool == EditorTool.pan && _dragStartPosition != null) {
      // Pan del canvas
      controller.setPan(controller.panOffset.value + delta);
    } else if (tool == EditorTool.line) {
      // Actualizar preview de línea en tiempo real
      _currentDragPosition = worldPosition;
      controller.updateLinePreview(worldPosition);
    } else if (tool == EditorTool.rectangle) {
      // Actualizar preview de rectángulo en tiempo real
      _currentDragPosition = worldPosition;
      controller.updateRectanglePreview(worldPosition);
    } else if (_isIconTool(tool)) {
      // Actualizar posición del icono arrastrado
      controller.updateIconDragPosition(worldPosition);
    }
  }

  void _handlePanEnd() {
    final tool = controller.currentTool.value;

    // Manejar finalización de rotación
    if (controller.isRotatingElement.value) {
      controller.finishRotation();
      return;
    }

    // Manejar finalización de redimensionamiento
    if (controller.isResizingElement.value) {
      controller.finishResize();
      return;
    }

    // Manejar finalización de línea
    if (tool == EditorTool.line && _lineStartPosition != null) {
      final endPosition = _currentDragPosition ?? _lineStartPosition!;
      controller.addLine(_lineStartPosition!, endPosition);
      _lineStartPosition = null;
    }

    // Manejar finalización de rectángulo
    if (tool == EditorTool.rectangle && _rectangleStartPosition != null) {
      final endPosition = _currentDragPosition ?? _rectangleStartPosition!;
      controller.addRectangle(_rectangleStartPosition!, endPosition);
      _rectangleStartPosition = null;
    }

    // Manejar finalización de arrastre de icono
    if (_isIconTool(tool) && controller.draggingIconPosition.value != null) {
      controller.finishIconDrag(controller.draggingIconPosition.value!);
    }

    _dragStartPosition = null;
    _elementStartPosition = null;
    _currentDragPosition = null;
    _groupedElements = null;
    _groupedStartPositions = null;
  }

  /// Si el elemento que se va a arrastrar es un contenedor (Rectangle o
  /// Polygon), capturamos los elementos que están dentro de su bounding box
  /// y sus posiciones actuales. Durante el drag los movemos por el mismo
  /// delta para que "viajen" con el contenedor.
  void _captureGroupForDrag(FloorPlanElement element) {
    if (element is RectangleElement || element is PolygonElement) {
      final inside = controller.elementsInside(
        element.getBounds(),
        excludeId: element.id,
      );
      _groupedElements = inside;
      _groupedStartPositions = inside.map((e) => e.position).toList();
    } else {
      _groupedElements = null;
      _groupedStartPositions = null;
    }
  }

  /// Convierte coordenadas del canvas (con zoom y pan) a coordenadas del mundo
  Offset _canvasToWorldPosition(Offset canvasPosition) {
    // Deshacer el pan
    final afterPan = canvasPosition - controller.panOffset.value;

    // Deshacer el zoom
    final worldPosition = afterPan / controller.zoomLevel.value;

    return worldPosition;
  }
}

/// Banner persistente que aparece sobre el canvas cuando hay un icono
/// pre-seleccionado listo para colocar. Da feedback visual claro de que el
/// editor está en "modo colocación" y deja al usuario salir con un tap en ✕.
class _PlacementBanner extends StatelessWidget {
  final dynamic iconData; // FloorPlanIconData
  final VoidCallback onCancel;

  const _PlacementBanner({
    required this.iconData,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: Colors.blue.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(iconData.icon as IconData,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Toca el plano para colocar ${iconData.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Podés colocar varios. ESC o ✕ para cancelar.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              tooltip: 'Cancelar (ESC)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
