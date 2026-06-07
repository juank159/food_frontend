import 'package:flutter/material.dart';

/// Card moderna con glassmorphism y sombras suaves
/// Reutilizable para todo el app
///
/// Características:
/// - Glassmorphism opcional
/// - Degradados personalizables
/// - Sombras adaptativas según elevación
/// - Responsive y accesible
class ModernCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;
  final bool enableGlassmorphism;
  final double? width;
  final double? height;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.elevation,
    this.backgroundColor,
    this.gradient,
    this.borderRadius,
    this.border,
    this.enableGlassmorphism = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBorderRadius = borderRadius ?? BorderRadius.circular(16);
    final effectiveElevation = elevation ?? 2;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? (backgroundColor ?? theme.cardColor)
            : null,
        borderRadius: defaultBorderRadius,
        border: border,
        boxShadow: _buildShadows(effectiveElevation, theme),
      ),
      child: child,
    );

    if (enableGlassmorphism) {
      content = ClipRRect(
        borderRadius: defaultBorderRadius,
        child: BackdropFilter(
          filter: ColorFilter.mode(
            Colors.white.withValues(alpha: 0.1),
            BlendMode.overlay,
          ),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: defaultBorderRadius as BorderRadius?,
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: content,
    );
  }

  List<BoxShadow> _buildShadows(double elevation, ThemeData theme) {
    if (elevation == 0) return [];

    final isDark = theme.brightness == Brightness.dark;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.08);

    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: elevation * 4,
        offset: Offset(0, elevation * 2),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.5),
        blurRadius: elevation * 2,
        offset: Offset(0, elevation),
        spreadRadius: -1,
      ),
    ];
  }
}

/// Card con gradiente para acciones destacadas
class GradientCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<Color>? gradientColors;
  final AlignmentGeometry? gradientBegin;
  final AlignmentGeometry? gradientEnd;

  const GradientCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.gradientColors,
    this.gradientBegin,
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColors = gradientColors ?? [
      theme.primaryColor,
      theme.primaryColor.withValues(alpha: 0.7),
    ];

    return ModernCard(
      onTap: onTap,
      padding: padding,
      margin: margin,
      gradient: LinearGradient(
        colors: defaultColors,
        begin: gradientBegin ?? Alignment.topLeft,
        end: gradientEnd ?? Alignment.bottomRight,
      ),
      child: child,
    );
  }
}

/// Card con efecto hover para desktop/web
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final double hoverElevation;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.elevation,
    this.hoverElevation = 8,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: ModernCard(
          onTap: widget.onTap,
          padding: widget.padding,
          margin: widget.margin,
          elevation: _isHovering
              ? widget.hoverElevation
              : (widget.elevation ?? 2),
          child: widget.child,
        ),
      ),
    );
  }
}
