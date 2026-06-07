# Guía de Tematización - Floor Plan Editor

## Introducción

Esta guía documenta las mejores prácticas para mantener la consistencia de temas en el Floor Plan Editor. Como esta es una aplicación multi-tenant, **NUNCA debemos usar colores fijos (hardcoded)**. Siempre debemos usar `Theme.of(context)` para acceder a los colores del tema actual.

## Reglas Fundamentales

### ❌ NUNCA Hacer
```dart
// ❌ Colores hardcoded
Colors.blue.shade700
Colors.white
Colors.grey[600]
const Color(0xFF7FB3D5)

// ❌ Estilos hardcoded
TextStyle(color: Colors.black, fontSize: 16)
```

### ✅ SIEMPRE Hacer
```dart
// ✅ Usar tema
final theme = Theme.of(context);
theme.colorScheme.primary
theme.colorScheme.onPrimary
theme.textTheme.titleLarge

// ✅ Usar estilos del tema
theme.textTheme.bodyLarge?.copyWith(fontSize: 16)
```

## Mapeo de Colores

### Colores de Fondo
```dart
// Fondo de diálogos
theme.dialogBackgroundColor

// Fondo de superficie (cards, containers)
theme.colorScheme.surface

// Fondo de pantalla
theme.scaffoldBackgroundColor
```

### Colores Primarios y Secundarios
```dart
// Color principal de la marca
theme.colorScheme.primary

// Color secundario de la marca
theme.colorScheme.secondary

// Color terciario
theme.colorScheme.tertiary

// Texto sobre colores primarios
theme.colorScheme.onPrimary

// Texto sobre colores secundarios
theme.colorScheme.onSecondary
```

### Colores de Texto
```dart
// Texto sobre superficie
theme.colorScheme.onSurface

// Texto variante/secundario
theme.colorScheme.onSurfaceVariant

// Color de error
theme.colorScheme.error
```

### Colores de Bordes y Divisores
```dart
// Divisores (líneas separadoras)
theme.dividerColor

// Bordes (outline)
theme.colorScheme.outline

// Sombras
theme.shadowColor
```

## Estilos de Texto

### Títulos
```dart
// Título grande (dialogs, headers)
theme.textTheme.titleLarge?.copyWith(
  color: theme.colorScheme.onPrimary,
  fontWeight: FontWeight.bold,
)

// Título mediano
theme.textTheme.titleMedium

// Título pequeño
theme.textTheme.titleSmall
```

### Cuerpo de Texto
```dart
// Texto grande
theme.textTheme.bodyLarge

// Texto mediano (más común)
theme.textTheme.bodyMedium

// Texto pequeño
theme.textTheme.bodySmall
```

### Labels
```dart
// Label grande
theme.textTheme.labelLarge

// Label mediano
theme.textTheme.labelMedium

// Label pequeño
theme.textTheme.labelSmall
```

## Ejemplos de Implementación

### Dialog Header con Gradiente
```dart
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
        Icons.icon_name,
        color: theme.colorScheme.onPrimary,
        size: isMobile ? 28 : 32,
      ),
      Text(
        'Título',
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
)
```

### Card con Bordes Temáticos
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: theme.colorScheme.outline,
      width: 2,
    ),
    color: theme.colorScheme.surface,
    boxShadow: [
      BoxShadow(
        color: theme.shadowColor.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)
```

### TextField con Tema
```dart
TextField(
  style: theme.textTheme.bodyLarge?.copyWith(
    fontSize: isMobile ? 15 : 16,
  ),
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

## Archivos Actualizados

Los siguientes archivos ya están correctamente tematizados:

1. ✅ `icon_selector_dialog.dart`
2. ✅ `table_selector_dialog.dart`
3. ✅ `floor_plan_editor_page.dart` (TextInputDialog)

## Archivos Pendientes de Revisión

Los siguientes archivos pueden contener colores hardcoded y deben ser revisados:

- `floor_plan_canvas_painter.dart` - Colores de estados de mesa (available, occupied, reserved, etc.)
- Cualquier otro widget personalizado en la feature

## Consideraciones Especiales

### Colores de Estado de Mesas

Los colores de estado de las mesas (disponible, ocupada, reservada) actualmente están hardcoded. Deberían definirse en el ColorScheme extendido o usando colores semánticos del tema:

```dart
// Opción 1: Usar colores semánticos existentes
case 'available':
  color = theme.colorScheme.surfaceVariant; // o un color suave
case 'occupied':
  color = theme.colorScheme.error; // rojo para ocupado
case 'reserved':
  color = theme.colorScheme.tertiary; // color terciario

// Opción 2: Extender ColorScheme (recomendado)
// Definir en app_theme.dart colores específicos para estados
```

### Responsive Design

Siempre combinar el uso de temas con diseño responsive:

```dart
final theme = Theme.of(context);
final screenSize = MediaQuery.of(context).size;
final isMobile = screenSize.width < 600;
final isSmallMobile = screenSize.width < 360;

// Usar tanto theme como breakpoints
fontSize: isSmallMobile ? 14 : (isMobile ? 16 : 18)
```

## Testing de Temas

Para verificar que la tematización funciona correctamente:

1. Cambiar el tema en la configuración del tenant
2. Verificar que todos los colores cambien acorde al nuevo tema
3. Verificar que no haya colores que permanezcan fijos
4. Probar en modo claro y oscuro (si aplica)

## Mantenimiento Futuro

Al agregar nuevos widgets o dialogs:

1. **NUNCA** usar `Colors.*` directamente
2. **SIEMPRE** obtener `final theme = Theme.of(context)`
3. **USAR** `theme.colorScheme.*` y `theme.textTheme.*`
4. **DOCUMENTAR** cualquier excepción justificada

---

Última actualización: 2025-11-05
Autor: Claude Code Assistant
