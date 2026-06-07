import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

/// Barra de acción principal — el patrón canónico del proyecto para
/// "crear nuevo X" en una pantalla de listado.
///
/// **Por qué este widget en vez de `FloatingActionButton.extended`:**
/// El FAB.extended trunca / desborda con labels largos en mobile (el
/// ancho del FAB es limitado al contenido natural pero el texto +
/// icono puede pasarse del área tocable). Además compite visualmente
/// con el contenido al flotar sobre las cards.
///
/// Este widget se usa como `bottomNavigationBar` del Scaffold:
/// - Ancho completo del viewport, sin truncado.
/// - SafeArea aplicada automáticamente (evita el home indicator).
/// - Mismo lenguaje visual en mobile/tablet/desktop.
/// - Tooltip implícito vía label visible.
///
/// **Uso:**
/// ```dart
/// Scaffold(
///   body: ...,
///   bottomNavigationBar: AppPrimaryActionBar(
///     label: 'Nueva orden',
///     icon: Icons.add,
///     onPressed: () => NavigationService.toCreateOrder(),
///   ),
/// );
/// ```
class AppPrimaryActionBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Color de fondo. Por defecto `AppColors.primary`. Para acciones
  /// destructivas (eliminar/anular) se puede pasar `AppColors.error`,
  /// y para acciones de éxito (confirmar cierre) `AppColors.success`.
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Estado de procesamiento — muestra un spinner en vez del icono y
  /// deshabilita el botón. Útil para evitar doble submit.
  final bool isLoading;

  /// Padding lateral del contenedor. Default 16 — alineado con el
  /// padding estándar del proyecto. Bajarlo a 0 si el caller ya envuelve
  /// el botón en un container con padding propio.
  final double horizontalPadding;

  const AppPrimaryActionBar({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? Colors.white;
    final disabled = onPressed == null || isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          12,
        ),
        child: FilledButton.icon(
          onPressed: disabled ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            // `minimumSize` con `double.infinity` hace que ocupe el
            // ancho del padre — el FilledButton no lo hace por default.
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
