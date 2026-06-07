import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

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

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.hero,
    this.chips,
    this.horizontalPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
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
        16,
        horizontalPadding,
        hero != null || (chips != null && chips!.isNotEmpty) ? 20 : 18,
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
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (hero != null) ...[
            const SizedBox(height: 14),
            hero!,
          ],
          if (chips != null && chips!.isNotEmpty) ...[
            const SizedBox(height: 12),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
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
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
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
