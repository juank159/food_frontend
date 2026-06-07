# Food Platform App - Development Guidelines

## 📋 Principios de Desarrollo

### 1. **DRY (Don't Repeat Yourself)**
- **SIEMPRE** reutilizar componentes existentes antes de crear nuevos
- **NUNCA** duplicar lógica de negocio
- **USO OBLIGATORIO** de widgets compartidos en `/lib/core/widgets/`:
  - `ModernCard` para todas las tarjetas
  - Componentes de UI compartidos
  - Utilidades comunes

### 2. **Sistema Responsive Global**
- **UBICACIÓN**: `/lib/core/config/responsive_config.dart`
- **USO OBLIGATORIO** en todas las pantallas
- Breakpoints estándar:
  - Mobile: < 600px
  - Tablet: 600px - 900px
  - Desktop: > 900px
  - Large Desktop: > 1200px

### 3. **Arquitectura Limpia**
- Respetar capas: Presentation → Domain → Data
- Nunca saltarse capas
- Usar casos de uso (UseCases) para lógica de negocio
- Repositorios como única fuente de datos

### 4. **Gestión de Estado**
- GetX para state management
- Controllers en capa de presentación
- Bindings para inyección de dependencias
- Lazy loading cuando sea posible

### 5. **Modelos de Datos**
- Todos los modelos deben manejar:
  - Campos opcionales del backend
  - Conversión de tipos (String/int)
  - Null safety
  - Serialización robusta

## 🎨 Componentes Reutilizables

### ModernCard
```dart
ModernCard(
  onTap: () {},
  elevation: 2,
  child: // your content
)
```

### Responsive Helper
```dart
final responsive = ResponsiveConfig(context);
if (responsive.isMobile) { /* mobile layout */ }
if (responsive.isTablet) { /* tablet layout */ }
if (responsive.isDesktop) { /* desktop layout */ }
```

## 📱 Pantallas y Responsive

### Checklist para cada pantalla:
- [ ] Usa ResponsiveConfig
- [ ] Funciona en móvil (< 600px)
- [ ] Funciona en tablet (600-900px)
- [ ] Funciona en desktop (> 900px)
- [ ] No tiene overflow
- [ ] Usa ModernCard para tarjetas
- [ ] Sigue principios DRY

## 🔧 Orden de Rutas en GetX

**CRÍTICO**: Las rutas específicas SIEMPRE deben ir ANTES de las rutas con parámetros:

```dart
// ✅ CORRECTO
GetPage(name: '/orders/create', ...),  // Específica primero
GetPage(name: '/orders/:id', ...),     // Con parámetro después

// ❌ INCORRECTO
GetPage(name: '/orders/:id', ...),     // Captura /create como :id
GetPage(name: '/orders/create', ...),  // Nunca se alcanza
```

## 🐛 Problemas Comunes y Soluciones

### Error: "String is not a subtype of int" o "type 'String' is not a subtype of type 'int' of 'index'"
- **Causa**:
  - Backend envía números como strings
  - Conflicto entre json_serializable y parsing manual
  - Arrays null no manejados correctamente
  - **API incluye campos extra** (ej: `category` object y `variants` array) que el modelo no espera
- **Solución DEFINITIVA**: Parsing manual completo + manejo de campos extra del API
  1. **Eliminar json_serializable**:
     - Remover `import 'package:json_annotation/json_annotation.dart'`
     - Remover `part 'model_name.g.dart'`
     - Remover anotaciones `@JsonSerializable` y `@JsonKey`
     - Eliminar archivo `.g.dart` generado
  2. **Implementar parsing manual**:
     ```dart
     // Helper methods para parsing robusto
     static double _parseDouble(dynamic value) {
       if (value == null) return 0.0;
       if (value is double) return value;
       if (value is int) return value.toDouble();
       if (value is String) return double.tryParse(value) ?? 0.0;
       return 0.0;
     }

     static List<String> _parseStringList(dynamic value) {
       if (value == null) return [];
       if (value is List) return value.map((e) => e.toString()).toList();
       return [];
     }

     factory Model.fromJson(Map<String, dynamic> json) {
       try {
         // Manejar campos que pueden venir anidados o directos
         String categoryId;
         if (json['category_id'] != null) {
           categoryId = json['category_id'] as String;
         } else if (json['category'] != null && json['category'] is Map) {
           categoryId = (json['category'] as Map<String, dynamic>)['id'] as String;
         } else {
           throw FormatException('Missing category_id');
         }

         return Model(
           field: _parseDouble(json['field']),
           tags: _parseStringList(json['tags']),
           categoryId: categoryId,
         );
         // Nota: Campos extra como 'variants' se ignoran automáticamente
       } catch (e, stackTrace) {
         throw FormatException('Error parsing Model: $e\nJSON: $json\nStack: $stackTrace');
       }
     }
     ```
  3. **Limpiar y recompilar**:
     ```bash
     flutter clean
     flutter pub get
     flutter run
     ```

### Overflow en Column/Row
- **Causa**: Contenido excede espacio disponible
- **Solución**:
  - Usar `Expanded` o `Flexible`
  - Añadir `SingleChildScrollView`
  - Ajustar tamaños con ResponsiveConfig

### Ruta incorrecta carga controller equivocado
- **Causa**: Orden incorrecto en app_pages.dart
- **Solución**: Rutas específicas ANTES de parametrizadas

## 📚 Estructura de Carpetas

```
lib/
├── core/
│   ├── config/
│   │   ├── responsive_config.dart
│   │   └── constants/
│   ├── widgets/
│   │   ├── modern_card.dart
│   │   └── ...
│   └── routes/
│       ├── app_pages.dart
│       └── app_routes.dart
├── features/
│   └── [feature]/
│       ├── data/
│       ├── domain/
│       └── presentation/
```

## ✅ Checklist Antes de Commit

- [ ] Código sigue principios DRY
- [ ] No hay duplicación de lógica
- [ ] Usa componentes compartidos (ModernCard, etc.)
- [ ] Responsive en todas las pantallas
- [ ] Sin warnings de overflow
- [ ] Orden correcto de rutas en app_pages.dart
- [ ] Modelos manejan datos opcionales/flexibles
- [ ] Tests actualizados (si aplica)

## 🔄 Workflow de Desarrollo

1. **Planificar**: Revisar componentes existentes
2. **Reutilizar**: Usar widgets compartidos
3. **Responsive**: Aplicar ResponsiveConfig
4. **Testing**: Probar en mobile, tablet, desktop
5. **Review**: Verificar principios DRY
6. **Commit**: Seguir checklist

---

**RECORDATORIO**: Cada vez que implementes algo nuevo, pregúntate:
1. ¿Ya existe un componente para esto?
2. ¿Este código será responsive?
3. ¿Estoy duplicando lógica?
4. ¿Respeta la arquitectura limpia?
