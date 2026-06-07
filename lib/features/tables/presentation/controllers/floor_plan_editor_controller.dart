// lib/features/tables/presentation/controllers/floor_plan_editor_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../domain/entities/floor_plan.dart';
import '../../domain/entities/floor_plan_element.dart';
import '../../domain/entities/floor_plan_layer.dart';
import '../../domain/commands/floor_plan_command.dart';
import '../../domain/commands/element_commands.dart';
import '../../domain/enums/editor_tool.dart';
import '../../domain/repositories/floor_plan_repository.dart';
import '../../domain/enums/table_capacity.dart';
import '../../domain/enums/floor_plan_icons.dart';
import '../widgets/table_selector_dialog.dart';
import '../widgets/icon_selector_dialog.dart';
import 'floor_plans_list_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Enum para los handles de redimensionamiento
enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  centerRight,
  bottomRight,
  bottomCenter,
  bottomLeft,
  centerLeft,
}

class FloorPlanEditorController extends GetxController {
  final FloorPlanRepository repository;
  final _uuid = const Uuid();

  FloorPlanEditorController({required this.repository});

  // Estado del Floor Plan actual
  final Rx<FloorPlan?> currentFloorPlan = Rx<FloorPlan?>(null);

  // Historial de comandos para Undo/Redo
  final commandHistory = CommandHistory();
  final RxInt historyVersion = RxInt(0); // Para notificar cambios en historial

  // Herramienta actual seleccionada
  final Rx<EditorTool> currentTool = Rx<EditorTool>(EditorTool.select);

  // Capa activa
  final RxString activeLayerId = RxString('layer_walls');

  // Elemento seleccionado
  final Rx<FloorPlanElement?> selectedElement = Rx<FloorPlanElement?>(null);

  // Transformación del canvas (zoom y pan)
  final RxDouble zoomLevel = RxDouble(1.0);
  final Rx<Offset> panOffset = Rx<Offset>(Offset.zero);

  // Estado de dibujo de polígono
  final RxList<Offset> currentPolygonPoints = RxList<Offset>([]);
  final RxBool isDrawingPolygon = RxBool(false);

  // Estado de preview en tiempo real
  final Rx<Offset?> currentLineStart = Rx<Offset?>(null);
  final Rx<Offset?> currentLineEnd = Rx<Offset?>(null);
  final Rx<Offset?> currentRectStart = Rx<Offset?>(null);
  final Rx<Offset?> currentRectEnd = Rx<Offset?>(null);

  // Estado para arrastrar iconos desde toolbar
  final Rx<ElementType?> draggingIconType = Rx<ElementType?>(null);
  final Rx<Offset?> draggingIconPosition = Rx<Offset?>(null);

  // Pre-elección de icono (cuando el usuario tocó la herramienta en la
  // toolbar y eligió un sub-tipo en el dialog). Si está seteado, el siguiente
  // tap/drag en el canvas lo usa directamente sin re-abrir el picker.
  final Rx<ElementType?> pendingIconType = Rx<ElementType?>(null);
  final Rx<FloorPlanIconData?> pendingIconChoice = Rx<FloorPlanIconData?>(null);

  // Capacidad pre-elegida cuando el usuario seleccionó "Mesa" en la toolbar
  // y abrió el TableSelectorDialog. Se aplica en el siguiente tap del canvas.
  final Rx<TableCapacity?> pendingTableCapacity = Rx<TableCapacity?>(null);

  // Posición actual del cursor en world-space, usada para el ghost preview
  // cuando hay una elección de icono pendiente. Null cuando el cursor sale
  // del canvas.
  final Rx<Offset?> hoverWorldPosition = Rx<Offset?>(null);

  // Estado de carga
  final RxBool isLoading = RxBool(false);
  final RxBool isSaving = RxBool(false);

  // Control de viewport inicial (para evitar recalcular en cada rebuild)
  bool _viewportInitialized = false;
  double _lastCanvasWidth = 0;
  double _lastCanvasHeight = 0;

  // Estado de redimensionamiento
  final RxBool isResizingElement = RxBool(false);
  final Rx<ResizeHandle?> activeResizeHandle = Rx<ResizeHandle?>(null);
  Map<String, dynamic>? _initialResizeState;
  Offset? _resizeStartPosition;

  // Estado de rotación
  final RxBool isRotatingElement = RxBool(false);
  double? _initialRotation;
  Offset? _rotationCenter;
  double? _initialAngle;

  // Grid
  final RxBool showGrid = RxBool(true);
  final RxBool snapToGrid = RxBool(true);
  final RxDouble gridSize = RxDouble(20.0);

  // UI Responsive - Control de paneles
  final RxBool showToolbar = RxBool(true);
  final RxBool showLayersPanel = RxBool(true);
  final RxBool isCompactMode = RxBool(false);

  @override
  void onInit() {
    super.onInit();
    final floorPlanId = Get.arguments?['floorPlanId'] as String?;
    if (floorPlanId != null) {
      loadFloorPlanById(floorPlanId);
    } else {
      loadFloorPlans();
    }
  }

  // ========== UI Controls ==========

  void toggleToolbar() {
    showToolbar.value = !showToolbar.value;
  }

  void toggleLayersPanel() {
    showLayersPanel.value = !showLayersPanel.value;
  }

  void setCompactMode(bool compact) {
    isCompactMode.value = compact;
  }

  // ========== CRUD Operations ==========

  /// Cargar un floor plan específico por ID
  Future<void> loadFloorPlanById(String floorPlanId) async {
    try {
      isLoading.value = true;
      final floorPlan = await repository.getFloorPlanById(floorPlanId);
      currentFloorPlan.value = floorPlan;
      gridSize.value = floorPlan.gridSize;
      showGrid.value = floorPlan.showGrid;

      // Resetear el flag para que se calcule el viewport inicial
      _viewportInitialized = false;
    } catch (e) {
      AppSnackbar.show('Error', 'Error al cargar plano: $e');
      Get.back(); // Volver a la lista si falla
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadFloorPlans() async {
    try {
      isLoading.value = true;
      final floorPlans = await repository.getFloorPlans();
      if (floorPlans.isNotEmpty) {
        currentFloorPlan.value = floorPlans.first;
        gridSize.value = floorPlans.first.gridSize;
        showGrid.value = floorPlans.first.showGrid;
      } else {
        // Crear floor plan vacío por defecto
        await createNewFloorPlan('Principal');
      }
    } catch (e) {
      AppSnackbar.show('Error', 'Error al cargar planos: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createNewFloorPlan(String name) async {
    try {
      isSaving.value = true;
      // Crear un plano temporal sin ID (el backend lo generará)
      final newFloorPlan = FloorPlan.empty(
        id: '', // Placeholder ID, será reemplazado por el backend
        name: name,
      );
      final created = await repository.createFloorPlan(newFloorPlan);
      currentFloorPlan.value = created;
      commandHistory.clear();
      _refreshListIfRegistered();
      AppSnackbar.show('Éxito', 'Plano creado exitosamente');
    } catch (e) {
      AppSnackbar.show('Error', 'Error al crear plano: $e');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveFloorPlan() async {
    if (currentFloorPlan.value == null) return;

    try {
      isSaving.value = true;
      await repository.updateFloorPlan(
        currentFloorPlan.value!.id,
        currentFloorPlan.value!,
      );
      _refreshListIfRegistered();
      AppSnackbar.show('Éxito', 'Plano guardado exitosamente');
    } catch (e) {
      AppSnackbar.show('Error', 'Error al guardar plano: $e');
    } finally {
      isSaving.value = false;
    }
  }

  /// Refresca el `FloorPlansListController` si está vivo. Importante
  /// para que la lista de planos muestre el último estado (mesas
  /// agregadas/movidas/renombradas) sin que el operario tenga que
  /// volver a la lista y refrescar a mano.
  ///
  /// El selector de mesas en el flow de orden hace fetch propio, así
  /// que esto solo cubre la vista de listado de planos.
  void _refreshListIfRegistered() {
    if (Get.isRegistered<FloorPlansListController>()) {
      Get.find<FloorPlansListController>().loadFloorPlans();
    }
  }

  // ========== Command Pattern (Undo/Redo) ==========

  void executeCommand(FloorPlanCommand command) {
    if (currentFloorPlan.value == null) return;

    final newState = commandHistory.executeCommand(
      currentFloorPlan.value!,
      command,
    );
    currentFloorPlan.value = newState;
    historyVersion.value++; // Notificar cambio
  }

  void undo() {
    if (currentFloorPlan.value == null || !commandHistory.canUndo) return;

    final newState = commandHistory.undo(currentFloorPlan.value!);
    currentFloorPlan.value = newState;
    selectedElement.value = null;
    historyVersion.value++; // Notificar cambio
  }

  void redo() {
    if (currentFloorPlan.value == null || !commandHistory.canRedo) return;

    final newState = commandHistory.redo(currentFloorPlan.value!);
    currentFloorPlan.value = newState;
    historyVersion.value++; // Notificar cambio
  }

  // ========== Tool Management ==========

  void selectTool(EditorTool tool) {
    currentTool.value = tool;

    // Limpiar estado de dibujo al cambiar de herramienta
    if (tool != EditorTool.polygon) {
      currentPolygonPoints.clear();
      isDrawingPolygon.value = false;
    }
    if (tool != EditorTool.line) {
      currentLineStart.value = null;
      currentLineEnd.value = null;
    }
    if (tool != EditorTool.rectangle) {
      currentRectStart.value = null;
      currentRectEnd.value = null;
    }

    // Limpiar pre-elección de icono si cambiamos a otra herramienta de icono
    final stillSameIconTool = pendingIconType.value != null &&
        _iconToolFor(pendingIconType.value!) == tool;
    if (!stillSameIconTool) {
      pendingIconType.value = null;
      pendingIconChoice.value = null;
    }

    // Deseleccionar elemento al cambiar a herramientas de dibujo
    if (tool != EditorTool.select) {
      selectedElement.value = null;
    }
  }

  /// Guarda la elección del IconSelectorDialog hecha desde la toolbar para
  /// que el siguiente tap en el canvas coloque ese icono sin reabrir el dialog.
  void setPendingIconChoice(ElementType type, FloorPlanIconData icon) {
    pendingIconType.value = type;
    pendingIconChoice.value = icon;
  }

  EditorTool _iconToolFor(ElementType type) {
    switch (type) {
      case ElementType.bathroom:
        return EditorTool.bathroom;
      case ElementType.kitchen:
        return EditorTool.kitchen;
      case ElementType.door:
        return EditorTool.door;
      case ElementType.bar:
        return EditorTool.bar;
      case ElementType.plant:
        return EditorTool.plant;
      case ElementType.stairs:
        return EditorTool.stairs;
      case ElementType.table:
        return EditorTool.table;
      default:
        return EditorTool.select;
    }
  }

  // ========== Layer Management ==========

  void setActiveLayer(String layerId) {
    activeLayerId.value = layerId;
  }

  /// Crea una capa nueva (z-index = max + 1) y la deja como activa.
  void createLayer(String name) {
    if (currentFloorPlan.value == null) return;
    final fp = currentFloorPlan.value!;
    final maxZ = fp.layers.fold<int>(0, (max, l) => l.zIndex > max ? l.zIndex : max);
    final newLayer = FloorPlanLayer(
      id: _uuid.v4(),
      name: name,
      zIndex: maxZ + 1,
    );
    currentFloorPlan.value = fp.addLayer(newLayer);
    activeLayerId.value = newLayer.id;
  }

  /// Mueve un set de elementos por un delta (x,y). Sirve para arrastrar un
  /// "contenedor" (rectángulo/polígono) llevándose con él los elementos que
  /// están adentro. Cada elemento conserva su posición relativa al contenedor.
  void moveElementsByDelta(
    List<FloorPlanElement> elements,
    List<Offset> startPositions,
    Offset delta,
  ) {
    if (currentFloorPlan.value == null) return;
    if (elements.length != startPositions.length) return;

    var fp = currentFloorPlan.value!;
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      final newPos = startPositions[i] + delta;
      final snapped = snapToGrid.value ? _snapToGrid(newPos) : newPos;

      final layer = fp.getLayer(e.layerId);
      if (layer == null) continue;
      final updated = e.copyWith(position: snapped);
      fp = fp.updateLayer(layer.updateElement(updated));
    }
    currentFloorPlan.value = fp;
  }

  /// Devuelve los elementos cuyo centro/posición cae dentro del bounds dado,
  /// excluyendo el elemento contenedor mismo. Se usa para detectar "qué se
  /// mueve junto con un rectángulo cuando lo arrastrás".
  List<FloorPlanElement> elementsInside(Rect bounds, {String? excludeId}) {
    final fp = currentFloorPlan.value;
    if (fp == null) return const [];
    final result = <FloorPlanElement>[];
    for (final layer in fp.layers) {
      if (!layer.isVisible || layer.isLocked) continue;
      for (final e in layer.elements) {
        if (e.id == excludeId) continue;
        if (bounds.contains(e.position)) {
          result.add(e);
        }
      }
    }
    return result;
  }

  /// Mueve el elemento seleccionado a otra capa. Si la capa destino está
  /// bloqueada o no existe, no hace nada y avisa.
  void moveSelectedElementToLayer(String targetLayerId) {
    final element = selectedElement.value;
    if (element == null || currentFloorPlan.value == null) return;
    if (element.layerId == targetLayerId) return;

    final fp = currentFloorPlan.value!;
    final sourceLayer = fp.getLayer(element.layerId);
    final targetLayer = fp.getLayer(targetLayerId);

    if (sourceLayer == null || targetLayer == null) return;
    if (targetLayer.isLocked) {
      AppSnackbar.show(
        'Capa bloqueada',
        'Desbloqueá "${targetLayer.name}" antes de mover elementos.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final movedElement = element.copyWith(layerId: targetLayerId);
    final updatedSource = sourceLayer.removeElement(element.id);
    final updatedTarget = targetLayer.addElement(movedElement);

    currentFloorPlan.value =
        fp.updateLayer(updatedSource).updateLayer(updatedTarget);
    selectedElement.value = movedElement;
  }

  void toggleLayerVisibility(String layerId) {
    if (currentFloorPlan.value == null) return;

    final layer = currentFloorPlan.value!.getLayer(layerId);
    if (layer == null) return;

    final updatedLayer = layer.copyWith(isVisible: !layer.isVisible);
    currentFloorPlan.value = currentFloorPlan.value!.updateLayer(updatedLayer);
  }

  void toggleLayerLock(String layerId) {
    if (currentFloorPlan.value == null) return;

    final layer = currentFloorPlan.value!.getLayer(layerId);
    if (layer == null) return;

    final updatedLayer = layer.copyWith(isLocked: !layer.isLocked);
    currentFloorPlan.value = currentFloorPlan.value!.updateLayer(updatedLayer);
  }

  // ========== Element Operations ==========

  void addElement(FloorPlanElement element) {
    // Resolver la capa target según el TIPO de elemento, no la capa activa.
    // Cada categoría va a su propia capa para que el usuario pueda ocultar
    // (p.ej.) "Mesas" sin que desaparezcan las paredes o los baños.
    // Si no existe esa capa la creamos al vuelo.
    final targetLayerId = _resolveLayerForElement(element);
    final placedElement = element.copyWith(layerId: targetLayerId);
    final command = AddElementCommand(targetLayerId, placedElement);
    executeCommand(command);
  }

  /// Devuelve el id de la capa donde debe vivir un elemento de este tipo.
  /// Si la capa "canónica" no existe todavía, la crea (con un z-index
  /// estable que respeta la jerarquía visual: estructura abajo, anotaciones
  /// arriba). Esto evita que todo termine en una sola capa "Paredes".
  String _resolveLayerForElement(FloorPlanElement element) {
    final spec = _layerSpecFor(element);
    final fp = currentFloorPlan.value!;

    // ¿Ya existe la capa por nombre?
    for (final layer in fp.layers) {
      if (layer.name.toLowerCase() == spec.name.toLowerCase()) {
        return layer.id;
      }
    }

    // No existe → la creamos con un z-index "preferido" según la categoría.
    final newLayer = FloorPlanLayer(
      id: _uuid.v4(),
      name: spec.name,
      zIndex: spec.zIndex,
    );
    currentFloorPlan.value = fp.addLayer(newLayer);
    return newLayer.id;
  }

  _LayerSpec _layerSpecFor(FloorPlanElement element) {
    // z-index alineados con StandardLayers para que la jerarquía visual
    // sea coherente: paredes/marco abajo, servicios y puertas arriba,
    // mobiliario encima, decoración y anotaciones al frente.
    if (element is IconElement) {
      switch (element.type) {
        case ElementType.table:
          return const _LayerSpec('Mesas', 4);
        case ElementType.bathroom:
          return const _LayerSpec('Baños', 2);
        case ElementType.kitchen:
          return const _LayerSpec('Cocina', 2);
        case ElementType.bar:
          return const _LayerSpec('Bar', 2);
        case ElementType.door:
          return const _LayerSpec('Puertas', 2);
        case ElementType.plant:
          return const _LayerSpec('Decoración', 5);
        case ElementType.stairs:
          return const _LayerSpec('Escaleras', 2);
        default:
          return const _LayerSpec('Otros', 3);
      }
    }
    if (element is RectangleElement ||
        element is LineElement ||
        element is PolygonElement) {
      // Marco/paredes SIEMPRE abajo de todo lo demás.
      return const _LayerSpec('Paredes', 1);
    }
    if (element is TextElement) {
      return const _LayerSpec('Anotaciones', 6);
    }
    return const _LayerSpec('General', 3);
  }

  void deleteSelectedElement() {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final command = DeleteElementCommand(element.layerId, element);
    executeCommand(command);
    selectedElement.value = null;
  }

  void selectElementAtPosition(Offset position) {
    if (currentFloorPlan.value == null) return;

    final element = currentFloorPlan.value!.findElementAtPosition(position);
    selectedElement.value = element;

    // Si se seleccionó un elemento, cambiar automáticamente a la herramienta de selección
    if (element != null && currentTool.value != EditorTool.select) {
      currentTool.value = EditorTool.select;
    }
  }

  void moveSelectedElement(Offset newPosition) {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final snappedPosition = snapToGrid.value
        ? _snapToGrid(newPosition)
        : newPosition;

    final command = MoveElementCommand(
      element.layerId,
      element.id,
      element.position,
      snappedPosition,
    );
    executeCommand(command);

    // Actualizar elemento seleccionado
    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer != null) {
      selectedElement.value = layer.getElement(element.id);
    }
  }

  void rotateSelectedElement(double newRotation) {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final command = RotateElementCommand(
      element.layerId,
      element.id,
      element.rotation,
      newRotation,
    );
    executeCommand(command);

    // Actualizar elemento seleccionado
    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer != null) {
      selectedElement.value = layer.getElement(element.id);
    }
  }

  // ========== Polygon Drawing ==========

  void startPolygon() {
    isDrawingPolygon.value = true;
    currentPolygonPoints.clear();
  }

  void addPolygonPoint(Offset point) {
    final snappedPoint = snapToGrid.value ? _snapToGrid(point) : point;
    currentPolygonPoints.add(snappedPoint);
  }

  void finishPolygon({
    Color fillColor = Colors.transparent,
    Color strokeColor = Colors.black,
    double strokeWidth = 2.0,
    String? name,
  }) {
    if (currentPolygonPoints.length < 3) {
      AppSnackbar.show('Error', 'Un polígono debe tener al menos 3 puntos');
      return;
    }

    final polygon = PolygonElement(
      id: _uuid.v4(),
      layerId: activeLayerId.value,
      position: Offset.zero,
      points: List.from(currentPolygonPoints),
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      name: name,
    );

    addElement(polygon);

    // Limpiar estado
    currentPolygonPoints.clear();
    isDrawingPolygon.value = false;
  }

  void cancelPolygon() {
    currentPolygonPoints.clear();
    isDrawingPolygon.value = false;
  }

  // ========== Line Drawing ==========

  void startLinePreview(Offset start) {
    currentLineStart.value = snapToGrid.value ? _snapToGrid(start) : start;
    currentLineEnd.value = currentLineStart.value;
  }

  void updateLinePreview(Offset end) {
    if (currentLineStart.value != null) {
      currentLineEnd.value = snapToGrid.value ? _snapToGrid(end) : end;
    }
  }

  void addLine(Offset start, Offset end) {
    final snappedStart = snapToGrid.value ? _snapToGrid(start) : start;
    final snappedEnd = snapToGrid.value ? _snapToGrid(end) : end;

    final line = LineElement(
      id: _uuid.v4(),
      layerId: activeLayerId.value,
      position: Offset.zero,
      start: snappedStart,
      end: snappedEnd,
      color: Colors.black,
      strokeWidth: 4.0,
    );

    addElement(line);

    // Limpiar preview
    currentLineStart.value = null;
    currentLineEnd.value = null;
  }

  // ========== Rectangle Drawing ==========

  void startRectanglePreview(Offset start) {
    currentRectStart.value = snapToGrid.value ? _snapToGrid(start) : start;
    currentRectEnd.value = currentRectStart.value;
  }

  void updateRectanglePreview(Offset end) {
    if (currentRectStart.value != null) {
      currentRectEnd.value = snapToGrid.value ? _snapToGrid(end) : end;
    }
  }

  void addRectangle(Offset topLeft, Offset bottomRight) {
    final snappedTopLeft = snapToGrid.value ? _snapToGrid(topLeft) : topLeft;
    final snappedBottomRight = snapToGrid.value ? _snapToGrid(bottomRight) : bottomRight;

    final width = (snappedBottomRight.dx - snappedTopLeft.dx).abs();
    final height = (snappedBottomRight.dy - snappedTopLeft.dy).abs();

    if (width < 10 || height < 10) {
      AppSnackbar.show('Error', 'El rectángulo es demasiado pequeño');
      // Limpiar preview
      currentRectStart.value = null;
      currentRectEnd.value = null;
      return;
    }

    // Rectángulo como marco/contorno: sin fill (transparente) para que la
    // cuadrícula y los elementos debajo sigan visibles. Solo borde marcado.
    final rectangle = RectangleElement(
      id: _uuid.v4(),
      layerId: activeLayerId.value,
      position: snappedTopLeft,
      width: width,
      height: height,
      fillColor: Colors.transparent,
      strokeColor: const Color(0xFF3F51B5),
      strokeWidth: 2.5,
    );

    addElement(rectangle);

    // Limpiar preview
    currentRectStart.value = null;
    currentRectEnd.value = null;
  }

  // ========== Text Adding ==========

  void addText(Offset position, String text) {
    if (text.trim().isEmpty) {
      AppSnackbar.show('Error', 'El texto no puede estar vacío');
      return;
    }

    final snappedPosition = snapToGrid.value ? _snapToGrid(position) : position;

    final textElement = TextElement(
      id: _uuid.v4(),
      layerId: activeLayerId.value,
      position: snappedPosition,
      text: text,
      fontSize: 16.0,
      color: Colors.black,
    );

    addElement(textElement);
  }

  // ========== Icon Dragging ==========

  void startIconDrag(ElementType type) {
    draggingIconType.value = type;
    draggingIconPosition.value = null;
  }

  void updateIconDragPosition(Offset position) {
    if (draggingIconType.value != null) {
      final snappedPosition = snapToGrid.value ? _snapToGrid(position) : position;
      draggingIconPosition.value = snappedPosition;
    }
  }

  void finishIconDrag(Offset position) {
    if (draggingIconType.value != null) {
      addIconElement(position, draggingIconType.value!);
      draggingIconType.value = null;
      draggingIconPosition.value = null;
    }
  }

  void cancelIconDrag() {
    draggingIconType.value = null;
    draggingIconPosition.value = null;
  }

  // ========== Icon Elements ==========

  void addIconElement(Offset position, ElementType type) {
    final snappedPosition = snapToGrid.value ? _snapToGrid(position) : position;

    // Si es una mesa, mostrar diálogo de selección
    if (type == ElementType.table) {
      showTableSelector(snappedPosition);
      return;
    }

    // Si es un tipo que tiene múltiples opciones, mostrar diálogo de selección
    if (_hasIconOptions(type)) {
      _showIconSelector(snappedPosition, type);
      return;
    }

    // Para elementos que no tienen opciones, usar el icono por defecto
    IconData icon;
    String label;

    switch (type) {
      case ElementType.stairs:
        icon = Icons.stairs;
        label = 'Escaleras';
        break;
      default:
        AppSnackbar.show('Error', 'Tipo de ícono no soportado');
        return;
    }

    final iconElement = IconElement(
      id: _uuid.v4(),
      type: type,
      layerId: activeLayerId.value,
      position: snappedPosition,
      icon: icon,
      size: 48.0,
      color: Colors.blueGrey,
      label: label,
    );

    addElement(iconElement);
  }

  /// Verifica si un tipo de elemento tiene múltiples opciones de iconos
  bool _hasIconOptions(ElementType type) {
    return type == ElementType.kitchen ||
           type == ElementType.plant ||
           type == ElementType.door ||
           type == ElementType.bar ||
           type == ElementType.bathroom;
  }

  /// Muestra el diálogo de selección de iconos según la categoría.
  /// Si la toolbar ya pre-eligió un icono para este tipo
  /// (`pendingIconChoice`), lo usa directamente y MANTIENE la pre-elección
  /// para que el usuario pueda colocar varios consecutivos del mismo tipo.
  /// Cancelar/cambiar tool/ESC limpia la elección.
  Future<void> _showIconSelector(Offset position, ElementType type) async {
    if (pendingIconType.value == type && pendingIconChoice.value != null) {
      _createIconElement(position, type, pendingIconChoice.value!);
      return;
    }

    String category;

    switch (type) {
      case ElementType.kitchen:
        category = 'kitchen';
        break;
      case ElementType.plant:
        category = 'decoration';
        break;
      case ElementType.door:
        category = 'door';
        break;
      case ElementType.bar:
        category = 'bar';
        break;
      case ElementType.bathroom:
        category = 'bathroom';
        break;
      default:
        return;
    }

    final selectedIcon = await Get.dialog<FloorPlanIconData>(
      IconSelectorDialog(category: category),
    );

    if (selectedIcon != null) {
      _createIconElement(position, type, selectedIcon);
    }
  }

  /// Crea un elemento de icono con el icono seleccionado y lo deja
  /// auto-seleccionado para que el usuario pueda moverlo, rotarlo o
  /// redimensionarlo de inmediato.
  void _createIconElement(Offset position, ElementType type, FloorPlanIconData iconData) {
    final iconElement = IconElement(
      id: _uuid.v4(),
      type: type,
      layerId: activeLayerId.value,
      position: position,
      icon: iconData.icon,
      size: 48.0,
      color: Colors.blueGrey,
      label: iconData.displayName,
      metadata: {
        'iconCategory': iconData.category,
        'iconSubType': iconData.subType,
      },
    );

    addElement(iconElement);
    selectedElement.value = iconElement;
  }

  /// Cancela la elección de icono pendiente (botón ✕ del banner o ESC).
  void cancelPendingIconChoice() {
    pendingIconType.value = null;
    pendingIconChoice.value = null;
    pendingTableCapacity.value = null;
  }

  /// Pre-carga una mesa con su capacidad para colocarla con un tap. Genera
  /// también un FloorPlanIconData "sintético" para que el banner muestre
  /// "Toca el plano para colocar Mesa de N personas".
  void setPendingTablePlacement(TableCapacity capacity) {
    pendingTableCapacity.value = capacity;
    pendingIconType.value = ElementType.table;
    pendingIconChoice.value = FloorPlanIconData(
      category: 'table',
      subType: capacity.name,
      icon: Icons.table_restaurant,
      displayName: 'Mesa para ${capacity.seats} personas',
    );
  }

  /// Pre-carga una escalera (sin dialog porque no tiene variantes) para que
  /// se aplique el flujo unificado del banner.
  void setPendingStairsPlacement() {
    pendingIconType.value = ElementType.stairs;
    pendingIconChoice.value = FloorPlanIconData(
      category: 'stairs',
      subType: 'default',
      icon: Icons.stairs,
      displayName: 'Escalera',
    );
  }

  /// Coloca la mesa pre-elegida en `position` (llamado desde el canvas).
  void placePendingTable(Offset position) {
    final capacity = pendingTableCapacity.value;
    if (capacity == null) return;
    final snapped = snapToGrid.value ? _snapToGrid(position) : position;
    _createTableElement(snapped, capacity);
  }

  // ========== Table Selection ==========

  /// Muestra el diálogo para seleccionar el tipo de mesa
  Future<void> showTableSelector(Offset position) async {
    final capacity = await Get.dialog<TableCapacity>(
      const TableSelectorDialog(),
    );

    if (capacity != null) {
      _createTableElement(position, capacity);
    }
  }

  /// Crea un elemento de mesa con la capacidad especificada
  void _createTableElement(Offset position, TableCapacity capacity) {
    // Obtener el siguiente número de mesa
    final tableNumber = _getNextTableNumber();

    final iconElement = IconElement(
      id: _uuid.v4(),
      type: ElementType.table,
      layerId: activeLayerId.value,
      position: position,
      icon: Icons.table_restaurant,
      size: 48.0,
      color: Colors.brown,
      label: '$tableNumber', // Solo el número de la mesa
      metadata: {
        'tableCapacity': capacity.name, // Guardar como 'two', 'four', etc.
      },
    );

    addElement(iconElement);
  }

  /// Obtiene el siguiente número de mesa disponible
  int _getNextTableNumber() {
    if (currentFloorPlan.value == null) return 1;

    // Obtener todos los elementos de todas las capas
    final allTables = <FloorPlanElement>[];
    for (final layer in currentFloorPlan.value!.layers) {
      allTables.addAll(layer.elements.where((e) => e.type == ElementType.table));
    }

    // Si no hay mesas, empezar en 1
    if (allTables.isEmpty) return 1;

    // Buscar el número más alto y sumar 1
    int maxNumber = 0;
    for (var table in allTables) {
      if (table is IconElement && table.label != null) {
        // Intentar extraer el número del label
        final number = int.tryParse(table.label!);
        if (number != null && number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    return maxNumber + 1;
  }

  // ========== Canvas Transformations ==========

  void setZoom(double zoom) {
    zoomLevel.value = zoom.clamp(0.1, 5.0);
  }

  void zoomIn() {
    zoomLevel.value = (zoomLevel.value * 1.2).clamp(0.1, 5.0);
  }

  void zoomOut() {
    zoomLevel.value = (zoomLevel.value / 1.2).clamp(0.1, 5.0);
  }

  void resetZoom() {
    zoomLevel.value = 1.0;
    panOffset.value = Offset.zero;
  }

  void setPan(Offset offset) {
    panOffset.value = offset;
  }

  /// Calcula el zoom y pan inicial para mostrar el contenido centrado
  /// Acepta las dimensiones reales del canvas disponible
  void calculateInitialViewport(double canvasWidth, double canvasHeight) {
    final floorPlan = currentFloorPlan.value;
    if (floorPlan == null) return;

    // Solo calcular si:
    // 1. No se ha inicializado antes, O
    // 2. Las dimensiones del canvas cambiaron significativamente (más de 50px)
    if (_viewportInitialized &&
        (canvasWidth - _lastCanvasWidth).abs() < 50 &&
        (canvasHeight - _lastCanvasHeight).abs() < 50) {
      return;
    }

    // Guardar las dimensiones actuales
    _lastCanvasWidth = canvasWidth;
    _lastCanvasHeight = canvasHeight;

    // Ajustar grid size basado en el ancho del canvas (responsivo)
    _adjustGridSize(canvasWidth);

    // Calcular los bounds del contenido real
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final layer in floorPlan.layers) {
      if (!layer.isVisible) continue;
      for (final element in layer.elements) {
        if (!element.isVisible) continue;
        final bounds = element.getBounds();
        if (bounds.left < minX) minX = bounds.left;
        if (bounds.top < minY) minY = bounds.top;
        if (bounds.right > maxX) maxX = bounds.right;
        if (bounds.bottom > maxY) maxY = bounds.bottom;
      }
    }

    // Si no hay elementos, usar el canvas completo
    if (minX == double.infinity) {
      zoomLevel.value = 1.0;
      panOffset.value = Offset.zero;
      _viewportInitialized = true;
      return;
    }

    // Agregar padding alrededor del contenido
    // Menos padding en pantallas pequeñas para aprovechar mejor el espacio
    final padding = canvasWidth < 600 ? 40.0 : 80.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    // Dimensiones del contenido real
    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;

    // Calcular zoom para que el contenido quepa en el canvas disponible
    final scaleX = canvasWidth / contentWidth;
    final scaleY = canvasHeight / contentHeight;
    var calculatedZoom = (scaleX < scaleY ? scaleX : scaleY);

    // En pantallas pequeñas (móviles), usar el 95% del espacio para máximo aprovechamiento
    // En pantallas grandes, usar el 85% para dejar más aire
    if (canvasWidth < 600) {
      calculatedZoom *= 0.95; // 95% del espacio en móviles
    } else if (canvasWidth < 1024) {
      calculatedZoom *= 0.90; // 90% en tablets
    } else {
      calculatedZoom *= 0.85; // 85% en desktop
    }

    // Aplicar zoom (limitado entre 0.1 y 5.0)
    zoomLevel.value = calculatedZoom.clamp(0.1, 5.0);

    // Calcular pan para centrar el contenido
    final scaledContentWidth = contentWidth * zoomLevel.value;
    final scaledContentHeight = contentHeight * zoomLevel.value;

    final panX = (canvasWidth - scaledContentWidth) / 2 - (minX * zoomLevel.value);
    final panY = (canvasHeight - scaledContentHeight) / 2 - (minY * zoomLevel.value);

    panOffset.value = Offset(panX, panY);

    // Marcar como inicializado
    _viewportInitialized = true;
  }

  // ========== Grid ==========

  void toggleGrid() {
    showGrid.value = !showGrid.value;
  }

  void toggleSnapToGrid() {
    snapToGrid.value = !snapToGrid.value;
  }

  /// Ajusta el tamaño del grid basado en el ancho del canvas (responsivo)
  void _adjustGridSize(double canvasWidth) {
    // Calcular grid size óptimo basado en tamaño de pantalla
    // Móviles pequeños: 10px, Tablets: 15px, Desktop: 20px
    double optimalGridSize;

    if (canvasWidth < 400) {
      optimalGridSize = 10.0; // Móviles muy pequeños
    } else if (canvasWidth < 600) {
      optimalGridSize = 12.0; // Móviles normales
    } else if (canvasWidth < 900) {
      optimalGridSize = 15.0; // Tablets
    } else if (canvasWidth < 1200) {
      optimalGridSize = 18.0; // Tablets grandes / Desktop pequeño
    } else {
      optimalGridSize = 20.0; // Desktop
    }

    // Solo actualizar si cambió significativamente
    if ((gridSize.value - optimalGridSize).abs() > 1.0) {
      gridSize.value = optimalGridSize;
    }
  }

  Offset _snapToGrid(Offset position) {
    final size = gridSize.value;
    return Offset(
      (position.dx / size).round() * size,
      (position.dy / size).round() * size,
    );
  }

  // ========== Resize Operations ==========

  /// Detecta si un punto está sobre el handle de rotación O su línea conectora
  /// Usa detección circular REAL y detección de línea para máxima facilidad de uso
  bool detectRotationHandle(Offset point, FloorPlanElement element) {
    if (element is LineElement) return false; // No rotar líneas

    // Tamaños responsivos al zoom - más grandes cuando hay zoom out
    final clickRadius = 40.0 / zoomLevel.value.clamp(0.5, 2.0); // Radio de detección del círculo
    final lineClickDistance = 20.0 / zoomLevel.value.clamp(0.5, 2.0); // Distancia de click a la línea
    final rotationHandleDistance = 40.0; // Distancia desde el elemento (no escalada)

    // Para IconElement, calcular la posición del handle considerando la rotación
    if (element is IconElement) {
      final elementCenter = element.position;
      final elementSize = element.size;

      // El handle está arriba del elemento (en coordenadas locales: 0, -size/2 - distance)
      // Necesitamos rotar este offset según la rotación del elemento
      final localHandleOffset = Offset(0, -elementSize / 2 - rotationHandleDistance);

      // Aplicar rotación
      final cos = math.cos(element.rotation);
      final sin = math.sin(element.rotation);
      final rotatedOffset = Offset(
        localHandleOffset.dx * cos - localHandleOffset.dy * sin,
        localHandleOffset.dx * sin + localHandleOffset.dy * cos,
      );

      // Posición global del handle
      final rotationHandlePosition = elementCenter + rotatedOffset;

      // DETECCIÓN 1: Círculo del handle (más fácil)
      final distanceToHandle = (point - rotationHandlePosition).distance;
      if (distanceToHandle <= clickRadius) {
        return true;
      }

      // DETECCIÓN 2: Línea conectora (también válida para hacer click)
      // Calcular punto donde la línea se conecta al elemento
      final localConnectionPoint = Offset(0, -elementSize / 2);
      final rotatedConnectionPoint = Offset(
        localConnectionPoint.dx * cos - localConnectionPoint.dy * sin,
        localConnectionPoint.dx * sin + localConnectionPoint.dy * cos,
      );
      final connectionPoint = elementCenter + rotatedConnectionPoint;

      // Verificar si el punto está cerca de la línea entre connectionPoint y rotationHandlePosition
      final lineStart = connectionPoint;
      final lineEnd = rotationHandlePosition;
      final lineLength = (lineEnd - lineStart).distance;

      if (lineLength == 0) return false;

      // Proyectar el punto sobre la línea
      final t = ((point - lineStart).dx * (lineEnd - lineStart).dx +
                 (point - lineStart).dy * (lineEnd - lineStart).dy) /
                (lineLength * lineLength);

      // Verificar que está dentro del segmento (no más allá de los extremos)
      if (t >= 0 && t <= 1) {
        final projection = lineStart + (lineEnd - lineStart) * t;
        final distanceToLine = (point - projection).distance;

        if (distanceToLine <= lineClickDistance) {
          return true;
        }
      }

      return false;
    }

    // Para otros tipos de elementos, usar bounds
    final bounds = element.getBounds();
    final rotationHandlePosition = Offset(
      bounds.center.dx,
      bounds.top - rotationHandleDistance,
    );

    // DETECCIÓN CIRCULAR REAL
    final distance = (point - rotationHandlePosition).distance;
    return distance <= clickRadius;
  }

  /// Detecta si un punto está sobre un handle de redimensionamiento
  /// Usa detección circular REAL para mayor precisión
  ResizeHandle? detectResizeHandle(Offset point, FloorPlanElement element) {
    // Tamaños responsivos al zoom - más grandes cuando hay zoom out
    final clickRadius = 18.0 / zoomLevel.value.clamp(0.5, 2.0); // Radio de detección

    // Para IconElement (mesas), usar coordenadas considerando rotación
    if (element is IconElement) {
      final elementCenter = element.position;
      final elementSize = element.size;
      final rotation = element.rotation;

      // Definir posiciones locales de los handles
      final localHandlePositions = {
        ResizeHandle.topLeft: Offset(-elementSize / 2, -elementSize / 2),
        ResizeHandle.topCenter: Offset(0, -elementSize / 2),
        ResizeHandle.topRight: Offset(elementSize / 2, -elementSize / 2),
        ResizeHandle.centerRight: Offset(elementSize / 2, 0),
        ResizeHandle.bottomRight: Offset(elementSize / 2, elementSize / 2),
        ResizeHandle.bottomCenter: Offset(0, elementSize / 2),
        ResizeHandle.bottomLeft: Offset(-elementSize / 2, elementSize / 2),
        ResizeHandle.centerLeft: Offset(-elementSize / 2, 0),
      };

      // Aplicar rotación a cada handle y detectar con CÍRCULO REAL
      final cos = math.cos(rotation);
      final sin = math.sin(rotation);

      for (final entry in localHandlePositions.entries) {
        final local = entry.value;
        final rotated = Offset(
          local.dx * cos - local.dy * sin,
          local.dx * sin + local.dy * cos,
        );
        final globalPos = elementCenter + rotated;

        // DETECCIÓN CIRCULAR REAL
        final distance = (point - globalPos).distance;
        if (distance <= clickRadius) {
          return entry.key;
        }
      }
      return null;
    }

    // Para otros elementos, usar bounds con detección circular
    final bounds = element.getBounds();

    // Para LineElement, solo detectar handles en los extremos
    if (element is LineElement) {
      final handles = {
        ResizeHandle.topLeft: bounds.topLeft,
        ResizeHandle.bottomRight: bounds.bottomRight,
      };

      for (final entry in handles.entries) {
        // DETECCIÓN CIRCULAR REAL
        final distance = (point - entry.value).distance;
        if (distance <= clickRadius) {
          return entry.key;
        }
      }
      return null;
    }

    // Para todos los demás elementos, detectar todos los handles
    final handles = {
      ResizeHandle.topLeft: bounds.topLeft,
      ResizeHandle.topCenter: bounds.topCenter,
      ResizeHandle.topRight: bounds.topRight,
      ResizeHandle.centerRight: bounds.centerRight,
      ResizeHandle.bottomRight: bounds.bottomRight,
      ResizeHandle.bottomCenter: bounds.bottomCenter,
      ResizeHandle.bottomLeft: bounds.bottomLeft,
      ResizeHandle.centerLeft: bounds.centerLeft,
    };

    for (final entry in handles.entries) {
      // DETECCIÓN CIRCULAR REAL
      final distance = (point - entry.value).distance;
      if (distance <= clickRadius) {
        return entry.key;
      }
    }

    return null;
  }

  /// Inicia el redimensionamiento de un elemento
  void startResize(ResizeHandle handle) {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;

    isResizingElement.value = true;
    activeResizeHandle.value = handle;
    _resizeStartPosition = null;

    // Guardar el estado inicial según el tipo de elemento
    if (element is IconElement) {
      _initialResizeState = {'size': element.size};
    } else if (element is RectangleElement) {
      _initialResizeState = {
        'width': element.width,
        'height': element.height,
        'position': element.position,
      };
    } else if (element is PolygonElement) {
      _initialResizeState = {
        'points': List<Offset>.from(element.points),
        'bounds': element.getBounds(),
      };
    } else if (element is LineElement) {
      _initialResizeState = {
        'start': element.start,
        'end': element.end,
      };
    } else if (element is TextElement) {
      _initialResizeState = {'fontSize': element.fontSize};
    }
  }

  /// Actualiza el redimensionamiento en tiempo real
  void updateResize(Offset currentPosition) {
    if (!isResizingElement.value ||
        activeResizeHandle.value == null ||
        selectedElement.value == null ||
        _initialResizeState == null) {
      return;
    }

    final element = selectedElement.value!;

    if (_resizeStartPosition == null) {
      _resizeStartPosition = currentPosition;
      return;
    }

    final delta = currentPosition - _resizeStartPosition!;
    final handle = activeResizeHandle.value!;

    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer == null) return;

    FloorPlanElement? updatedElement;

    // Manejar cada tipo de elemento
    if (element is IconElement) {
      updatedElement = _updateIconResize(element, delta, handle);
    } else if (element is RectangleElement) {
      updatedElement = _updateRectangleResize(element, delta, handle);
    } else if (element is PolygonElement) {
      updatedElement = _updatePolygonResize(element, delta, handle);
    } else if (element is LineElement) {
      updatedElement = _updateLineResize(element, delta, handle);
    } else if (element is TextElement) {
      updatedElement = _updateTextResize(element, delta, handle);
    }

    if (updatedElement != null) {
      final updatedLayer = layer.updateElement(updatedElement);
      currentFloorPlan.value = currentFloorPlan.value!.updateLayer(updatedLayer);
      selectedElement.value = updatedElement;
    }
  }

  IconElement _updateIconResize(IconElement element, Offset delta, ResizeHandle handle) {
    final initialSize = _initialResizeState!['size'] as double;
    double newSize = initialSize;

    switch (handle) {
      case ResizeHandle.topLeft:
      case ResizeHandle.bottomLeft:
        newSize = initialSize - delta.dx * 2;
        break;
      case ResizeHandle.topRight:
      case ResizeHandle.bottomRight:
        newSize = initialSize + delta.dx * 2;
        break;
      case ResizeHandle.topCenter:
        newSize = initialSize - delta.dy * 2;
        break;
      case ResizeHandle.bottomCenter:
        newSize = initialSize + delta.dy * 2;
        break;
      case ResizeHandle.centerLeft:
        newSize = initialSize - delta.dx * 2;
        break;
      case ResizeHandle.centerRight:
        newSize = initialSize + delta.dx * 2;
        break;
    }

    newSize = newSize.clamp(20.0, 200.0);
    return element.copyWith(size: newSize);
  }

  RectangleElement _updateRectangleResize(RectangleElement element, Offset delta, ResizeHandle handle) {
    final initialWidth = _initialResizeState!['width'] as double;
    final initialHeight = _initialResizeState!['height'] as double;
    final initialPosition = _initialResizeState!['position'] as Offset;

    double newWidth = initialWidth;
    double newHeight = initialHeight;
    Offset newPosition = initialPosition;

    switch (handle) {
      case ResizeHandle.topLeft:
        newWidth = initialWidth - delta.dx;
        newHeight = initialHeight - delta.dy;
        newPosition = Offset(initialPosition.dx + delta.dx, initialPosition.dy + delta.dy);
        break;
      case ResizeHandle.topCenter:
        newHeight = initialHeight - delta.dy;
        newPosition = Offset(initialPosition.dx, initialPosition.dy + delta.dy);
        break;
      case ResizeHandle.topRight:
        newWidth = initialWidth + delta.dx;
        newHeight = initialHeight - delta.dy;
        newPosition = Offset(initialPosition.dx, initialPosition.dy + delta.dy);
        break;
      case ResizeHandle.centerRight:
        newWidth = initialWidth + delta.dx;
        break;
      case ResizeHandle.bottomRight:
        newWidth = initialWidth + delta.dx;
        newHeight = initialHeight + delta.dy;
        break;
      case ResizeHandle.bottomCenter:
        newHeight = initialHeight + delta.dy;
        break;
      case ResizeHandle.bottomLeft:
        newWidth = initialWidth - delta.dx;
        newHeight = initialHeight + delta.dy;
        newPosition = Offset(initialPosition.dx + delta.dx, initialPosition.dy);
        break;
      case ResizeHandle.centerLeft:
        newWidth = initialWidth - delta.dx;
        newPosition = Offset(initialPosition.dx + delta.dx, initialPosition.dy);
        break;
    }

    newWidth = newWidth.clamp(10.0, 1000.0);
    newHeight = newHeight.clamp(10.0, 1000.0);

    return element.copyWith(
      width: newWidth,
      height: newHeight,
      position: newPosition,
    );
  }

  PolygonElement _updatePolygonResize(PolygonElement element, Offset delta, ResizeHandle handle) {
    final initialPoints = _initialResizeState!['points'] as List<Offset>;
    final initialBounds = _initialResizeState!['bounds'] as Rect;

    if (initialPoints.isEmpty) return element;

    final center = initialBounds.center;

    // Calcular el factor de escala basado en el handle arrastrado
    double scaleX = 1.0;
    double scaleY = 1.0;

    switch (handle) {
      case ResizeHandle.topLeft:
      case ResizeHandle.bottomLeft:
      case ResizeHandle.centerLeft:
        scaleX = (initialBounds.width - delta.dx * 2) / initialBounds.width;
        scaleY = scaleX;
        break;
      case ResizeHandle.topRight:
      case ResizeHandle.bottomRight:
      case ResizeHandle.centerRight:
        scaleX = (initialBounds.width + delta.dx * 2) / initialBounds.width;
        scaleY = scaleX;
        break;
      case ResizeHandle.topCenter:
        scaleY = (initialBounds.height - delta.dy * 2) / initialBounds.height;
        scaleX = scaleY;
        break;
      case ResizeHandle.bottomCenter:
        scaleY = (initialBounds.height + delta.dy * 2) / initialBounds.height;
        scaleX = scaleY;
        break;
    }

    // Limitar escala mínima y máxima
    scaleX = scaleX.clamp(0.1, 5.0);
    scaleY = scaleY.clamp(0.1, 5.0);

    // Escalar todos los puntos desde el centro
    final relativeCenter = center - element.position;
    final scaledPoints = initialPoints.map((point) {
      final relative = point - relativeCenter;
      return relativeCenter + Offset(relative.dx * scaleX, relative.dy * scaleY);
    }).toList();

    return element.copyWith(points: scaledPoints);
  }

  LineElement _updateLineResize(LineElement element, Offset delta, ResizeHandle handle) {
    final initialStart = _initialResizeState!['start'] as Offset;
    final initialEnd = _initialResizeState!['end'] as Offset;

    Offset newStart = initialStart;
    Offset newEnd = initialEnd;

    // Solo permitir mover los extremos de la línea
    if (handle == ResizeHandle.topLeft) {
      newStart = initialStart + delta;
    } else if (handle == ResizeHandle.bottomRight) {
      newEnd = initialEnd + delta;
    }

    return element.copyWith(start: newStart, end: newEnd);
  }

  TextElement _updateTextResize(TextElement element, Offset delta, ResizeHandle handle) {
    final initialFontSize = _initialResizeState!['fontSize'] as double;
    double newFontSize = initialFontSize;

    // Aumentar/disminuir tamaño de fuente basado en el movimiento
    switch (handle) {
      case ResizeHandle.topLeft:
      case ResizeHandle.bottomLeft:
      case ResizeHandle.centerLeft:
        newFontSize = initialFontSize - delta.dx * 0.2;
        break;
      case ResizeHandle.topRight:
      case ResizeHandle.bottomRight:
      case ResizeHandle.centerRight:
        newFontSize = initialFontSize + delta.dx * 0.2;
        break;
      case ResizeHandle.topCenter:
        newFontSize = initialFontSize - delta.dy * 0.2;
        break;
      case ResizeHandle.bottomCenter:
        newFontSize = initialFontSize + delta.dy * 0.2;
        break;
    }

    newFontSize = newFontSize.clamp(8.0, 120.0);
    return element.copyWith(fontSize: newFontSize);
  }

  /// Finaliza el redimensionamiento y crea el comando para undo/redo
  void finishResize() {
    if (!isResizingElement.value ||
        selectedElement.value == null ||
        _initialResizeState == null) {
      _cleanupResize();
      return;
    }

    final element = selectedElement.value!;
    FloorPlanCommand? command;

    // Crear el comando apropiado según el tipo de elemento
    if (element is IconElement) {
      final initialSize = _initialResizeState!['size'] as double;
      final finalSize = element.size;
      if ((initialSize - finalSize).abs() > 0.1) {
        command = ResizeIconCommand(
          element.layerId,
          element.id,
          initialSize,
          finalSize,
        );
      }
    } else if (element is RectangleElement) {
      final initialWidth = _initialResizeState!['width'] as double;
      final initialHeight = _initialResizeState!['height'] as double;
      final finalWidth = element.width;
      final finalHeight = element.height;
      if ((initialWidth - finalWidth).abs() > 0.1 || (initialHeight - finalHeight).abs() > 0.1) {
        command = ResizeRectangleCommand(
          element.layerId,
          element.id,
          initialWidth,
          initialHeight,
          finalWidth,
          finalHeight,
        );
      }
    } else if (element is PolygonElement) {
      final initialPoints = _initialResizeState!['points'] as List<Offset>;
      final finalPoints = element.points;
      // Verificar si los puntos cambiaron
      bool changed = false;
      if (initialPoints.length != finalPoints.length) {
        changed = true;
      } else {
        for (int i = 0; i < initialPoints.length; i++) {
          if ((initialPoints[i] - finalPoints[i]).distance > 0.1) {
            changed = true;
            break;
          }
        }
      }
      if (changed) {
        command = ResizePolygonCommand(
          element.layerId,
          element.id,
          initialPoints,
          finalPoints,
        );
      }
    } else if (element is LineElement) {
      final initialStart = _initialResizeState!['start'] as Offset;
      final initialEnd = _initialResizeState!['end'] as Offset;
      final finalStart = element.start;
      final finalEnd = element.end;
      if ((initialStart - finalStart).distance > 0.1 || (initialEnd - finalEnd).distance > 0.1) {
        command = ResizeLineCommand(
          element.layerId,
          element.id,
          initialStart,
          initialEnd,
          finalStart,
          finalEnd,
        );
      }
    } else if (element is TextElement) {
      final initialFontSize = _initialResizeState!['fontSize'] as double;
      final finalFontSize = element.fontSize;
      if ((initialFontSize - finalFontSize).abs() > 0.1) {
        command = ResizeTextCommand(
          element.layerId,
          element.id,
          initialFontSize,
          finalFontSize,
        );
      }
    }

    // Si hay un comando, revertir el cambio temporal y ejecutarlo oficialmente
    if (command != null) {
      // Revertir al estado inicial
      final layer = currentFloorPlan.value!.getLayer(element.layerId);
      if (layer != null) {
        final revertedElement = _revertToInitialState(element);
        if (revertedElement != null) {
          final revertedLayer = layer.updateElement(revertedElement);
          currentFloorPlan.value = currentFloorPlan.value!.updateLayer(revertedLayer);
        }
      }

      // Ejecutar el comando oficialmente para historial
      executeCommand(command);

      // Actualizar el elemento seleccionado
      final updatedLayer = currentFloorPlan.value!.getLayer(element.layerId);
      if (updatedLayer != null) {
        selectedElement.value = updatedLayer.getElement(element.id);
      }
    }

    _cleanupResize();
  }

  FloorPlanElement? _revertToInitialState(FloorPlanElement element) {
    if (_initialResizeState == null) return null;

    if (element is IconElement) {
      return element.copyWith(size: _initialResizeState!['size'] as double);
    } else if (element is RectangleElement) {
      return element.copyWith(
        width: _initialResizeState!['width'] as double,
        height: _initialResizeState!['height'] as double,
        position: _initialResizeState!['position'] as Offset,
      );
    } else if (element is PolygonElement) {
      return element.copyWith(
        points: List<Offset>.from(_initialResizeState!['points'] as List<Offset>),
      );
    } else if (element is LineElement) {
      return element.copyWith(
        start: _initialResizeState!['start'] as Offset,
        end: _initialResizeState!['end'] as Offset,
      );
    } else if (element is TextElement) {
      return element.copyWith(fontSize: _initialResizeState!['fontSize'] as double);
    }

    return null;
  }

  void _cleanupResize() {
    isResizingElement.value = false;
    activeResizeHandle.value = null;
    _initialResizeState = null;
    _resizeStartPosition = null;
  }

  // ========== Rotation Operations ==========

  /// Inicia la rotación de un elemento
  void startRotation(Offset startPosition) {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    isRotatingElement.value = true;
    _initialRotation = element.rotation;
    _rotationCenter = element.getBounds().center;

    // Calcular ángulo inicial desde el centro al punto de inicio
    final dx = startPosition.dx - _rotationCenter!.dx;
    final dy = startPosition.dy - _rotationCenter!.dy;
    _initialAngle = math.atan2(dy, dx);
  }

  /// Actualiza la rotación mientras se arrastra
  void updateRotation(Offset currentPosition) {
    if (!isRotatingElement.value ||
        selectedElement.value == null ||
        _rotationCenter == null ||
        _initialAngle == null ||
        _initialRotation == null) {
      return;
    }

    // Calcular ángulo actual
    final dx = currentPosition.dx - _rotationCenter!.dx;
    final dy = currentPosition.dy - _rotationCenter!.dy;
    final currentAngle = math.atan2(dy, dx);

    // Calcular diferencia de ángulo
    final angleDelta = currentAngle - _initialAngle!;

    // Nueva rotación
    final newRotation = _initialRotation! + angleDelta;

    // Actualizar el elemento temporalmente
    final element = selectedElement.value!;
    final updatedElement = element.copyWith(rotation: newRotation);

    // Actualizar en el floor plan
    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer != null) {
      final updatedLayer = layer.updateElement(updatedElement);
      currentFloorPlan.value = currentFloorPlan.value!.updateLayer(updatedLayer);
      selectedElement.value = updatedElement;
    }
  }

  /// Finaliza la rotación y crea el comando para undo/redo
  void finishRotation() {
    if (!isRotatingElement.value ||
        selectedElement.value == null ||
        _initialRotation == null) {
      _cleanupRotation();
      return;
    }

    final element = selectedElement.value!;
    final finalRotation = element.rotation;

    // Si hubo cambio significativo, crear comando
    if ((finalRotation - _initialRotation!).abs() > 0.01) {
      // Revertir al estado inicial
      final revertedElement = element.copyWith(rotation: _initialRotation);
      final layer = currentFloorPlan.value!.getLayer(element.layerId);
      if (layer != null) {
        final revertedLayer = layer.updateElement(revertedElement);
        currentFloorPlan.value = currentFloorPlan.value!.updateLayer(revertedLayer);
      }

      // Crear y ejecutar comando
      final command = RotateElementCommand(
        element.layerId,
        element.id,
        _initialRotation!,
        finalRotation,
      );
      executeCommand(command);

      // Actualizar el elemento seleccionado
      final updatedLayer = currentFloorPlan.value!.getLayer(element.layerId);
      if (updatedLayer != null) {
        selectedElement.value = updatedLayer.getElement(element.id);
      }
    }

    _cleanupRotation();
  }

  void _cleanupRotation() {
    isRotatingElement.value = false;
    _initialRotation = null;
    _rotationCenter = null;
    _initialAngle = null;
  }

  // ========== Keyboard Shortcuts ==========

  void handleKeyboardShortcut(String key, {bool ctrl = false}) {
    if (ctrl) {
      switch (key.toUpperCase()) {
        case 'Z':
          undo();
          break;
        case 'Y':
          redo();
          break;
        case 'S':
          saveFloorPlan();
          break;
      }
    } else {
      switch (key.toUpperCase()) {
        case 'V':
          selectTool(EditorTool.select);
          break;
        case 'P':
          selectTool(EditorTool.polygon);
          break;
        case 'L':
          selectTool(EditorTool.line);
          break;
        case 'T':
          selectTool(EditorTool.text);
          break;
        case 'H':
          selectTool(EditorTool.pan);
          break;
        case 'DELETE':
        case 'BACKSPACE':
          deleteSelectedElement();
          break;
        case 'ESCAPE':
          selectedElement.value = null;
          if (isDrawingPolygon.value) {
            cancelPolygon();
          }
          break;
      }
    }
  }

  // ========== Z-Index Operations (Layer Ordering) ==========

  /// Traer el elemento seleccionado al frente (incrementar zIndex)
  void bringToFront() {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer == null) return;

    // Encontrar el zIndex máximo en la capa
    int maxZIndex = 0;
    for (final el in layer.elements) {
      if (el.zIndex > maxZIndex) {
        maxZIndex = el.zIndex;
      }
    }

    // Si ya está al frente, no hacer nada
    if (element.zIndex >= maxZIndex) {
      AppSnackbar.show('Información', 'El elemento ya está al frente');
      return;
    }

    // Actualizar zIndex del elemento
    final oldZIndex = element.zIndex;
    final updatedElement = element.copyWith(zIndex: maxZIndex + 1);
    _updateElementInPlace(updatedElement, oldZIndex);

    AppSnackbar.show('Éxito', 'Elemento traído al frente');
  }

  /// Enviar el elemento seleccionado atrás (decrementar zIndex)
  void sendToBack() {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer == null) return;

    // Encontrar el zIndex mínimo en la capa
    int minZIndex = 0;
    for (final el in layer.elements) {
      if (el.zIndex < minZIndex) {
        minZIndex = el.zIndex;
      }
    }

    // Si ya está atrás, no hacer nada
    if (element.zIndex <= minZIndex) {
      AppSnackbar.show('Información', 'El elemento ya está atrás');
      return;
    }

    // Actualizar zIndex del elemento
    final oldZIndex = element.zIndex;
    final updatedElement = element.copyWith(zIndex: minZIndex - 1);
    _updateElementInPlace(updatedElement, oldZIndex);

    AppSnackbar.show('Éxito', 'Elemento enviado atrás');
  }

  /// Subir un nivel (incrementar zIndex en 1)
  void bringForward() {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final oldZIndex = element.zIndex;
    final updatedElement = element.copyWith(zIndex: element.zIndex + 1);
    _updateElementInPlace(updatedElement, oldZIndex);

    AppSnackbar.show('Éxito', 'Elemento movido hacia adelante');
  }

  /// Bajar un nivel (decrementar zIndex en 1)
  void sendBackward() {
    if (selectedElement.value == null) return;

    final element = selectedElement.value!;
    final oldZIndex = element.zIndex;
    final updatedElement = element.copyWith(zIndex: element.zIndex - 1);
    _updateElementInPlace(updatedElement, oldZIndex);

    AppSnackbar.show('Éxito', 'Elemento movido hacia atrás');
  }

  /// Método auxiliar para actualizar un elemento en su lugar
  void _updateElementInPlace(FloorPlanElement updatedElement, int oldZIndex) {
    final element = selectedElement.value!;

    // Crear comando para cambiar zIndex
    final command = ChangeZIndexCommand(
      element.layerId,
      element.id,
      oldZIndex,
      updatedElement.zIndex,
    );

    executeCommand(command);

    // Actualizar selectedElement
    final layer = currentFloorPlan.value!.getLayer(element.layerId);
    if (layer != null) {
      selectedElement.value = layer.getElement(element.id);
    }
  }

  // ========== Lifecycle ==========

  @override
  void onClose() {
    // Limpiar historial de comandos
    commandHistory.clear();

    // Limpiar estado reactivo
    currentFloorPlan.value = null;
    selectedElement.value = null;
    currentPolygonPoints.clear();

    // Resetear flags
    _viewportInitialized = false;
    _initialResizeState = null;
    _resizeStartPosition = null;
    _initialRotation = null;
    _rotationCenter = null;
    _initialAngle = null;

    super.onClose();
  }
}

/// Spec inmutable de una capa "canónica": nombre + z-index sugerido.
/// Sirve para el auto-layering por tipo de elemento.
class _LayerSpec {
  final String name;
  final int zIndex;
  const _LayerSpec(this.name, this.zIndex);
}
