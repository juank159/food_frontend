// lib/features/tables/presentation/pages/floor_plans_list_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
import '../../domain/entities/floor_plan.dart';
import '../../domain/entities/floor_plan_element.dart';
import '../controllers/floor_plans_list_controller.dart';

/// Listado de planos de mesas — pantalla que carga al ir a `/tables`.
///
/// Header gradient con KPIs (cantidad de planos + mesas totales) →
/// grid/lista de cards de planos → empty state moderno → FAB extendido
/// para crear el primer plano.
class FloorPlansListPage extends GetView<FloorPlansListController> {
  const FloorPlansListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      // Cuando hay planos, FAB simple solo con icono. Cuando no hay,
      // barra ancha en el bottomNavigationBar con label — más
      // prominente y sin riesgo de truncado del label en mobile.
      floatingActionButton: Obx(() {
        if (controller.floorPlans.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          // heroTag único — esta pantalla puede convivir con otras que
          // tienen FAB dentro del IndexedStack del HomeScreen (mesero
          // ve Órdenes + Mesas a la vez). Sin tag explícito ambos
          // comparten "<default tag>" y Flutter tira un assert.
          heroTag: 'floor-plans-list-fab',
          onPressed: controller.createNewFloorPlan,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Nuevo plano',
          child: const Icon(Icons.add),
        );
      }),
      bottomNavigationBar: Obx(() {
        if (controller.floorPlans.isNotEmpty) return const SizedBox.shrink();
        return AppPrimaryActionBar(
          label: 'Nuevo plano',
          icon: Icons.add,
          onPressed: controller.createNewFloorPlan,
        );
      }),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      final stats = _calculateGlobalStats(controller.floorPlans);
      return AppGradientHeader(
        title: 'Planos de mesas',
        subtitle: 'Organizá el layout de tu restaurante',
        // El back button lo inyecta `AppGradientHeader` automáticamente
        // (auto-detecta que esta pantalla no es root del Home).
        trailing: IconButton(
          tooltip: 'Refrescar',
          onPressed: controller.loadFloorPlans,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
        chips: [
          AppKpiChip(
            icon: Icons.map_outlined,
            label: 'Planos',
            value: stats['plans'].toString(),
          ),
          AppKpiChip(
            icon: Icons.table_bar,
            label: 'Mesas',
            value: stats['tables'].toString(),
          ),
          AppKpiChip(
            icon: Icons.layers,
            label: 'Capas',
            value: stats['layers'].toString(),
          ),
          AppKpiChip(
            icon: Icons.widgets_outlined,
            label: 'Elementos',
            value: stats['elements'].toString(),
          ),
        ],
      );
    });
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.floorPlans.isEmpty) {
        return AppEmptyState(
          icon: Icons.map_outlined,
          title: 'Aún no hay planos creados',
          message:
              'Creá tu primer plano para organizar las mesas de tu restaurante. Vas a poder agregar mesas, paredes y decoración.',
          actionLabel: 'Crear primer plano',
          actionIcon: Icons.add,
          onAction: controller.createNewFloorPlan,
        );
      }
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.loadFloorPlans,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isWide = width > 600;
            if (isWide) {
              final cross = width > 1400
                  ? 4
                  : width > 1100
                      ? 3
                      : width > 700
                          ? 2
                          : 2;
              final cardWidth = (width - 16 * 2 - 16 * (cross - 1)) / cross;
              final aspect = (cardWidth / 220).clamp(0.85, 1.4);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: aspect,
                ),
                itemCount: controller.floorPlans.length,
                itemBuilder: (context, i) {
                  final fp = controller.floorPlans[i];
                  return _FloorPlanCard(
                    floorPlan: fp,
                    onTap: () => controller.goToService(fp),
                    onEdit: () => controller.editFloorPlan(fp),
                    onDelete: () => controller.deleteFloorPlan(fp),
                  );
                },
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: controller.floorPlans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final fp = controller.floorPlans[i];
                return _FloorPlanCard(
                  floorPlan: fp,
                  onTap: () => controller.goToService(fp),
                  onEdit: () => controller.editFloorPlan(fp),
                  onDelete: () => controller.deleteFloorPlan(fp),
                );
              },
            );
          },
        ),
      );
    });
  }

  // ─────────────────────────── Stats globales ───────────────────────────

  static Map<String, int> _calculateGlobalStats(List<FloorPlan> plans) {
    int totalTables = 0;
    int totalElements = 0;
    int totalLayers = 0;
    for (final p in plans) {
      totalLayers += p.layers.length;
      for (final layer in p.layers) {
        totalElements += layer.elements.length;
        for (final element in layer.elements) {
          if (element.type == ElementType.table) totalTables++;
        }
      }
    }
    return {
      'plans': plans.length,
      'tables': totalTables,
      'layers': totalLayers,
      'elements': totalElements,
    };
  }
}

// ─────────────────────── Card del plano (rediseñada) ───────────────────────

/// Card moderna en el mismo lenguaje visual que `OrderCard`:
///
///   - Avatar tintado con icono.
///   - Título grande, badge de "Nivel X".
///   - Stats inline (mesas, capas, elementos) como chips compactos.
///   - Acción primaria "Servicio" como botón filled.
///   - Menú overflow con editar / eliminar.
class _FloorPlanCard extends StatelessWidget {
  final FloorPlan floorPlan;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FloorPlanCard({
    required this.floorPlan,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 14),
                _buildStatsRow(stats),
                const Spacer(),
                const SizedBox(height: 14),
                _buildPrimaryAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.table_restaurant,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                floorPlan.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Nivel ${floorPlan.floorLevel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 12),
                Text('Editar plano'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                SizedBox(width: 12),
                Text('Eliminar', style: TextStyle(color: AppColors.error)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, int> stats) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MiniStat(
          icon: Icons.table_bar,
          label: '${stats['tables']} mesas',
        ),
        _MiniStat(
          icon: Icons.layers,
          label: '${stats['layers']} capas',
        ),
        _MiniStat(
          icon: Icons.widgets_outlined,
          label: '${stats['elements']} elementos',
        ),
      ],
    );
  }

  Widget _buildPrimaryAction() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.room_service, size: 18),
        label: const Text(
          'Ir a servicio',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Map<String, int> _calculateStats() {
    int totalTables = 0;
    int totalElements = 0;
    for (final layer in floorPlan.layers) {
      for (final element in layer.elements) {
        totalElements++;
        if (element.type == ElementType.table) totalTables++;
      }
    }
    return {
      'tables': totalTables,
      'layers': floorPlan.layers.length,
      'elements': totalElements,
    };
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
