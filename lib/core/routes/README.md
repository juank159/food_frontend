# Sistema de Rutas Profesional - Food Platform App

Este directorio contiene el sistema de rutas profesional y escalable de la aplicación.

## 📂 Estructura de Archivos

```
lib/core/routes/
├── app_routes.dart        # Constantes de nombres de rutas
├── app_pages.dart          # Configuración de GetPages con bindings
├── route_guards.dart       # Middlewares de autenticación y autorización
├── navigation_service.dart # Servicio de navegación type-safe
└── README.md              # Esta documentación
```

## 🎯 Características

✅ **Type-Safe Navigation** - Métodos con tipado fuerte
✅ **Constantes Centralizadas** - Sin magic strings
✅ **Middlewares de Autenticación** - AuthGuard, RoleGuard, PermissionGuard
✅ **Rutas Organizadas** - Por módulos de negocio
✅ **Fácil Mantenimiento** - Código limpio y documentado
✅ **Prevención de Errores** - Autocompletado en IDE

---

## 📖 Uso

### 1. Navegación Básica

```dart
import 'package:food_platform_app/core/routes/navigation_service.dart';

// Navegar a una ruta
NavigationService.toProducts();

// Navegar y limpiar el stack
NavigationService.toHome(clearStack: true);

// Navegar con ID
NavigationService.toProductDetail('product-123');

// Regresar
NavigationService.back();
```

### 2. Usar Constantes de Rutas

```dart
import 'package:food_platform_app/core/routes/app_routes.dart';

// En lugar de usar strings
Get.toNamed('/products');  // ❌ No recomendado

// Usa constantes
Get.toNamed(AppRoutes.products);  // ✅ Recomendado

// O mejor aún, usa NavigationService
NavigationService.toProducts();  // ✅✅ Mejor opción
```

### 3. Construir Rutas Dinámicas

```dart
// Rutas con parámetros
final route = AppRoutes.buildProductDetail('123');
// Resultado: '/products/123'

final editRoute = AppRoutes.buildEditOrder('456');
// Resultado: '/orders/456/edit'
```

---

## 🔐 Guards y Middlewares

### AuthGuard

Protege rutas que requieren autenticación:

```dart
GetPage(
  name: AppRoutes.orders,
  page: () => OrdersScreen(),
  middlewares: [AuthGuard()],  // Solo usuarios autenticados
),
```

### RoleGuard

Protege rutas por roles específicos:

```dart
GetPage(
  name: AppRoutes.employeesList,
  page: () => EmployeesScreen(),
  middlewares: [
    AuthGuard(),
    RoleGuard(requiredRoles: ['TENANT_OWNER', 'ADMIN']),
  ],
),
```

### PermissionGuard

Protege rutas por permisos específicos:

```dart
GetPage(
  name: AppRoutes.businessSettings,
  page: () => BusinessSettingsScreen(),
  middlewares: [
    AuthGuard(),
    PermissionGuard(requiredPermissions: ['MANAGE_SETTINGS']),
  ],
),
```

### GuestGuard

Protege rutas que solo pueden ser accedidas por usuarios NO autenticados:

```dart
GetPage(
  name: AppRoutes.login,
  page: () => LoginScreen(),
  middlewares: [GuestGuard()],  // Redirige a home si está logueado
),
```

---

## 🗺️ Rutas Disponibles

### Autenticación
- `/splash` - Pantalla de splash
- `/login` - Inicio de sesión
- `/register` - Registro de usuario
- `/forgot-password` - Recuperar contraseña
- `/reset-password` - Restablecer contraseña

### Principal
- `/home` - Pantalla principal
- `/dashboard` - Dashboard con estadísticas

### Órdenes
- `/orders` - Lista de órdenes
- `/orders/:id` - Detalle de orden
- `/orders/create` - Crear orden
- `/orders/:id/edit` - Editar orden

### Productos
- `/products` - Lista de productos
- `/products/:id` - Detalle de producto
- `/products/create` - Crear producto
- `/products/:id/edit` - Editar producto

### Categorías
- `/categories` - Lista de categorías
- `/categories/create` - Crear categoría
- `/categories/:id/edit` - Editar categoría

### Mesas
- `/tables` - Lista de mesas
- `/tables/:id` - Detalle de mesa
- `/tables/layout` - Vista del layout de mesas
- `/tables/create` - Crear mesa

### Clientes
- `/customers` - Lista de clientes
- `/customers/:id` - Detalle de cliente
- `/customers/create` - Crear cliente

### Empleados
- `/employees` - Lista de empleados
- `/employees/:id` - Detalle de empleado
- `/employees/create` - Crear empleado

### Reportes
- `/reports` - Listado de reportes
- `/reports/sales` - Reporte de ventas
- `/reports/inventory` - Reporte de inventario

### Configuración
- `/settings` - Configuración general
- `/settings/profile` - Perfil de usuario
- `/settings/change-password` - Cambiar contraseña
- `/settings/business` - Configuración del negocio
- `/settings/printer` - Configuración de impresora

### Inventario
- `/inventory` - Lista de inventario
- `/inventory/:id` - Detalle de inventario
- `/inventory/adjustment` - Ajuste de inventario

### Reservaciones
- `/reservations` - Lista de reservaciones
- `/reservations/:id` - Detalle de reservación
- `/reservations/create` - Crear reservación

---

## 📝 Agregar una Nueva Ruta

### Paso 1: Agregar constante en `app_routes.dart`

```dart
class AppRoutes {
  // ...
  static const String myNewFeature = '/my-feature';
  static const String myFeatureDetail = '/my-feature/:id';

  // Helper method
  static String buildMyFeatureDetail(String id) => '/my-feature/$id';
}
```

### Paso 2: Configurar página en `app_pages.dart`

```dart
class AppPages {
  static final List<GetPage> pages = [
    // ...
    GetPage(
      name: AppRoutes.myNewFeature,
      page: () => MyFeatureScreen(),
      binding: MyFeatureBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
  ];
}
```

### Paso 3: Agregar método en `navigation_service.dart`

```dart
class NavigationService {
  // ...

  /// Navega a mi nueva feature
  static Future<T?>? toMyFeature<T>() {
    return Get.toNamed<T>(AppRoutes.myNewFeature);
  }

  /// Navega al detalle de mi feature
  static Future<T?>? toMyFeatureDetail<T>(String id) {
    return Get.toNamed<T>(AppRoutes.buildMyFeatureDetail(id));
  }
}
```

### Paso 4: Usar en tu código

```dart
// En cualquier parte de tu app
NavigationService.toMyFeature();

// Con parámetros
NavigationService.toMyFeatureDetail('123');
```

---

## 🛡️ Mejores Prácticas

### ✅ DO

```dart
// Usar NavigationService
NavigationService.toProducts();

// Usar constantes de AppRoutes
Get.toNamed(AppRoutes.products);

// Construir rutas dinámicas con helpers
final route = AppRoutes.buildProductDetail(productId);

// Verificar si se puede regresar
if (NavigationService.canGoBack()) {
  NavigationService.back();
}
```

### ❌ DON'T

```dart
// NO usar strings hardcodeados
Get.toNamed('/products');  // ❌

// NO construir rutas manualmente
Get.toNamed('/products/$productId');  // ❌

// NO usar Get.back() directamente
Get.back();  // ❌ Usar NavigationService.back()
```

---

## 🔄 Transiciones Personalizadas

Puedes personalizar transiciones por ruta:

```dart
GetPage(
  name: AppRoutes.createOrder,
  page: () => CreateOrderScreen(),
  transition: Transition.rightToLeft,  // Slide desde la derecha
  transitionDuration: Duration(milliseconds: 300),
),
```

Transiciones disponibles:
- `Transition.fade`
- `Transition.rightToLeft`
- `Transition.leftToRight`
- `Transition.upToDown`
- `Transition.downToUp`
- `Transition.cupertino` (estilo iOS)
- `Transition.zoom`

---

## 📊 Debugging

### Ver ruta actual

```dart
final currentRoute = NavigationService.currentRoute;
print('Ruta actual: $currentRoute');
```

### Logging automático

El `NavigationLoggerMiddleware` registra automáticamente todas las navegaciones:

```
🧭 Navegando a: /products
📄 Página llamada: /products
```

---

## 🚀 Ventajas de esta Arquitectura

1. **Mantenibilidad** - Todas las rutas en un solo lugar
2. **Escalabilidad** - Fácil agregar nuevas rutas
3. **Seguridad** - Middlewares de autenticación y autorización
4. **Type-Safety** - Prevención de errores en tiempo de compilación
5. **Testabilidad** - Fácil de mockear para tests
6. **Documentación** - Código autodocumentado
7. **Performance** - Lazy loading con bindings
8. **Developer Experience** - Autocompletado en IDE

---

## 📚 Recursos Adicionales

- [GetX Documentation](https://pub.dev/packages/get)
- [Flutter Navigation](https://flutter.dev/docs/development/ui/navigation)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

**Autor:** Claude Code
**Versión:** 1.0.0
**Fecha:** 2025-11-02
