import 'package:flutter/material.dart';

/// Contenedor de íconos moderno con múltiples estilos
/// Reutilizable para todo el app
class IconContainer extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double? iconSize;
  final IconContainerStyle style;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const IconContainer({
    super.key,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.size = 48,
    this.iconSize,
    this.style = IconContainerStyle.rounded,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.primaryColor;
    final effectiveBackgroundColor = backgroundColor ?? effectiveIconColor.withValues(alpha: 0.1);
    final effectiveIconSize = iconSize ?? size * 0.5;

    Widget container = Container(
      width: size,
      height: size,
      decoration: _buildDecoration(effectiveBackgroundColor, theme),
      child: Icon(
        icon,
        size: effectiveIconSize,
        color: gradient != null ? Colors.white : effectiveIconColor,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _getBorderRadius(),
          child: container,
        ),
      );
    }

    return container;
  }

  BoxDecoration _buildDecoration(Color bgColor, ThemeData theme) {
    switch (style) {
      case IconContainerStyle.rounded:
        return BoxDecoration(
          color: gradient == null ? bgColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        );

      case IconContainerStyle.circle:
        return BoxDecoration(
          color: gradient == null ? bgColor : null,
          gradient: gradient,
          shape: BoxShape.circle,
        );

      case IconContainerStyle.soft:
        return BoxDecoration(
          color: gradient == null ? bgColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: (gradient?.colors.first ?? bgColor).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

      case IconContainerStyle.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconColor ?? theme.primaryColor,
            width: 2,
          ),
        );

      case IconContainerStyle.glass:
        return BoxDecoration(
          color: bgColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  BorderRadius? _getBorderRadius() {
    switch (style) {
      case IconContainerStyle.circle:
        return null;
      case IconContainerStyle.soft:
        return BorderRadius.circular(size * 0.25);
      default:
        return BorderRadius.circular(12);
    }
  }
}

enum IconContainerStyle {
  rounded,  // Bordes redondeados estándar
  circle,   // Circular
  soft,     // Bordes muy redondeados con sombra suave
  outlined, // Solo borde sin relleno
  glass,    // Efecto glassmorphism
}

/// Ícono con badge de notificación
class IconContainerWithBadge extends StatelessWidget {
  final IconData icon;
  final String badgeText;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color badgeColor;
  final double size;

  const IconContainerWithBadge({
    super.key,
    required this.icon,
    required this.badgeText,
    this.iconColor,
    this.backgroundColor,
    this.badgeColor = Colors.red,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconContainer(
          icon: icon,
          iconColor: iconColor,
          backgroundColor: backgroundColor,
          size: size,
        ),
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
