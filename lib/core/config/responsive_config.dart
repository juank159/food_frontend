import 'package:flutter/material.dart';

/// Responsive Configuration
/// Sistema global para manejar diseño responsive en toda la aplicación
///
/// USO:
/// ```dart
/// final responsive = ResponsiveConfig(context);
/// if (responsive.isMobile) {
///   // Mobile layout
/// } else if (responsive.isTablet) {
///   // Tablet layout
/// } else {
///   // Desktop layout
/// }
/// ```
class ResponsiveConfig {
  final BuildContext context;

  ResponsiveConfig(this.context);

  /// Breakpoints estándar
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Ancho actual de la pantalla
  double get width => MediaQuery.of(context).size.width;

  /// Alto actual de la pantalla
  double get height => MediaQuery.of(context).size.height;

  /// ¿Es móvil? (< 600px)
  bool get isMobile => width < mobileBreakpoint;

  /// ¿Es tablet? (600px - 900px)
  bool get isTablet => width >= mobileBreakpoint && width < tabletBreakpoint;

  /// ¿Es desktop? (> 900px)
  bool get isDesktop => width >= tabletBreakpoint;

  /// ¿Es desktop grande? (> 1200px)
  bool get isLargeDesktop => width >= desktopBreakpoint;

  /// ¿Es pantalla pequeña? (móvil o tablet)
  bool get isSmallScreen => width < tabletBreakpoint;

  /// Orientación de la pantalla
  Orientation get orientation => MediaQuery.of(context).orientation;

  /// ¿Es orientación vertical?
  bool get isPortrait => orientation == Orientation.portrait;

  /// ¿Es orientación horizontal?
  bool get isLandscape => orientation == Orientation.landscape;

  /// Obtiene el padding de seguridad (notch, barra de navegación, etc.)
  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  /// Obtiene el spacing adaptativo según el tamaño de pantalla
  double get spacing {
    if (isMobile) return 8.0;
    if (isTablet) return 12.0;
    return 16.0;
  }

  /// Obtiene el padding adaptativo según el tamaño de pantalla
  double get padding {
    if (isMobile) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }

  /// Obtiene el número de columnas para grids según el tamaño de pantalla
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    if (isLargeDesktop) return 4;
    return 3;
  }

  /// Obtiene el número de columnas personalizado para grids
  int getGridColumns({
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int largeDesktop = 4,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    if (isLargeDesktop) return largeDesktop;
    return desktop;
  }

  /// Obtiene un valor específico según el tamaño de pantalla
  T value<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    if (isLargeDesktop && largeDesktop != null) return largeDesktop;
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Obtiene el tamaño de fuente adaptativo
  double getFontSize(double baseSize) {
    if (isMobile) return baseSize * 0.9;
    if (isTablet) return baseSize;
    return baseSize * 1.1;
  }

  /// Obtiene el tamaño de icono adaptativo
  double getIconSize(double baseSize) {
    if (isMobile) return baseSize * 0.9;
    if (isTablet) return baseSize;
    return baseSize * 1.1;
  }

  /// Obtiene el ancho máximo para contenido centrado
  double get maxContentWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 800;
    return 1200;
  }

  /// Crea un container con ancho máximo responsivo
  Widget constrainedContent({
    required Widget child,
    double? maxWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? maxContentWidth,
        ),
        child: child,
      ),
    );
  }

  /// Obtiene el cross axis count para GridView según el ancho
  int getCrossAxisCount({
    double itemWidth = 200,
    double spacing = 12,
  }) {
    final availableWidth = width - (padding * 2);
    final count = (availableWidth / (itemWidth + spacing)).floor();
    return count.clamp(1, 6);
  }

  /// Obtiene el child aspect ratio para GridView según el tipo de pantalla
  double getChildAspectRatio({
    double mobile = 0.75,
    double tablet = 0.8,
    double desktop = 0.85,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    return desktop;
  }
}

/// Extension para acceder rápidamente a ResponsiveConfig
extension ResponsiveExtension on BuildContext {
  ResponsiveConfig get responsive => ResponsiveConfig(this);
}

/// Widget builder responsive
/// Permite construir diferentes widgets según el tamaño de pantalla
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveConfig config) mobile;
  final Widget Function(BuildContext context, ResponsiveConfig config)? tablet;
  final Widget Function(BuildContext context, ResponsiveConfig config)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final config = ResponsiveConfig(context);

    if (config.isDesktop && desktop != null) {
      return desktop!(context, config);
    }

    if (config.isTablet && tablet != null) {
      return tablet!(context, config);
    }

    return mobile(context, config);
  }
}

/// Layout responsivo con diferentes configuraciones
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: (context, config) => mobile,
      tablet: tablet != null ? (context, config) => tablet! : null,
      desktop: desktop != null ? (context, config) => desktop! : null,
    );
  }
}
