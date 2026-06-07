# REPORTE COMPLETO DEL FEATURE DE TABLES

**Fecha:** 5 de Noviembre de 2025  
**Nivel de Exploración:** Very Thorough (Muy Detallado)  
**Repositorio:** `/Users/mac/Documents/food_app/frontend`

---

## TABLA DE CONTENIDOS

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Controladores](#controladores)
3. [Páginas y Navegación](#páginas-y-navegación)
4. [Flujo Completo](#flujo-completo)
5. [Datos y Configuración](#datos-y-configuración)
6. [Duplicación y Uso](#duplicación-y-uso)
7. [Estado de Funcionamiento](#estado-de-funcionamiento)
8. [Recomendaciones](#recomendaciones)

---

## RESUMEN EJECUTIVO

### Estructura General

El feature de **tables** está bien organizado siguiendo **Clean Architecture**:

```
lib/features/tables/
├── data/               (Datasources, Models, Repositories)
├── domain/             (Entities, UseCases, Repositories interfaces)
└── presentation/       (Controllers, Pages, Widgets, Bindings)
```

### Estado Actual

| Aspecto | Estado | Detalles |
|---------|--------|----------|
| Arquitectura | ✅ Excelente | Clean Architecture, separación clara de responsabilidades |
| Controladores | ✅ 4 activos | TablesController, FloorPlanEditorController, TableMapController, TableStatusController |
| Páginas | ⚠️ 6 de 7 | TableStatusPage sin ruta definida |
| Duplicación | ✅ Ninguna | Cada controlador tiene propósito único |
| Datos | ✅ Real | Todo desde backend, sin hardcoding |
| Undo/Redo | ✅ Implementado | Sistema de comandos en FloorPlanEditor |
| Z-Index | ✅ Reciente | Implementado 5 nov 2025 |

### Métricas

- **Total de archivos:** 47 archivos Dart
- **Líneas totales:** ~15,181 líneas
- **Mayor controlador:** FloorPlanEditorController (1,532 líneas)
- **Mayor widget:** FloorPlanCanvasPainter (1,549 líneas)

---

## CONTROLADORES

### 1. TablesController (484 líneas)

**Propósito:** Gestión general de mesas en la base de datos

**Responsabilidades:**
- ✅ CRUD de mesas (Create, Read, Update, Delete)
- ✅ Filtrado avanzado (estado, zona, sección)
- ✅ Cálculo de estadísticas
- ✅ Ocupación y reserva de mesas

**Estado Observable:**
```dart
final RxList<RestaurantTable> tables = <RestaurantTable>[].obs;
final RxList<RestaurantTable> availableTables = <RestaurantTable>[].obs;
final RxList<RestaurantTable> occupiedTables = <RestaurantTable>[].obs;
final Rx<RestaurantTable?> selectedTable = Rx<RestaurantTable?>(null);
```

**Métodos Principales:**
```
✅ loadTables()              - Cargar con filtros
✅ loadAvailableTables()     - Solo disponibles
✅ createTable()             - Crear nueva
✅ updateTable()             - Actualizar existente
✅ occupyTable()             - Marcar como ocupada
✅ updateTableStatus()       - Cambiar estado
✅ updateTablePosition()     - Posición en canvas
```

**Getters Informativos:**
```
✅ totalTables              - Total de mesas
✅ totalAvailable           - Mesas disponibles
✅ totalOccupied            - Mesas ocupadas
✅ occupancyRate            - Porcentaje ocupación
✅ uniqueZones              - Zonas únicas
✅ uniqueSections           - Secciones únicas
```

**Ubicación:** `/presentation/controllers/tables_controller.dart`

---

### 2. FloorPlanEditorController (1,532 líneas) ⭐ MÁS GRANDE

**Propósito:** Editor visual profesional de planos del restaurante

**Responsabilidades:**
- ✅ Creación y edición de floor plans
- ✅ Herramientas de dibujo (línea, rectángulo, polígono, texto)
- ✅ Gestión de iconos (puertas, baños, cocina, mesas)
- ✅ Transformaciones (zoom, pan, rotación, redimensionamiento)
- ✅ Sistema completo de Undo/Redo
- ✅ Sistema de capas (layers) con Z-Index

**Herramientas de Dibujo:**
```dart
enum EditorTool { select, polygon, line, rectangle, text, pan, icon }
```

**Estado Observable:**
```dart
final Rx<FloorPlan?> currentFloorPlan = Rx<FloorPlan?>(null);
final Rx<EditorTool> currentTool = Rx<EditorTool>(EditorTool.select);
final RxString activeLayerId = RxString('layer_walls');
final Rx<FloorPlanElement?> selectedElement = Rx<FloorPlanElement?>(null);
final RxDouble zoomLevel = RxDouble(1.0);
final Rx<Offset> panOffset = Rx<Offset>(Offset.zero);
```

**Operaciones:**

| Categoría | Métodos |
|-----------|---------|
| **Herramientas** | selectTool, toggleGrid, toggleSnapToGrid |
| **Dibujo** | startLinePreview, addLine, addRectangle, addText, addPolygon |
| **Iconos** | addIconElement, showTableSelector, startIconDrag, finishIconDrag |
| **Transformaciones** | setZoom, zoomIn, zoomOut, resetZoom, setPan |
| **Elementos** | addElement, deleteSelectedElement, selectElementAtPosition, moveSelectedElement |
| **Resize** | startResize, updateResize, finishResize |
| **Rotación** | startRotation, updateRotation, finishRotation |
| **Z-Index** | bringToFront, sendToBack, bringForward, sendBackward |
| **Undo/Redo** | undo, redo, executeCommand |
| **Capas** | setActiveLayer, toggleLayerVisibility, toggleLayerLock |

**Sistema de Comandos:**
```
FloorPlanCommand (interfaz)
├─ AddElementCommand
├─ DeleteElementCommand
├─ MoveElementCommand
├─ ResizeElementCommand
├─ RotateElementCommand
├─ ChangeZIndexCommand (✨ NUEVO 5 nov)
└─ ... otros comandos
```

**Ubicación:** `/presentation/controllers/floor_plan_editor_controller.dart`

---

### 3. TableMapController (291 líneas)

**Propósito:** Gestión de visualización de mesas en canvas interactivo

**Responsabilidades:**
- ✅ Actualizar posiciones de mesas en canvas
- ✅ Rotación de mesas
- ✅ Zoom y pan
- ✅ Snap to grid
- ✅ Historial de cambios (undo/redo)
- ✅ Guardado de cambios

**Estado Observable:**
```dart
final RxMap<String, Offset> pendingChanges = <String, Offset>{}.obs;
final RxBool hasUnsavedChanges = false.obs;
final RxList<MapAction> history = <MapAction>[].obs;
final RxMap<String, double> tableRotations = <String, double>{}.obs;
```

**Métodos:**
```
✅ updateTablePosition()     - Mover mesa con snap
✅ rotateTable()             - Rotar mesa
✅ zoomIn/zoomOut/resetZoom() - Control de zoom
✅ toggleSnapToGrid()        - Activar/desactivar snap
✅ saveAllChanges()          - Guardar en BD
✅ discardChanges()          - Descartar cambios
✅ undo/redo()               - Historial
```

**Ubicación:** `/presentation/controllers/table_map_controller.dart`

---

### 4. TableStatusController (345 líneas)

**Propósito:** Control del estado de mesas durante el servicio (en vivo)

**Responsabilidades:**
- ✅ Cargar estado de mesas por floor plan
- ✅ Ocupar mesa (partySize, serverId, notas)
- ✅ Reservar mesa
- ✅ Liberar mesa (marcar para limpieza)
- ✅ Marcar disponible
- ✅ Sincronización con floor plan
- ✅ Filtrado y búsqueda

**Estado Observable:**
```dart
final tableStatuses = <TableStatusEntity>[].obs;
final selectedTableStatus = Rx<TableStatusEntity?>(null);
final filterStatus = Rx<TableStatus?>(null);
final searchQuery = ''.obs;
```

**Métodos:**
```
✅ loadTableStatuses()        - Cargar por floor plan
✅ loadTableStatus()           - Cargar individual
✅ occupyTable()              - Ocupar (partySize, serverId)
✅ reserveTable()             - Reservar
✅ releaseTable()             - Liberar
✅ markAsAvailable()          - Marcar disponible
✅ syncWithFloorPlan()        - Sincronizar
✅ setStatusFilter()          - Filtrar
✅ get filteredTableStatuses  - Getter con filtros
✅ get statistics             - Estadísticas por estado
```

**Ubicación:** `/presentation/controllers/table_status_controller.dart`

---

## PÁGINAS Y NAVEGACIÓN

### Estructura de Rutas

```
/tables
├── /tables                    → TablesListScreen
├── /tables/list               → TablesListScreen (alias)
├── /tables/create             → TableFormScreen (CREATE)
├── /tables/:id                → TableDetailScreen (READ detail)
├── /tables/:id/edit           → TableFormScreen (UPDATE)
├── /tables/map                → TableMapScreen (Visualización)
├── /tables/layout             → TableLayoutScreen (Layout view)
└── /tables/floor-plan-editor  → FloorPlanEditorPage (Editor)
```

### Árbol de Navegación

```
TablesListScreen (ENTRADA)
│
├─→ [Crear] → TableFormScreen (create)
│              └─→ [Guardar] → vuelve a lista
│
├─→ [Click mesa] → TableDetailScreen (detail)
│                  └─→ [Editar] → TableFormScreen (edit)
│                  └─→ [Acciones] → ocupar, reservar
│
├─→ [Mapa Visual] → TableMapScreen
│                   ├─→ Mover mesas
│                   ├─→ Rotar mesas
│                   └─→ [Guardar cambios]
│
├─→ [Vista Layout] → TableLayoutScreen
│                    └─→ Vista estática del plano
│
└─→ [Editor Planos] → FloorPlanEditorPage
                      ├─→ Dibujar paredes
                      ├─→ Agregar iconos
                      ├─→ Agregar mesas
                      ├─→ Undo/Redo
                      └─→ [Guardar plano]
```

---

### Páginas en Detalle

#### 1. TablesListScreen (533 líneas)

**Propósito:** Vista principal, lista de todas las mesas

**Características:**
- ✅ Lista con scroll de mesas
- ✅ Filtros: estado, zona, sección, activas
- ✅ Tarjetas de mesas con estado visual
- ✅ Estadísticas en header
- ✅ Botones de navegación

**Acciones disponibles:**
```
- Crear mesa nueva (botón FAB)
- Ver detalle (click en tarjeta)
- Cambiar estado (dropdown en tarjeta)
- Ir a Mapa Visual (icono)
- Ir a Layout (icono)
- Ir a Editor (icono)
```

**Controller:** `TablesController`  
**Binding:** `TablesBinding`

---

#### 2. TableFormScreen (505 líneas)

**Propósito:** Crear o editar una mesa

**Modo:**
- **CREATE:** sin parámetro `:id`
- **EDIT:** con parámetro `:id`

**Campos del Formulario:**
```
- Número de mesa (requerido)
- Nombre
- Capacidad (personas)
- Capacidad mínima
- Zona
- Sección
- Tipo (standard, high-top, etc)
- Forma (circular, rectangular, etc)
- Posición X, Y
- Ancho, Alto
- Estado inicial
- Activa (toggle)
```

**Validaciones:**
- ✅ Número requerido
- ✅ Capacidad > 0
- ✅ Posiciones numéricas

**Controller:** `TablesController`  
**Binding:** `TablesBinding`

---

#### 3. TableDetailScreen (718 líneas)

**Propósito:** Vista detallada de una mesa

**Secciones:**
```
- Header con estado visual
- Información básica (número, nombre, capacidad)
- Información de ubicación (zona, sección, posición)
- Historial de cambios
- Información técnica (ID, timestamps)
- Botones de acción
```

**Acciones:**
- ✅ Editar mesa
- ✅ Cambiar estado
- ✅ Más opciones (menú)

**Controller:** `TablesController`  
**Binding:** `TablesBinding`

---

#### 4. TableMapScreen (565 líneas)

**Propósito:** Mapa visual interactivo de mesas

**Características:**
- ✅ Canvas con TransformationController
- ✅ Mesas como widgets arrastrables
- ✅ Zoom (0.5x a 3.0x)
- ✅ Snap to grid (grid 50x50)
- ✅ Rotación de mesas
- ✅ Undo/Redo

**Toolbar:**
```
[Undo] [Redo] [Snap Grid] [Zoom Menu]
```

**Acciones por mesa:**
- Arrastrar para mover
- Rotar
- Click para seleccionar

**Guardado:**
- [Guardar cambios] → actualiza BD
- [Descartar] → recarga datos originales

**Controller:** `TableMapController` + `TablesController`  
**Binding:** `TablesBinding`

---

#### 5. TableLayoutScreen (660 líneas)

**Propósito:** Vista de layout del restaurante (más simple que mapa)

**Características:**
- ✅ Dual view: Grid layout O Positioned layout
- ✅ Legenda de colores por estado
- ✅ Filtro por zona
- ✅ Estadísticas en footer
- ✅ Vista estática (sin edición)

**Colores:**
```
Verde    → Disponible
Rojo     → Ocupada
Naranja  → Reservada
Amarillo → Limpieza
Gris     → Mantenimiento
```

**Controller:** `TablesController`  
**Binding:** `TablesBinding`

---

#### 6. FloorPlanEditorPage (709 líneas) ⭐ EDITOR PROFESIONAL

**Propósito:** Editor visual de planos del restaurante

**Componentes:**

| Componente | Descripción |
|-----------|-------------|
| **Canvas** | CustomPaint con FloorPlanCanvasPainter |
| **Toolbar** | Herramientas de dibujo (izquierda) |
| **AppBar** | Undo/Redo, Z-Index, Zoom |
| **Layers Panel** | Panel lateral con capas (derecha) |
| **Grid** | Grid visualizado y snap to grid |

**Herramientas:**
```
[V] Select    → Seleccionar elementos
[P] Polygon   → Dibujar polígono
[L] Line      → Dibujar línea
[R] Rectangle → Dibujar rectángulo
[T] Text      → Agregar texto
[H] Pan       → Mover canvas
[+] Icon      → Agregar iconos
```

**Características:**
- ✅ Múltiples capas (walls, furniture, decorations, etc)
- ✅ Visibilidad/bloqueo de capas
- ✅ Undo/Redo completo
- ✅ Z-Index (ordenamiento de elementos)
- ✅ Zoom y pan
- ✅ Snap to grid
- ✅ Manejo de rotación y resize con handles
- ✅ Preview en tiempo real

**Responsividad:**
```
Desktop  → Toolbar + Canvas + LayersPanel
Tablet   → Toolbar compacto + Canvas
Mobile   → Canvas full, botón toggle toolbar
```

**Controller:** `FloorPlanEditorController`  
**Binding:** `FloorPlanEditorBinding`

---

#### 7. TableStatusPage (453 líneas) ⚠️ NO TIENE RUTA

**Propósito:** Tablero de servicio (estado en vivo)

**Características:**
- ✅ Estado de cada mesa
- ✅ Ocupar, reservar, liberar
- ✅ Sincronización con floor plan
- ✅ Filtros y búsqueda

**Estado:** ❌ NO ESTÁ EN `app_pages.dart`

**Ubicación:** `/presentation/pages/table_status_page.dart`

---

## FLUJO COMPLETO

### Desde Crear Floor Plan Hasta Servir

```
PASO 1: DISEÑAR FLOOR PLAN
┌────────────────────────────────────────┐
│  FloorPlanEditorPage                   │
│  ├─ Dibujar paredes (líneas/rects)    │
│  ├─ Agregar iconos (puertas, baños)   │
│  ├─ Agregar MESAS                      │
│  │  └─ TableSelectorDialog             │
│  │     └─ Selecciona capacidad (2,4,6) │
│  ├─ Undo/Redo                          │
│  └─ Guardar FloorPlan                  │
└────────────────────────────────────────┘
            ↓ [Guardar]
     FloorPlanRepository
            ↓
        Backend API
            ↓
    FloorPlan con IconElements
    (mesas como iconos, no BD)


PASO 2: SINCRONIZAR MESAS EN BD
┌────────────────────────────────────────┐
│  TablesListScreen                      │
│  ├─ Sistema sincroniza:                │
│  │  ├─ Lee todos los IconElements      │
│  │  ├─ Por cada mesa crea              │
│  │  │  RestaurantTable en BD           │
│  │  └─ Asigna números, capacidades    │
│  │                                     │
│  └─ O crear MANUALMENTE vía            │
│     TableFormScreen                    │
└────────────────────────────────────────┘
            ↓
     RestaurantTable en BD


PASO 3: ORGANIZAR MESAS EN MAPA
┌────────────────────────────────────────┐
│  TableMapScreen                        │
│  ├─ Muestra mesas desde BD             │
│  ├─ Arrastrar para mover               │
│  ├─ Rotar                              │
│  ├─ Snap to grid                       │
│  └─ Guardar posiciones                 │
└────────────────────────────────────────┘
            ↓ [Guardar cambios]
     TablesController.updateTablePosition()
            ↓
        Backend API
            ↓
    Posiciones en BD


PASO 4: MONITOREAR SERVICIO
┌────────────────────────────────────────┐
│  TableLayoutScreen                     │
│  └─ Vista estática del plano           │
│                                        │
│  O                                      │
│                                        │
│  TableStatusPage (sin ruta actual)    │
│  ├─ Estado en vivo                     │
│  ├─ Ocupar mesa                        │
│  ├─ Reservar                           │
│  ├─ Marcar limpieza                    │
│  └─ Sincronizar estados                │
└────────────────────────────────────────┘
```

---

## DATOS Y CONFIGURACIÓN

### Datos Hardcodeados

**Mínimo de hardcoding encontrado:**

```dart
// floor_plan_editor_controller.dart:140
final newFloorPlan = FloorPlan.empty(
  id: '',  // ← Placeholder, backend lo genera
  name: name,
);
```

**TODO Items Pendientes:**

```dart
// table_status_page.dart
// TODO: Navegar a la orden

// draggable_table_widget.dart
// TODO: Ocupar mesa
```

### Fuentes de Datos Reales

✅ **Todo desde backend o DI:**

```
Datasources
├─ table_remote_datasource.dart    → API REST
├─ floor_plan_datasource.dart      → API REST
└─ table_status_datasource.dart    → API REST

Repositories
├─ table_repository_impl.dart
├─ floor_plan_repository_impl.dart
└─ table_status_repository.dart

UseCases
├─ get_tables_usecase.dart
├─ create_table_usecase.dart
├─ update_table_usecase.dart
└─ ... 5 más
```

### Inyección de Dependencias

**Bindings:**
```dart
// tables_binding.dart
TablesController con todos los UseCases

// floor_plan_editor_binding.dart
FloorPlanEditorController con FloorPlanRepository

// table_status_binding.dart
TableStatusController con TableStatusRepository
```

---

## DUPLICACIÓN Y USO

### Análisis de Controladores

| Controlador | Líneas | Propósito | ¿Duplicado? |
|------------|--------|----------|-----------|
| TablesController | 484 | CRUD mesas | ❌ NO (único) |
| FloorPlanEditorController | 1532 | Editar planos | ❌ NO (único) |
| TableMapController | 291 | Mapa visual | ❌ NO (único) |
| TableStatusController | 345 | Estado en vivo | ❌ NO (único) |

**Conclusión:** ✅ **CERO DUPLICACIÓN**

Cada controlador tiene responsabilidad única y clara.

### Análisis de Páginas

| Página | Estado | Ruta | Binding |
|--------|--------|------|---------|
| TablesListScreen | ✅ ACTIVA | `/tables` | TablesBinding |
| TableFormScreen | ✅ ACTIVA | `/tables/create`, `/tables/:id/edit` | TablesBinding |
| TableDetailScreen | ✅ ACTIVA | `/tables/:id` | TablesBinding |
| TableMapScreen | ✅ ACTIVA | `/tables/map` | TablesBinding |
| TableLayoutScreen | ✅ ACTIVA | `/tables/layout` | TablesBinding |
| FloorPlanEditorPage | ✅ ACTIVA | `/tables/floor-plan-editor` | FloorPlanEditorBinding |
| TableStatusPage | ❌ INACTIVA | SIN RUTA | TableStatusBinding |

**Conclusión:** ⚠️ **1 página sin usar**

### Análisis de Widgets

| Widget | Líneas | Usado en | ¿Activo? |
|--------|--------|----------|----------|
| table_card.dart | ~150 | TablesListScreen | ✅ |
| draggable_table_widget.dart | 278 | TableMapScreen | ✅ |
| floor_plan_canvas_painter.dart | 1549 | FloorPlanEditorPage | ✅ |
| table_selector_dialog.dart | 280 | FloorPlanEditorController | ✅ |
| icon_selector_dialog.dart | 322 | FloorPlanEditorController | ✅ |
| table_stats_card.dart | ~150 | TablesListScreen | ✅ |
| table_status_card.dart | ~150 | TableStatusPage | ✅ |
| reserve_table_dialog.dart | ~120 | TableStatusPage | ✅ |
| occupy_table_dialog.dart | ~120 | TableStatusPage | ✅ |
| editor_toolbar.dart | ~200 | FloorPlanEditorPage | ✅ |
| layers_panel.dart | ~200 | FloorPlanEditorPage | ✅ |

**Conclusión:** ✅ **TODOS LOS WIDGETS SE USAN**

---

## ESTADO DE FUNCIONAMIENTO

### Completamente Funcional ✅

```
✅ TablesController
   ├─ Cargar mesas
   ├─ CRUD operaciones
   ├─ Filtrados
   ├─ Cambios de estado
   └─ Estadísticas

✅ FloorPlanEditorController
   ├─ Creación/edición de planos
   ├─ Herramientas de dibujo
   ├─ Iconos y mesas
   ├─ Undo/Redo
   ├─ Z-Index (✨ nuevo 5 nov)
   └─ Resize y rotación

✅ TableMapController
   ├─ Visualización interactiva
   ├─ Movimiento y rotación
   ├─ Snap to grid
   ├─ Zoom y pan
   └─ Historial

✅ TableStatusController
   ├─ Carga de estados
   ├─ Ocupar/reservar
   ├─ Sincronización
   └─ Filtros
```

### Incompleto/Abandonado ⚠️

```
⚠️ TableStatusPage
   ├─ Existe: SÍ
   ├─ Funcional: SÍ
   ├─ En rutas: NO
   ├─ Estado: Abandonada
   └─ Acción: Integrar o remover
```

### Mejoras Recientes (5 nov 2025)

```
✨ Z-Index System
   ├─ ChangeZIndexCommand creado
   ├─ bringToFront()
   ├─ sendToBack()
   ├─ bringForward()
   ├─ sendBackward()
   └─ Menú contextual en AppBar

✨ Visual Improvements
   ├─ Efectos 3D en rectángulos
   ├─ Gradientes profesionales
   ├─ Sombras múltiples
   ├─ Colores Indigo (no gris)
   └─ Preview mejorado

✨ Documentación
   ├─ CORRECCIONES.md
   └─ MEJORAS_IMPLEMENTADAS.md
```

---

## RECOMENDACIONES

### 1. CRÍTICAS (Hacer ahora)

#### 1.1 Integrar TableStatusPage

**Problema:** Página existe pero no tiene ruta.

**Opción A - Crear ruta:**
```dart
GetPage(
  name: AppRoutes.tableStatus,
  page: () => TableStatusPage(
    floorPlanId: 'defaultFloorPlanId',
    floorPlanName: 'Principal',
  ),
  binding: TableStatusBinding(),
  middlewares: [AuthGuard()],
)
```

**Opción B - Remover:**
```bash
rm presentation/pages/table_status_page.dart
rm presentation/widgets/table_status_card.dart
rm presentation/controllers/table_status_controller.dart
rm presentation/bindings/table_status_binding.dart
```

**Recomendación:** **Opción A** - Parece ser un tablero útil para servicio.

---

#### 1.2 Completar TODOs Funcionales

**En table_status_page.dart:**
```dart
// TODO: Navegar a la orden
// → Implementar navegación a orden asociada
// Sugerencia: Get.toNamed('/orders/:id')
```

**En draggable_table_widget.dart:**
```dart
// TODO: Ocupar mesa
// → Implementar diálogo de ocupación
// Sugerencia: Get.dialog<bool>(OccupyTableDialog())
```

---

### 2. IMPORTANTES (Próxima semana)

#### 2.1 Atajos de Teclado para Z-Index

**Añadir en FloorPlanEditorController:**
```dart
// En handleKeyboardShortcut()
case 'CTRL+]':
  bringForward();
  break;
case 'CTRL+[':
  sendBackward();
  break;
case 'CTRL+SHIFT+]':
  bringToFront();
  break;
case 'CTRL+SHIFT+[':
  sendToBack();
  break;
```

#### 2.2 Panel Visual de Capas

**Mejorar layers_panel.dart:**
- Mostrar orden de elementos (zIndex)
- Drag & drop para reordenar
- Previsualización de elemento

---

### 3. MEJORAS (Mediano plazo)

#### 3.1 Sincronización Automática

**Problema:** FloorPlan y RestaurantTable están desacoplados.

**Solución:** 
- Cuando se guarda FloorPlan con IconElements
- Automáticamente crear/actualizar RestaurantTable
- Mantener sincronización bidireccional

#### 3.2 Vista 3D de Plano

**Añadir:**
- Proyección 3D del plano
- Visualización del restaurante en perspectiva
- Navegación 3D

#### 3.3 Exportación/Importación

**Permitir:**
- Exportar plano como PDF
- Importar plano desde imagen
- Guardar templates de planos

---

### 4. OPTIMIZACIÓN (Largo plazo)

#### 4.1 Rendimiento del Canvas

**Problema:** FloorPlanCanvasPainter (1549 líneas) es muy grande.

**Solución:**
- Dividir en múltiples drawers especializados
- Usar layers del canvas
- Implementar culling

#### 4.2 Caché de Elementos

**Implementar:**
- Caché de iconos renderizados
- Caché de bounds de elementos
- Invalidación selectiva

---

## CONCLUSIONES

### Arquitectura

✅ **Excelente**
- Clean Architecture bien implementada
- Separación clara de responsabilidades
- Inyección de dependencias correcta
- Sin duplicación de código

### Funcionalidad

✅ **Completa (excepto TableStatusPage)**
- 4 controladores activos
- 6 de 7 páginas en uso
- Sistema robusto de Undo/Redo
- Z-Index implementado recientemente

### Código

✅ **Bien documentado**
- CORRECCIONES.md detallado
- MEJORAS_IMPLEMENTADAS.md completo
- THEMING_GUIDE.md disponible

### Próximos Pasos

1. **Integrar TableStatusPage** en rutas
2. **Completar TODOs** pendientes
3. **Añadir atajos** de teclado
4. **Mejorar panel** de capas
5. **Optimizar canvas** painter

---

## APÉNDICE: COMANDOS ÚTILES

### Ver estructura completa
```bash
tree /Users/mac/Documents/food_app/frontend/lib/features/tables -L 3
```

### Contar líneas por archivo
```bash
find /Users/mac/Documents/food_app/frontend/lib/features/tables -name "*.dart" \
  -exec wc -l {} + | sort -n
```

### Encontrar TODOs
```bash
grep -r "TODO\|FIXME" /Users/mac/Documents/food_app/frontend/lib/features/tables
```

### Ver imports de controladores
```bash
grep -r "import.*_controller" /Users/mac/Documents/food_app/frontend/lib \
  --include="*.dart" | grep -v "^Binary"
```

---

**Fin del Reporte**

Generado: 5 de Noviembre de 2025  
Por: Claude Code Assistant  
Nivel: Very Thorough
