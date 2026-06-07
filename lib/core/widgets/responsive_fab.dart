import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

/// Responsive Floating Action Button
///
/// Un FAB que se adapta al tamaño de la pantalla:
/// - En pantallas pequeñas (móviles): muestra solo el icono en FAB circular
/// - En pantallas medianas/grandes: muestra botón rectangular con icono + texto
///
/// Mejora la experiencia del usuario en todos los dispositivos.
class ResponsiveFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool mini;

  /// Ancho mínimo para mostrar el botón extendido (con texto)
  /// Por defecto: 600px (tablets y escritorio)
  final double extendedThreshold;

  const ResponsiveFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.mini = false,
    this.extendedThreshold = 600.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtended = screenWidth >= extendedThreshold;

    // Para pantallas pequeñas (móviles), usar FAB circular con solo icono
    if (!isExtended) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip ?? label,
        backgroundColor: backgroundColor ?? AppColors.primary,
        foregroundColor: foregroundColor ?? AppColors.textOnPrimary,
        elevation: elevation ?? 4,
        mini: mini,
        child: Icon(icon),
      );
    }

    // Para pantallas grandes, usar botón personalizado rectangular
    return Material(
      elevation: elevation ?? 4,
      borderRadius: BorderRadius.circular(28),
      color: backgroundColor ?? AppColors.primary,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          constraints: const BoxConstraints(
            minHeight: 56,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: foregroundColor ?? AppColors.textOnPrimary,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: foregroundColor ?? AppColors.textOnPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
