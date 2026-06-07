# CHECKLIST DE IMPLEMENTACIÓN - FOOD APP FRONTEND

## LEGEND
- ✅ = Completado
- ⚠️ = Parcial
- ❌ = Pendiente
- 🔧 = Requiere refactorización

---

## PRIORITY 1: CRITICAL (BLOQUEA DESARROLLO)

### Use Cases Faltantes - MUST IMPLEMENT

#### Categories
- [ ] `DeleteCategoryUseCase` - Definido en repo, NO implementado
- [ ] `GetRootCategoriesUseCase` - Definido en repo, NO implementado  
- [ ] `GetSubcategoriesUseCase` - Definido en repo, NO implementado
- [ ] Registrar los 3 anteriores en `injection_container.dart`

#### Products
- [ ] `GetProductsByCategoryUseCase` - Definido en repo, NO implementado
- [ ] `GetLowStockProductsUseCase` - Definido en repo, NO implementado
- [ ] `GetProductBySkuUseCase` - Definido en repo, NO implementado
- [ ] `UpdateStockUseCase` - Definido en repo, NO implementado
- [ ] Registrar en `injection_container.dart`

#### Orders (9 use cases faltantes)
- [ ] `GetOrderByNumberUseCase` - Definido en repo, NO implementado
- [ ] `GetOrdersByTableUseCase` - Definido en repo, NO implementado
- [ ] `GetOrdersByCustomerUseCase` - Definido en repo, NO implementado
- [ ] `GetPendingPaymentOrdersUseCase` - Definido en repo, NO implementado
- [ ] `UpdateOrderUseCase` - Definido en repo, NO implementado
- [ ] `AssignOrderUseCase` - Definido en repo, NO implementado
- [ ] `UpdatePaymentMethodUseCase` - Definido en repo, NO implementado
- [ ] `MarkAsPaidUseCase` - Definido en repo, NO implementado
- [ ] `CancelOrderUseCase` - Definido en repo, NO implementado
- [ ] Registrar los 9 en `injection_container.dart`

#### Tables (4 use cases faltantes)
- [ ] `ReleaseTableUseCase` - Definido en repo, NO implementado
- [ ] `ReserveTableUseCase` - Definido en repo, NO implementado
- [ ] `MarkTableForCleaningUseCase` - Definido en repo, NO implementado
- [ ] `CompleteTableCleaningUseCase` - Definido en repo, NO implementado
- [ ] Registrar en `injection_container.dart`

#### FloorPlan (4 use cases nuevos)
- [ ] `CreateFloorPlanUseCase` - Repositorio vacio, NO tiene use case
- [ ] `UpdateFloorPlanUseCase` - Repositorio vacio, NO tiene use case
- [ ] `DeleteFloorPlanUseCase` - Repositorio vacio, NO tiene use case
- [ ] `DuplicateFloorPlanUseCase` - Repositorio vacio, NO tiene use case
- [ ] Crear los 4 use cases + registrar

#### Payments (3 use cases faltantes)
- [ ] `CreatePaymentUseCase` - Definido en repo, NO implementado
- [ ] `GetPaymentByIdUseCase` - Definido en repo, NO implementado
- [ ] `GetPaymentsUseCase` (genérico) - Definido en repo, NO implementado
- [ ] Registrar en `injection_container.dart`

### Páginas Faltantes - MUST IMPLEMENT

- [ ] `ProductDetailPage` - Vista de detalle de producto
- [ ] `PaymentsPage` - Página principal de pagos (actualmente solo en widgets)
- [ ] Agregar rutas en `app_pages.dart` y `app_routes.dart`

### Refactorización Crítica - DRY VIOLATIONS

#### Controllers Genéricos
- [ ] Crear `BasePaginatedController<T>` (reemplaza lógica duplicate en CategoriesController, OrdersController, ProductsController, TablesController)
- [ ] Migrar CategoriesController → heredar BaseController
- [ ] Migrar OrdersController → heredar BaseController
- [ ] Migrar ProductsController → heredar BaseController
- [ ] Migrar TableStatusController → heredar BaseController

#### Form Controllers
- [ ] Crear `BaseFormController<T>` abstracto
- [ ] Migrar CategoryFormController → heredar BaseFormController
- [ ] Migrar ProductFormController → heredar BaseFormController
- [ ] Migrar OrderFormController → heredar BaseFormController

---

## PRIORITY 2: IMPORTANT (MEJORA FUNCIONALIDAD)

### Datasources Locales (Offline Support)
- [ ] Crear `ProductLocalDataSource` (caché)
- [ ] Crear `CategoryLocalDataSource` (caché)
- [ ] Crear `TableLocalDataSource` (caché)
- [ ] Implementar sincronización con RemoteDataSource

### Widgets Genéricos - DRY
- [ ] Crear `BaseConfirmationDialog<T>`
- [ ] Refactorizar `ProcessPaymentDialog` → BaseConfirmationDialog
- [ ] Refactorizar `ReserveTableDialog` → BaseConfirmationDialog
- [ ] Refactorizar `OccupyTableDialog` → BaseConfirmationDialog

### Bindings
- [ ] 🔧 Mejorar ProductsBinding - inyectar use cases directos
- [ ] 🔧 Mejorar OrdersBinding - inyectar use cases directos
- [ ] 🔧 Mejorar CategoriesBinding - inyectar use cases directos
- [ ] 🔧 Mejorar TablesBinding - inyectar use cases directos

### Error Handling
- [ ] Crear `RepositoryErrorHandler` mixin
- [ ] Aplicar a todos los repositorios
- [ ] Crear mensajes de error localizados

---

## PRIORITY 3: FEATURES STRUCTURE (4 NUEVAS FEATURES)

### CUSTOMERS - Clientes (0% → 100%)

#### Domain
- [ ] Crear entidad `Customer`
- [ ] Crear `CustomerRepository` (interfaz)
- [ ] Crear use cases:
  - [ ] `GetCustomersUseCase`
  - [ ] `GetCustomerByIdUseCase`
  - [ ] `SearchCustomersUseCase`
  - [ ] `CreateCustomerUseCase`
  - [ ] `UpdateCustomerUseCase`
  - [ ] `DeleteCustomerUseCase`

#### Data
- [ ] Crear `CustomerModel`
- [ ] Crear `CustomerRepositoryImpl`
- [ ] Crear `CustomerRemoteDataSource`
- [ ] Crear `CustomerLocalDataSource` (opcional)

#### Presentation
- [ ] Crear `CustomersController`
- [ ] Crear `CustomerFormController`
- [ ] Crear `CustomersPage`
- [ ] Crear `CustomerFormPage`
- [ ] Crear `CustomerDetailPage`
- [ ] Crear widgets: `CustomerCard`, `CustomerSearchWidget`
- [ ] Crear bindings

#### Rutas & DI
- [ ] Agregar rutas a `app_routes.dart`
- [ ] Registrar en `app_pages.dart`
- [ ] Registrar use cases en `injection_container.dart`
- [ ] Crear `CustomersBinding`

### EMPLOYEES - Empleados (0% → 100%)

#### Domain
- [ ] Crear entidad `Employee`
- [ ] Crear `EmployeeRepository` (interfaz)
- [ ] Crear use cases: Get, GetById, Create, Update, Delete, Search

#### Data
- [ ] Crear `EmployeeModel`
- [ ] Crear `EmployeeRepositoryImpl`
- [ ] Crear `EmployeeRemoteDataSource`

#### Presentation
- [ ] Crear `EmployeesController`
- [ ] Crear `EmployeeFormController`
- [ ] Crear `EmployeesPage`, `EmployeeFormPage`, `EmployeeDetailPage`
- [ ] Crear widgets necesarios
- [ ] Crear bindings

#### Rutas & DI
- [ ] Agregar rutas
- [ ] Registrar en app_pages.dart
- [ ] Registrar use cases en injection_container.dart

### INVENTORY - Inventario (0% → 100%)

#### Domain
- [ ] Crear entidades: `InventoryItem`, `StockMovement`
- [ ] Crear `InventoryRepository` (interfaz)
- [ ] Crear use cases: Get, GetById, Adjust, Transfer, History

#### Data
- [ ] Crear modelos
- [ ] Crear `InventoryRepositoryImpl`
- [ ] Crear `InventoryRemoteDataSource`

#### Presentation
- [ ] Crear `InventoryController`
- [ ] Crear `InventoryAdjustmentController`
- [ ] Crear páginas: `InventoryPage`, `InventoryDetailPage`, `AdjustmentPage`
- [ ] Crear widgets necesarios
- [ ] Crear bindings

#### Rutas & DI
- [ ] Agregar rutas
- [ ] Registrar en app_pages.dart
- [ ] Registrar use cases

### RESERVATIONS - Reservaciones (0% → 100%)

#### Domain
- [ ] Crear entidades: `Reservation`
- [ ] Crear `ReservationRepository` (interfaz)
- [ ] Crear use cases: Get, GetById, Create, Update, Delete, Cancel, ByTable

#### Data
- [ ] Crear `ReservationModel`
- [ ] Crear `ReservationRepositoryImpl`
- [ ] Crear `ReservationRemoteDataSource`

#### Presentation
- [ ] Crear `ReservationsController`
- [ ] Crear `ReservationFormController`
- [ ] Crear páginas: `ReservationsPage`, `ReservationFormPage`, `ReservationDetailPage`
- [ ] Crear widgets necesarios
- [ ] Crear bindings

#### Rutas & DI
- [ ] Agregar rutas
- [ ] Registrar en app_pages.dart
- [ ] Registrar use cases

---

## PRIORITY 4: REPORTING & SETTINGS

### REPORTS - Reportes (0% → 100%)

#### Domain
- [ ] Crear entidad `Report`
- [ ] Crear `ReportRepository`
- [ ] Crear use cases:
  - [ ] `GetSalesReportUseCase`
  - [ ] `GetInventoryReportUseCase`
  - [ ] `GetEmployeeReportUseCase`
  - [ ] `GetCustomerReportUseCase`

#### Presentation
- [ ] Crear `ReportsController`
- [ ] Crear páginas: `ReportsPage`, `SalesReportPage`, `InventoryReportPage`, etc.
- [ ] Crear widgets para gráficos y datos

### SETTINGS - Configuración (0% → 100%)

#### Domain
- [ ] Crear entidades: `UserProfile`, `BusinessSettings`, `AppSettings`
- [ ] Crear repositorio
- [ ] Crear use cases

#### Presentation
- [ ] Crear `SettingsController`
- [ ] Crear `ProfileController`
- [ ] Crear páginas necesarias
- [ ] Crear widgets para preferencias

---

## QUALITY ASSURANCE

### Testing
- [ ] Unit tests para todos los use cases
- [ ] Unit tests para todos los controllers
- [ ] Widget tests para páginas principales
- [ ] Integration tests para flujos críticos

### Code Quality
- [ ] 🔧 Ejecutar análisis estática: `dart analyze`
- [ ] 🔧 Aplicar format: `dart format`
- [ ] 🔧 Revisar todas las imports no usadas
- [ ] 🔧 Revisar TODOs en código

### Documentation
- [ ] Documentar arquitectura en README
- [ ] Comentarios JSDoc en clases públicas
- [ ] Guía de contribución para nuevas features

---

## ESTIMATED EFFORT

| Task | Effort | Priority |
|------|--------|----------|
| Use Cases Faltantes (20 total) | 5-6h | Critical |
| Páginas Faltantes (2) | 2-3h | Critical |
| BaseController & BaseFormController | 3-4h | Critical |
| 4 Features Nuevas (CRUD) | 40-50h | High |
| Datasources Locales | 8-10h | Important |
| Testing | 20-30h | Important |
| Reports & Settings | 20-25h | Medium |
| **TOTAL** | **~100-130h** | - |

---

## NEXT STEPS

1. **Semana 1:** Implementar todos los use cases faltantes + refactorización de controllers
2. **Semana 2:** Implementar 4 features nuevas (MVP)
3. **Semana 3:** Datasources locales + Testing
4. **Semana 4:** Reports + Settings + Refinamiento

---

