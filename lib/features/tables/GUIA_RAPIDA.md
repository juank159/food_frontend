# GUÍA RÁPIDA DEL FEATURE DE TABLES

**Última actualización:** 5 de Noviembre 2025

---

## INICIO RÁPIDO

### ¿Qué hace cada controlador?

| Controlador | Líneas | Propósito | Ubicación |
|------------|--------|----------|-----------|
| **TablesController** | 484 | Gestión CRUD de mesas | `/controllers/tables_controller.dart` |
| **FloorPlanEditorController** | 1,532 | Editor visual de planos | `/controllers/floor_plan_editor_controller.dart` |
| **TableMapController** | 291 | Visualización interactiva | `/controllers/table_map_controller.dart` |
| **TableStatusController** | 345 | Control en vivo de servicio | `/controllers/table_status_controller.dart` |

### ¿Qué hace cada página?

| Página | Ruta | Controlador | Propósito |
|--------|------|-------------|----------|
| **TablesListScreen** | `/tables` | TablesController | Lista principal de mesas |
| **TableFormScreen** | `/tables/create`, `/tables/:id/edit` | TablesController | Crear/editar mesa |
| **TableDetailScreen** | `/tables/:id` | TablesController | Ver detalle de mesa |
| **TableMapScreen** | `/tables/map` | TableMapController + TablesController | Organizar en mapa |
| **TableLayoutScreen** | `/tables/layout` | TablesController | Vista layout del restaurante |
| **FloorPlanEditorPage** | `/tables/floor-plan-editor` | FloorPlanEditorController | Diseñar plano |
| **TableStatusPage** | ❌ SIN RUTA | TableStatusController | Control de servicio (abandonada) |

---

## FLUJO DE TRABAJO

### Flujo 1: Crear un plano y gestionar mesas

```
1. Ir a Editor de Planos
   └─ /tables/floor-plan-editor → FloorPlanEditorPage

2. Diseñar plano
   ├─ Dibujar paredes (líneas, rectángulos)
   ├─ Agregar iconos (puertas, baños, cocina)
   ├─ Agregar MESAS
   │  └─ Click icono mesa → TableSelectorDialog
   │     └─ Seleccionar capacidad (2, 4, 6, 8)
   ├─ Undo/Redo según sea necesario
   └─ Guardar

3. Ir a Lista de Mesas
   └─ /tables → TablesListScreen

4. Sistema sincroniza
   └─ Crea RestaurantTable por cada IconElement del plano

5. Organizar en mapa (opcional)
   └─ /tables/map → TableMapScreen
      ├─ Mover mesas
      ├─ Rotar
      └─ Guardar posiciones
```

### Flujo 2: Gestionar mesas durante el día

```
1. Abrir lista de mesas
   └─ /tables → TablesListScreen

2. Buscar o filtrar
   ├─ Por estado (disponible, ocupada, etc)
   ├─ Por zona
   ├─ Por sección
   └─ Solo activas

3. Acciones sobre una mesa
   ├─ Click en tarjeta → /tables/:id (detalle)
   │  └─ [Editar] → /tables/:id/edit
   │  └─ [Ocupar] → cambiar estado
   ├─ [Crear nueva] → /tables/create
   └─ [Ver layout] → /tables/layout
```

---

## MÉTODOS PRINCIPALES POR CONTROLADOR

### TablesController

```dart
// Cargar
loadTables({status, zone, section, isActive})
loadAvailableTables({minCapacity, zone})
loadTableDetails(tableId)

// CRUD
createTable(tableData) → bool
updateTable(id, tableData) → bool
deleteTable(id) → bool  // Si existe

// Estado
updateTableStatus(tableId, status)
occupyTable(tableId, {orderId, assignedTo})
updateTablePosition(tableId, x, y, {width, height, shape})

// Filtros
filterByStatus(status)
filterByZone(zone)
filterBySection(section)
toggleActiveFilter()
clearFilters()

// Getters
totalTables, totalAvailable, totalOccupied, totalReserved, totalCleaning
occupancyRate
uniqueZones, uniqueSections
```

### FloorPlanEditorController

```dart
// Planos
loadFloorPlans()
createNewFloorPlan(name)
saveFloorPlan()

// Herramientas
selectTool(EditorTool)
toggleGrid()
toggleSnapToGrid()

// Dibujo
addLine(start, end)
addRectangle(topLeft, bottomRight)
addText(position, text)
addPolygon(points)
addIconElement(position, type)
showTableSelector(position)

// Elementos
addElement(element)
deleteSelectedElement()
selectElementAtPosition(position)
moveSelectedElement(newPosition)
resizeSelectedElement()
rotateSelectedElement()

// Z-Index
bringToFront()
sendToBack()
bringForward()
sendBackward()

// Capas
setActiveLayer(layerId)
toggleLayerVisibility(layerId)
toggleLayerLock(layerId)

// Zoom/Pan
zoomIn(), zoomOut(), resetZoom()
setPan(offset)

// Undo/Redo
undo()
redo()
executeCommand(command)
```

### TableMapController

```dart
// Movimiento
updateTablePosition(tableId, position)
rotateTable(tableId, angle)

// Zoom
zoomIn()
zoomOut()
resetZoom()

// Grid
toggleSnapToGrid()
updateGridSize(size)

// Cambios
saveAllChanges()
discardChanges()

// Historial
undo()
redo()

// Getters
getTablePosition(table) → Offset
getTableRotation(tableId) → double
canUndo, canRedo → bool
```

### TableStatusController

```dart
// Carga
loadTableStatuses(floorPlanId)
loadTableStatus(tableElementId)

// Operaciones
occupyTable({tableElementId, partySize, serverId, notes}) → bool
reserveTable({tableElementId, partySize, reservationId, reservedFor, notes}) → bool
releaseTable(tableElementId) → bool
markAsAvailable(tableElementId) → bool

// Sincronización
syncWithFloorPlan(floorPlanId)

// Filtros
setStatusFilter(status)
setSearchQuery(query)

// Getters
filteredTableStatuses → List
statistics → Map<String, int>
```

---

## PROPIEDADES OBSERVABLES POR CONTROLADOR

### TablesController

```dart
// Listas
final RxList<RestaurantTable> tables
final RxList<RestaurantTable> availableTables
final RxList<RestaurantTable> occupiedTables

// Estado
final Rx<RestaurantTable?> selectedTable
final RxBool isLoading
final RxString errorMessage

// Filtros
final Rx<TableStatus?> filterStatus
final Rx<String?> filterZone
final Rx<String?> filterSection
final RxBool showOnlyActive
```

### FloorPlanEditorController

```dart
// Plano actual
final Rx<FloorPlan?> currentFloorPlan

// Herramienta
final Rx<EditorTool> currentTool

// Capas
final RxString activeLayerId

// Elemento
final Rx<FloorPlanElement?> selectedElement

// Transformaciones
final RxDouble zoomLevel
final Rx<Offset> panOffset

// Grid
final RxBool showGrid
final RxBool snapToGrid
final RxDouble gridSize

// Undo/Redo
final CommandHistory commandHistory
final RxInt historyVersion

// Carga
final RxBool isLoading
final RxBool isSaving
```

### TableMapController

```dart
// Cambios pendientes
final RxMap<String, Offset> pendingChanges
final RxBool hasUnsavedChanges

// Historial
final RxList<MapAction> history
final RxInt historyIndex

// Rotaciones
final RxMap<String, double> tableRotations

// Zoom
final RxDouble currentScale
final RxDouble minScale
final RxDouble maxScale

// Grid
final RxBool snapToGrid
final RxDouble gridSize
```

### TableStatusController

```dart
// Datos
final RxList<TableStatusEntity> tableStatuses
final Rx<TableStatusEntity?> selectedTableStatus

// Estado
final RxBool isLoading
final RxString errorMessage

// Filtros
final Rx<TableStatus?> filterStatus
final RxString searchQuery
```

---

## ENUMS Y CONSTANTES

### TableStatus (enum)
```dart
available   // Disponible
occupied    // Ocupada
reserved    // Reservada
cleaning    // Limpieza
maintenance // Mantenimiento
```

### EditorTool (enum)
```dart
select      // Seleccionar
polygon     // Dibujar polígono
line        // Dibujar línea
rectangle   // Dibujar rectángulo
text        // Agregar texto
pan         // Mover canvas
icon        // Agregar icono
```

### ElementType (enum)
```dart
polygon        // Polígono
line           // Línea
rectangle      // Rectángulo
text           // Texto
icon           // Icono
table          // Mesa
door           // Puerta
bathroom       // Baño
kitchen        // Cocina
bar            // Barra
plant          // Planta
stairs         // Escaleras
```

### TableCapacity (enum)
```dart
two    // 2 personas
four   // 4 personas
six    // 6 personas
eight  // 8 personas
```

---

## BINDINGS Y RUTAS

### Registración en app_pages.dart

```dart
// Tables (4 rutas comparten TablesBinding)
GetPage(name: '/tables', binding: TablesBinding(), page: () => TablesListScreen())
GetPage(name: '/tables/create', binding: TablesBinding(), page: () => TableFormScreen())
GetPage(name: '/tables/:id/edit', binding: TablesBinding(), page: () => TableFormScreen())
GetPage(name: '/tables/:id', binding: TablesBinding(), page: () => TableDetailScreen())
GetPage(name: '/tables/map', binding: TablesBinding(), page: () => TableMapScreen())
GetPage(name: '/tables/layout', binding: TablesBinding(), page: () => TableLayoutScreen())

// Floor Plan Editor (binding separado)
GetPage(name: '/tables/floor-plan-editor', binding: FloorPlanEditorBinding(), page: () => FloorPlanEditorPage())
```

### Inyecciones en Bindings

**TablesBinding:**
- TablesController (con todos los UseCases)

**FloorPlanEditorBinding:**
- FloorPlanDataSource
- FloorPlanRepository
- FloorPlanEditorController

**TableStatusBinding:**
- TableStatusDataSource
- TableStatusRepository
- TableStatusController

---

## PROBLEMAS CONOCIDOS Y SOLUCIONES

### ⚠️ TableStatusPage sin ruta

**Problema:** La página existe pero no está en app_pages.dart

**Soluciones:**
```dart
// Opción 1: Agregar ruta
GetPage(
  name: '/tables/status',
  binding: TableStatusBinding(),
  page: () => TableStatusPage(
    floorPlanId: 'defaultFloorPlanId',
    floorPlanName: 'Principal',
  ),
)

// Opción 2: Remover archivos
rm presentation/pages/table_status_page.dart
rm presentation/widgets/table_status_card.dart
rm presentation/controllers/table_status_controller.dart
rm presentation/bindings/table_status_binding.dart
```

### ⚠️ TODOs pendientes

```dart
// table_status_page.dart
// TODO: Navegar a la orden
→ Agregar: Get.toNamed('/orders/:id')

// draggable_table_widget.dart  
// TODO: Ocupar mesa
→ Agregar: Get.dialog<bool>(OccupyTableDialog())
```

---

## TESTING BÁSICO

### Crear una mesa
```dart
final success = await tablesController.createTable({
  'tableNumber': '1',
  'capacity': 4,
  'zone': 'Comedor Principal',
  'section': 'A',
  'status': 'available',
});
assert(success == true);
assert(tablesController.tables.isNotEmpty);
```

### Ocupar una mesa
```dart
await tablesController.occupyTable('mesa-1', orderId: 'orden-123');
assert(tablesController.selectedTable.value?.isOccupied == true);
```

### Undo en editor
```dart
await floorPlanController.addRectangle(Offset.zero, Offset(100, 100));
floorPlanController.undo();
assert(floorPlanController.currentFloorPlan.value?.layers.isEmpty == true);
```

---

## REFERENCIAS RÁPIDAS

| Necesito... | Voy a... | Uso |
|-------------|----------|------|
| Crear mesa | `/tables/create` | TableFormScreen + TablesController.createTable |
| Ver lista | `/tables` | TablesListScreen + TablesController.loadTables |
| Editar mesa | `/tables/:id/edit` | TableFormScreen + TablesController.updateTable |
| Mover mesas | `/tables/map` | TableMapScreen + TableMapController.updateTablePosition |
| Diseñar plano | `/tables/floor-plan-editor` | FloorPlanEditorPage + FloorPlanEditorController |
| Ver estado en vivo | ❌ SIN RUTA | TableStatusPage + TableStatusController |

---

## RECOMENDACIONES DE PRÓXIMOS PASOS

### Hoy
1. Integrar TableStatusPage en rutas
2. Completar TODOs funcionales

### Esta semana  
1. Agregar atajos de teclado para Z-Index
2. Mejorar panel de capas visual

### Próximas semanas
1. Sincronización automática plano ↔ BD
2. Vista 3D del restaurante

---

## DOCUMENTACIÓN COMPLETA

Para más detalles sobre cada componente, ver:
- **REPORTE_COMPLETO_TABLES.md** - Análisis exhaustivo
- **MEJORAS_IMPLEMENTADAS.md** - Features nuevas (Z-Index, 3D)
- **CORRECCIONES.md** - Errores corregidos
- **THEMING_GUIDE.md** - Guía de temas visuales

---

**Última actualización:** 5 de Noviembre 2025  
**Nivel de detalle:** Rápido (para referencias del día a día)
