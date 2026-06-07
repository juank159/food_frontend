// lib/features/tables/presentation/pages/table_status_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/table_status.dart';
import '../../domain/entities/floor_plan.dart';
import '../../domain/repositories/floor_plan_repository.dart';
import '../controllers/table_status_controller.dart';
import '../widgets/table_status_card.dart';
import '../widgets/occupy_table_dialog.dart';
import '../widgets/reserve_table_dialog.dart';
import '../widgets/service_floor_plan_canvas.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../core/utils/logger.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Pantalla de servicio de mesas — view en lista o mapa con filtros
/// inline y stats en gradient header. Mismo lenguaje visual que el
/// resto de la app.
class TableStatusPage extends StatefulWidget {
  final String floorPlanId;
  final String? floorPlanName;

  const TableStatusPage({
    super.key,
    required this.floorPlanId,
    this.floorPlanName,
  });

  @override
  State<TableStatusPage> createState() => _TableStatusPageState();
}

enum ServiceViewMode { list, map }

class _TableStatusPageState extends State<TableStatusPage> {
  final tableStatusController = Get.find<TableStatusController>();
  final floorPlanRepository = Get.find<FloorPlanRepository>();

  ServiceViewMode _viewMode = ServiceViewMode.list;
  FloorPlan? _floorPlan;
  bool _isLoadingFloorPlan = false;

  @override
  void initState() {
    super.initState();
    // Diferimos al próximo frame — `_loadData` empieza con
    // `setState(...)` síncrono, lo que crashea si Flutter aún está
    // construyendo el árbol.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingFloorPlan = true);
    try {
      _floorPlan = await floorPlanRepository.getFloorPlanById(
        widget.floorPlanId,
      );
    } catch (e) {
      tablesLogger.e(
        'Error cargando floor plan',
        error: e,
        stackTrace: StackTrace.current,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el plano: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingFloorPlan = false);
    }

    await tableStatusController.loadTableStatuses(widget.floorPlanId);
    if (tableStatusController.tableStatuses.isEmpty) {
      await tableStatusController.syncWithFloorPlan(widget.floorPlanId);
    }
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ServiceViewMode.list
          ? ServiceViewMode.map
          : ServiceViewMode.list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    final title = widget.floorPlanName ?? 'Servicio';
    return Obx(() {
      final stats = tableStatusController.statistics;
      return AppGradientHeader(
        title: title,
        subtitle: 'Estado en vivo de tus mesas',
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderIconButton(
              icon: _viewMode == ServiceViewMode.list
                  ? Icons.map_outlined
                  : Icons.view_list,
              tooltip: _viewMode == ServiceViewMode.list
                  ? 'Vista de mapa'
                  : 'Vista de lista',
              onTap: _toggleViewMode,
            ),
            const SizedBox(width: 6),
            _HeaderIconButton(
              icon: Icons.sync,
              tooltip: 'Sincronizar mesas',
              onTap: () => tableStatusController.syncWithFloorPlan(
                widget.floorPlanId,
              ),
            ),
          ],
        ),
        chips: [
          AppKpiChip(
            icon: Icons.table_bar,
            label: 'Total',
            value: '${stats['total']}',
          ),
          AppKpiChip(
            icon: Icons.check_circle_outline,
            label: 'Disponibles',
            value: '${stats['available']}',
          ),
          AppKpiChip(
            icon: Icons.people_outline,
            label: 'Ocupadas',
            value: '${stats['occupied']}',
          ),
          AppKpiChip(
            icon: Icons.event,
            label: 'Reservadas',
            value: '${stats['reserved']}',
          ),
        ],
      );
    });
  }

  // ─────────────────────── Filter chips ───────────────────────

  /// Solo aplica a la vista de lista. En el mapa los filtros no se
  /// aplican (se muestra el plano completo siempre).
  Widget _buildFilterBar() {
    if (_viewMode != ServiceViewMode.list) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SizedBox(
        height: 36,
        child: Obx(() {
          final selected = tableStatusController.filterStatus.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              AppFilterChip(
                label: 'Todas',
                selected: selected == null,
                onTap: () => tableStatusController.setStatusFilter(null),
              ),
              for (final status in const [
                TableStatus.available,
                TableStatus.occupied,
                TableStatus.reserved,
                TableStatus.cleaning,
                TableStatus.maintenance,
              ])
                AppFilterChip(
                  label: status.displayName,
                  selected: selected == status,
                  icon: _statusIcon(status),
                  onTap: () => tableStatusController.setStatusFilter(
                    selected == status ? null : status,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody() {
    return Obx(() {
      if (tableStatusController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (tableStatusController.errorMessage.value.isNotEmpty) {
        return AppErrorState(
          message: tableStatusController.errorMessage.value,
          onRetry: _loadData,
        );
      }
      return _viewMode == ServiceViewMode.list
          ? _buildListView()
          : _buildMapView();
    });
  }

  Widget _buildListView() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Obx(() {
            final filtered = tableStatusController.filteredTableStatuses;
            if (filtered.isEmpty) {
              return AppEmptyState(
                icon: Icons.table_bar,
                title: 'No hay mesas para mostrar',
                message:
                    'Probá quitar el filtro o sincronizar con el plano para ver las mesas configuradas.',
                actionLabel: 'Sincronizar mesas',
                actionIcon: Icons.sync,
                onAction: () => tableStatusController.syncWithFloorPlan(
                  widget.floorPlanId,
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final tableStatus = filtered[index];
                  return TableStatusCard(
                    tableStatus: tableStatus,
                    onTap: () => _showTableActions(tableStatus),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: tableStatusController.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Buscar mesa…',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (_isLoadingFloorPlan || _floorPlan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Calcular bounds del contenido
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = double.negativeInfinity;
        double maxY = double.negativeInfinity;

        for (final layer in _floorPlan!.layers) {
          if (!layer.isVisible) continue;
          for (final element in layer.elements) {
            if (!element.isVisible) continue;
            final bounds = element.getBounds();
            if (bounds.left < minX) minX = bounds.left;
            if (bounds.top < minY) minY = bounds.top;
            if (bounds.right > maxX) maxX = bounds.right;
            if (bounds.bottom > maxY) maxY = bounds.bottom;
          }
        }

        if (minX == double.infinity) {
          minX = 0;
          minY = 0;
          maxX = _floorPlan!.canvasWidth;
          maxY = _floorPlan!.canvasHeight;
        }

        const padding = 50.0;
        minX -= padding;
        minY -= padding;
        maxX += padding;
        maxY += padding;

        final contentWidth = maxX - minX;
        final contentHeight = maxY - minY;
        final scaleX = screenWidth / contentWidth;
        final scaleY = screenHeight / contentHeight;
        double initialZoom = (scaleX < scaleY ? scaleX : scaleY) * 0.9;

        final scaledContentWidth = contentWidth * initialZoom;
        final scaledContentHeight = contentHeight * initialZoom;
        final panX =
            (screenWidth - scaledContentWidth) / 2 - (minX * initialZoom);
        final panY = (screenHeight - scaledContentHeight) / 2 -
            (minY * initialZoom);

        return Container(
          color: AppColors.background,
          child: Obx(() {
            final statuses = tableStatusController.tableStatuses.toList();
            return ServiceFloorPlanCanvas(
              floorPlan: _floorPlan!,
              tableStatuses: statuses,
              zoom: initialZoom,
              pan: Offset(panX, panY),
              onTableTap: (tableElementId) {
                final tableStatus = statuses.firstWhereOrNull(
                  (ts) => ts.tableElementId == tableElementId,
                );
                if (tableStatus != null) {
                  _showTableActions(tableStatus);
                }
              },
            );
          }),
        );
      },
    );
  }

  // ─────────────────────────── Actions sheet ───────────────────────────

  void _showTableActions(TableStatusEntity tableStatus) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TableActionsSheet(
        tableStatus: tableStatus,
        onOccupy: () {
          Get.back();
          _showOccupyDialog(tableStatus);
        },
        onReserve: () {
          Get.back();
          _showReserveDialog(tableStatus);
        },
        onTakeOrder: () {
          Get.back();
          _navigateToCreateOrder(
            tableStatus: tableStatus,
            partySize: tableStatus.partySize ?? 2,
            notes: tableStatus.notes,
          );
        },
        onViewOrder: () {
          Get.back();
          _navigateToOrderDetail(tableStatus);
        },
        onRelease: () async {
          Get.back();
          await tableStatusController.releaseTable(
            tableStatus.tableElementId,
          );
        },
        onMarkAvailable: () async {
          Get.back();
          await tableStatusController.markAsAvailable(
            tableStatus.tableElementId,
          );
        },
      ),
    );
  }

  void _showOccupyDialog(TableStatusEntity tableStatus) {
    showDialog(
      context: context,
      builder: (context) => OccupyTableDialog(
        tableStatus: tableStatus,
        onOccupy: (partySize, serverId, notes) async {
          final success = await tableStatusController.occupyTable(
            tableElementId: tableStatus.tableElementId,
            partySize: partySize,
            serverId: serverId,
            notes: notes,
          );
          if (success && context.mounted) {
            _navigateToCreateOrder(
              tableStatus: tableStatus,
              partySize: partySize,
              notes: notes,
            );
          }
        },
      ),
    );
  }

  void _showReserveDialog(TableStatusEntity tableStatus) {
    showDialog(
      context: context,
      builder: (context) => ReserveTableDialog(
        tableStatus: tableStatus,
        onReserve: (partySize, reservationId, reservedFor, notes) async {
          final success = await tableStatusController.reserveTable(
            tableElementId: tableStatus.tableElementId,
            partySize: partySize,
            reservationId: reservationId,
            reservedFor: reservedFor,
            notes: notes,
          );
          if (success && context.mounted) {
            Get.back();
          }
        },
      ),
    );
  }

  void _navigateToCreateOrder({
    required TableStatusEntity tableStatus,
    required int partySize,
    String? notes,
  }) {
    Get.toNamed(
      AppRoutes.createOrder,
      arguments: {
        'fromTableService': true,
        'tableElementId': tableStatus.tableElementId,
        'tableId': tableStatus.id,
        'tableName':
            tableStatus.tableLabel ?? 'Mesa ${tableStatus.tableElementId}',
        'partySize': partySize,
        'notes': notes,
      },
    );
  }

  void _navigateToOrderDetail(TableStatusEntity tableStatus) {
    if (tableStatus.currentOrderId == null) {
      AppSnackbar.show(
        'Error',
        'No hay orden asociada a esta mesa',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    NavigationService.toOrderDetail(tableStatus.currentOrderId!);
  }

  // ─────────────────────────── Helpers ───────────────────────────

  static IconData _statusIcon(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return Icons.check_circle_outline;
      case TableStatus.occupied:
        return Icons.people_outline;
      case TableStatus.reserved:
        return Icons.event;
      case TableStatus.cleaning:
        return Icons.cleaning_services;
      case TableStatus.maintenance:
        return Icons.build;
      case TableStatus.unavailable:
        return Icons.block;
    }
  }
}

// ─────────────────────────── UI helpers ───────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet con acciones contextuales según el estado de la mesa.
/// Header con icono coloreado por estado + lista de acciones grandes.
class _TableActionsSheet extends StatelessWidget {
  final TableStatusEntity tableStatus;
  final VoidCallback onOccupy;
  final VoidCallback onReserve;
  final VoidCallback onTakeOrder;
  final VoidCallback onViewOrder;
  final VoidCallback onRelease;
  final VoidCallback onMarkAvailable;

  const _TableActionsSheet({
    required this.tableStatus,
    required this.onOccupy,
    required this.onReserve,
    required this.onTakeOrder,
    required this.onViewOrder,
    required this.onRelease,
    required this.onMarkAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(tableStatus.status);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.table_restaurant,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tableStatus.tableLabel ??
                          'Mesa ${tableStatus.tableElementId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tableStatus.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Actions según estado
          ..._buildActionsForStatus(),
        ],
      ),
    );
  }

  List<Widget> _buildActionsForStatus() {
    if (tableStatus.isAvailableToOccupy) {
      return [
        _ActionTile(
          icon: Icons.people,
          accent: AppColors.primary,
          title: 'Ocupar mesa',
          subtitle: 'Asignar comensales y abrir cuenta',
          onTap: onOccupy,
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.event,
          accent: AppColors.warning,
          title: 'Reservar mesa',
          subtitle: 'Bloquear para una reserva futura',
          onTap: onReserve,
        ),
      ];
    }
    if (tableStatus.isOccupied) {
      return [
        if (tableStatus.currentOrderId != null)
          _ActionTile(
            icon: Icons.receipt_long,
            accent: AppColors.primary,
            title: 'Ver orden',
            subtitle: 'Detalle, items y cobro',
            onTap: onViewOrder,
          )
        else
          _ActionTile(
            icon: Icons.add_shopping_cart,
            accent: AppColors.primary,
            title: 'Tomar orden',
            subtitle: 'Crear pedido para esta mesa',
            onTap: onTakeOrder,
          ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.check_circle_outline,
          accent: AppColors.success,
          title: 'Liberar mesa',
          subtitle: 'Marcarla como disponible',
          onTap: onRelease,
        ),
      ];
    }
    if (tableStatus.isCleaning) {
      return [
        _ActionTile(
          icon: Icons.done_all,
          accent: AppColors.success,
          title: 'Marcar como disponible',
          subtitle: 'La mesa está lista para clientes',
          onTap: onMarkAvailable,
        ),
      ];
    }
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Sin acciones disponibles para este estado.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    ];
  }

  static Color _statusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.error;
      case TableStatus.reserved:
        return AppColors.warning;
      case TableStatus.cleaning:
        return AppColors.info;
      case TableStatus.maintenance:
        return AppColors.textSecondary;
      case TableStatus.unavailable:
        return AppColors.textPrimary;
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
