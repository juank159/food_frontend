import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';

/// Empty state estandarizado con círculo coloreado + icono + título +
/// mensaje + CTA. El círculo grande hace que la pantalla no se sienta
/// vacía sin necesidad de assets PNG.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  /// Color del círculo. Default = primary del brand.
  final Color? accent;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    // Scrollable + ConstrainedBox: centra cuando hay alto de sobra y
    // permite scroll (en vez de overflow) cuando la pantalla es muy baja
    // — ej. modificadores en mobile con poco alto disponible. Antes el
    // `Column` con `mainAxisAlignment.center` no podía achicarse → 11px
    // de overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: Icon(actionIcon ?? Icons.add),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight - 48).clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
