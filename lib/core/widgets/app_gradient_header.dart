import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/responsive_config.dart';
import '../config/theme/app_colors.dart';
import '../routes/app_routes.dart';

/// Header con gradient redondeado que estandariza la "cabeza" de las
/// pantallas principales (Dashboard, Órdenes, Productos, Planos…).
///
/// Pensado para que cada pantalla se sienta del mismo "edificio":
///
///   - Gradient naranja del brand → identidad visual instantánea.
///   - Esquinas inferiores redondeadas → continuidad con el contenido.
///   - Slot opcional para un KPI hero abajo y/o una fila de chips de stats.
///
/// Uso típico:
/// ```dart
/// AppGradientHeader(
///   title: 'Órdenes',
///   subtitle: 'Resumen de hoy',
///   trailing: IconButton(...),
///   hero: AppKpiHero(...),
///   chips: [AppKpiChip(...), AppKpiChip(...)],
/// )
/// ```
class AppGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Widget grande debajo del título — típicamente el KPI principal del día.
  final Widget? hero;

  /// Fila de chips compactos abajo del hero. Se reparten con `Expanded`.
  final List<Widget>? chips;

  /// Espaciado horizontal interno. Default 20 — coincide con la mayoría
  /// de las pantallas.
  final double horizontalPadding;

  /// Si se pasa, el título se vuelve tappable y muestra un ícono de edición.
  final VoidCallback? onTitleTap;

  /// Controla si se muestra el botón de back auto-generado cuando NO se
  /// pasa `leading`:
  /// - `null` (default): auto. Muestra back si la pantalla NO es root
  ///   del Home (`/home`, `/home/*`) y hay una ruta previa en la pila.
  /// - `true`: siempre muestra back (override manual).
  /// - `false`: nunca muestra back (útil para tabs internas del Home
  ///   donde el bottom nav ya cubre la navegación).
  final bool? showBackButton;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.hero,
    this.chips,
    this.horizontalPadding = 20,
    this.showBackButton,
    this.onTitleTap,
  });

  /// Decide si renderizar el back button automático. Lógica:
  /// 1. Si el caller pasó `leading` → respeta su decisión (no overrideamos).
  /// 2. Si `showBackButton` es bool explícito → respeta ese valor.
  /// 3. Si `showBackButton == null` (auto) → muestra back cuando:
  ///    - La ruta actual NO es `/home` ni un sub-tab del Home (`/home/...`)
  ///    - Hay una ruta anterior en la pila de navegación.
  bool _shouldAutoBackButton() {
    if (leading != null) return false;
    if (showBackButton == true) return true;
    if (showBackButton == false) return false;
    // Auto-detección.
    final current = Get.currentRoute;
    final isHomeTab =
        current == AppRoutes.home || current.startsWith('${AppRoutes.home}/');
    if (isHomeTab) return false;
    return Get.previousRoute.isNotEmpty;
  }

  void _handleBack() {
    if (Get.previousRoute.isNotEmpty) {
      Get.back();
    } else {
      // Fallback: usuario llegó por deep link y no hay back stack.
      Get.offAllNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bug real reportado: en laptop/desktop (mouse, no dedo, y sin la
    // distancia de un celular contra la cara) este header — pensado y
    // medido para mobile — se ve desproporcionadamente grande. Todo lo
    // de abajo se achica un poco SOLO en desktop; mobile/tablet quedan
    // exactamente igual que antes.
    final isCompact = ResponsiveConfig(context).isDesktop;
    final titleSize = isCompact ? 16.0 : 20.0;
    final subtitleSize = isCompact ? 11.0 : 12.0;
    final vTopPad = isCompact ? 10.0 : 16.0;
    final vBottomPad = isCompact
        ? (hero != null || (chips != null && chips!.isNotEmpty) ? 14.0 : 12.0)
        : (hero != null || (chips != null && chips!.isNotEmpty) ? 20.0 : 18.0);
    final backButtonSize = isCompact ? 32.0 : 40.0;
    final backIconSize = isCompact ? 16.0 : 20.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        vTopPad,
        horizontalPadding,
        vBottomPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ] else if (_shouldAutoBackButton()) ...[
                _AutoBackButton(
                  onTap: _handleBack,
                  size: backButtonSize,
                  iconSize: backIconSize,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: onTitleTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (onTitleTap != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit_outlined,
                              color: Colors.white60,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: subtitleSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (hero != null) ...[
            SizedBox(height: isCompact ? 10 : 14),
            hero!,
          ],
          if (chips != null && chips!.isNotEmpty) ...[
            SizedBox(height: isCompact ? 8 : 12),
            Row(
              children: [
                for (var i = 0; i < chips!.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: chips![i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón de back con el mismo estilo translúcido que usan otras pantallas
/// (`OrderDetailPage`, `QrTokensPage`, etc.). Se inyecta automáticamente
/// en `AppGradientHeader` cuando no hay `leading` custom y la pantalla
/// no es root del Home.
class _AutoBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  const _AutoBackButton({
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}

/// Card grande translúcida sobre el gradient — para el KPI principal de
/// la pantalla (ventas del día, total de planos, etc).
class AppKpiHero extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  const AppKpiHero({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveConfig(context).isDesktop;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 7 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: isCompact ? 16 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                // FittedBox: montos grandes ("$1.250.000") se achican en
                // vez de envolver a 2 líneas o desbordar.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 18 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat compacto translúcido — fila de KPIs secundarios sobre el gradient.
class AppKpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const AppKpiChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveConfig(context).isDesktop;
    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isCompact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: isCompact ? 13 : 16, color: Colors.white),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 16,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isCompact ? 9 : 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
    );
  }
}
