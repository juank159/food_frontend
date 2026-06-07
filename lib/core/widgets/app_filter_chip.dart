import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

/// Pill seleccionable para filtros inline. Reemplaza al `FilterChip` /
/// `ChoiceChip` de Material que tiene un look anticuado y problemas de
/// contraste (cuando se seleccionan, Material no cambia el color del
/// texto/icono, así que con fondos saturados el texto se vuelve invisible).
///
/// **Contraste garantizado:**
///   - Seleccionado: fondo del color de acento + texto e icono blancos.
///   - No seleccionado: fondo blanco + borde gris + texto/icono oscuro.
///
/// **Color custom:**
/// Si pasás `accentColor` (ej. rojo para "fallido", verde para
/// "completado"), se usa como color de selección. Default: `AppColors.primary`.
///
/// Uso típico dentro de un `ListView` horizontal o `Wrap`.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Color de acento cuando el chip está seleccionado. Si es `null`,
  /// usa `AppColors.primary` (naranja del brand). Usar colores de status
  /// (rojo/verde/ámbar) para filtros tipo "fallido / completado / pendiente".
  final Color? accentColor;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? accent : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? accent : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color:
                        selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
