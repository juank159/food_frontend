import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/controllers/home_controller.dart';

/// Reports Hub — pantalla central del módulo de reportes.
///
/// Estructura:
/// 1. Header con gradient + back button + subtítulo.
/// 2. Banda de KPIs ejecutivos del día (reutiliza HomeController si
///    está vivo, o no muestra la banda si no — sin segundo fetch).
/// 3. Sección "Áreas de reporte" — grid responsive con las 4 cards
///    grandes navegando a cada sub-reporte.
/// 4. Sección "Sugerencias" con tips de qué reporte mirar según
///    objetivo del operario (cierre del día, control de stock, etc.).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  /// Breakpoints — alineados con el resto del proyecto.
  /// - <600 px: mobile, grid 2 cols.
  /// - 600-900 px: tablet, grid 3 cols.
  /// - ≥900 px: desktop, grid 4 cols.
  int _gridColumns(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  /// Aspect ratio del card según columnas — más anchos cuanto más
  /// columnas. Evita el problema actual de cards gigantes en wide.
  double _aspectRatio(int columns) {
    if (columns == 4) return 1.05;
    if (columns == 3) return 1.0;
    return 0.95;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _gridColumns(constraints.maxWidth);
                  return SingleChildScrollView(
                    // Padding lateral generoso en wide para que el
                    // contenido respire pero usando el ancho completo
                    // — sin Center+ConstrainedBox que diluía la
                    // experiencia.
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth >= 900 ? 32 : 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKpiBand(),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Áreas de reporte',
                          subtitle:
                              'Tap en una para ver el detalle completo',
                        ),
                        const SizedBox(height: 12),
                        _buildReportsGrid(cols),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Sugerencias'),
                        const SizedBox(height: 12),
                        _buildTipsList(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── Header ────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: 'Reportes',
      subtitle: 'Análisis del negocio en un vistazo',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── KPI Band ───────────────────────────

  /// Banda de KPIs del día. Reutiliza el HomeController si está vivo.
  /// Si el usuario llegó directo a /reports sin pasar por home, no
  /// muestra la banda (evitamos un segundo fetch innecesario).
  Widget _buildKpiBand() {
    if (!Get.isRegistered<HomeController>()) {
      return const SizedBox.shrink();
    }
    final home = Get.find<HomeController>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Banda horizontal en wide, 2x2 en mobile.
          final wide = constraints.maxWidth >= 700;
          final tiles = [
            _KpiTile(
              icon: Icons.payments_outlined,
              label: 'Ventas hoy',
              accent: AppColors.success,
              valueBuilder: () =>
                  CurrencyFormatter.format(home.totalSalesToday),
              hintBuilder: () => home.salesDeltaLabel,
            ),
            _KpiTile(
              icon: Icons.receipt_long_outlined,
              label: 'Órdenes activas',
              accent: AppColors.primary,
              valueBuilder: () => home.activeOrders.toString(),
            ),
            _KpiTile(
              icon: Icons.chair_outlined,
              label: 'Ocupación',
              accent: AppColors.warning,
              valueBuilder: () => home.tablesOccupancyLabel,
            ),
            _KpiTile(
              icon: Icons.people_alt_outlined,
              label: 'Clientes',
              accent: AppColors.info,
              valueBuilder: () => home.totalCustomers.toString(),
            ),
          ];
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 48,
                      color: AppColors.divider,
                    ),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          }
          return Column(
            children: [
              Row(children: [
                Expanded(child: tiles[0]),
                Container(width: 1, height: 48, color: AppColors.divider),
                Expanded(child: tiles[1]),
              ]),
              const Divider(height: 20, color: AppColors.divider),
              Row(children: [
                Expanded(child: tiles[2]),
                Container(width: 1, height: 48, color: AppColors.divider),
                Expanded(child: tiles[3]),
              ]),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────── Section title ──────────────────────────

  Widget _buildSectionTitle(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────── Reports grid ───────────────────────────

  Widget _buildReportsGrid(int columns) {
    final tiles = <_ReportTile>[
      _ReportTile(
        title: 'Ventas',
        subtitle: 'Facturación, ticket y órdenes',
        icon: Icons.trending_up,
        accent: AppColors.primary,
        onTap: () => Get.toNamed(AppRoutes.salesReport),
      ),
      _ReportTile(
        title: 'Inventario',
        subtitle: 'Stock crítico y movimientos',
        icon: Icons.warehouse_outlined,
        accent: AppColors.info,
        onTap: () => Get.toNamed(AppRoutes.inventoryReport),
      ),
      _ReportTile(
        title: 'Empleados',
        subtitle: 'Turnos y desempeño',
        icon: Icons.group_outlined,
        accent: AppColors.accent,
        onTap: () => Get.toNamed(AppRoutes.employeeReport),
      ),
      _ReportTile(
        title: 'Clientes',
        subtitle: 'Top compradores y frecuencia',
        icon: Icons.people_outline,
        accent: AppColors.secondary,
        onTap: () => Get.toNamed(AppRoutes.customerReport),
      ),
    ];
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: _aspectRatio(columns),
      children: tiles,
    );
  }

  // ────────────────────────── Tips ────────────────────────────────

  Widget _buildTipsList() {
    final tips = [
      (
        Icons.lightbulb_outline,
        'Resumen del día',
        'En Ventas elegí el rango "Hoy" para ver facturación, ticket promedio y órdenes del día.',
        AppColors.warning,
      ),
      (
        Icons.inventory_2_outlined,
        'Stock bajo',
        'Revisá Inventario antes de abrir para reabastecer productos con alerta mínima.',
        AppColors.info,
      ),
      (
        Icons.workspace_premium_outlined,
        'Top empleados',
        'En Empleados encontrás quién atendió más órdenes y vendió más en el mes.',
        AppColors.accent,
      ),
    ];
    return Column(
      children: [
        for (final tip in tips) ...[
          _TipRow(
            icon: tip.$1,
            title: tip.$2,
            message: tip.$3,
            accent: tip.$4,
          ),
          if (tip != tips.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ──────────────────────────── KpiTile ────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final String Function() valueBuilder;
  final String Function()? hintBuilder;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.valueBuilder,
    this.hintBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Suscribimos al observable `isLoadingStats` para que el Obx
      // reaccione cuando el HomeController termina de cargar y los
      // builders de value/hint devuelvan los valores actualizados.
      // Sin esta lectura explícita, el builder no re-ejecuta.
      final loading = Get.find<HomeController>().isLoadingStats;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loading ? '—' : valueBuilder(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hintBuilder != null && !loading) ...[
                    const SizedBox(height: 1),
                    Text(
                      hintBuilder!(),
                      style: TextStyle(
                        fontSize: 10,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ──────────────────────────── ReportTile ─────────────────────────

class _ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Ver',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward, size: 13, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── TipRow ────────────────────────────

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const _TipRow({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
