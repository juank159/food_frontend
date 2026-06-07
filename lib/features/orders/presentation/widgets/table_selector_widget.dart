import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/constants/table_enums.dart';
import '../../../tables/domain/entities/floor_plan.dart';
import '../../../tables/domain/entities/table_status.dart' as table_entity;
import '../../../tables/domain/repositories/floor_plan_repository.dart';
import '../../../tables/presentation/controllers/table_status_controller.dart';

/// Table Selector Widget
///
/// Se abre desde `CreateOrderPage` para elegir una mesa a la que asignar la
/// orden. Antes fallaba con "no hay mesas disponibles" porque nadie cargaba
/// los estados: el widget asumía que el `TableStatusController` ya tenía data.
/// Ahora este widget:
///   1. Lista los floor plans del tenant.
///   2. Si hay uno solo → lo selecciona y carga sus mesas automáticamente.
///   3. Si hay varios → muestra un dropdown para que el usuario elija.
///   4. Muestra solo mesas con `status == available`.
class TableSelectorWidget extends StatefulWidget {
  final Function(String tableElementId, String? tableId, String tableName)
      onTableSelected;

  const TableSelectorWidget({
    super.key,
    required this.onTableSelected,
  });

  @override
  State<TableSelectorWidget> createState() => _TableSelectorWidgetState();
}

class _TableSelectorWidgetState extends State<TableSelectorWidget> {
  late final TableStatusController _tableController;
  late final FloorPlanRepository _floorPlanRepo;

  List<FloorPlan> _floorPlans = const [];
  FloorPlan? _selectedFloorPlan;
  bool _loadingFloorPlans = true;
  String? _floorPlanError;

  @override
  void initState() {
    super.initState();
    _tableController = Get.find<TableStatusController>();
    _floorPlanRepo = GetIt.I<FloorPlanRepository>();
    // Diferimos al próximo frame — `_loadFloorPlans` empieza con
    // `setState(...)` síncrono, lo que crashea si Flutter aún está
    // construyendo el árbol.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFloorPlans();
    });
  }

  Future<void> _loadFloorPlans() async {
    setState(() {
      _loadingFloorPlans = true;
      _floorPlanError = null;
    });

    try {
      final plans = await _floorPlanRepo.getFloorPlans();
      if (!mounted) return;
      setState(() {
        _floorPlans = plans;
        _loadingFloorPlans = false;
        if (plans.isNotEmpty) {
          _selectedFloorPlan = plans.first;
        }
      });
      if (plans.isNotEmpty) {
        await _tableController.loadTableStatuses(plans.first.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFloorPlans = false;
        _floorPlanError = e.toString();
      });
    }
  }

  void _onFloorPlanChanged(FloorPlan? plan) {
    if (plan == null) return;
    setState(() => _selectedFloorPlan = plan);
    _tableController.loadTableStatuses(plan.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        _buildFloorPlanSelector(context),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.table_restaurant,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Seleccionar Mesa',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _selectedFloorPlan == null
                ? null
                : () => _tableController
                    .loadTableStatuses(_selectedFloorPlan!.id),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Selector de floor plan. Si solo hay uno, mostramos un chip informativo
  /// en lugar del dropdown para no ensuciar la UI.
  Widget _buildFloorPlanSelector(BuildContext context) {
    if (_loadingFloorPlans) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }

    if (_floorPlanError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error cargando planos: $_floorPlanError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _loadFloorPlans,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_floorPlans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Todavía no hay ningún plano creado. Creá uno desde el módulo Mesas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (_floorPlans.length == 1) {
      final only = _floorPlans.first;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              'Plano: ${only.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DropdownButtonFormField<FloorPlan>(
        value: _selectedFloorPlan,
        decoration: InputDecoration(
          labelText: 'Plano',
          prefixIcon: const Icon(Icons.map_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
        items: _floorPlans
            .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
            .toList(),
        onChanged: _onFloorPlanChanged,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_selectedFloorPlan == null) {
      return _buildNoFloorPlanState(context);
    }

    return Obx(() {
      if (_tableController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_tableController.errorMessage.value.isNotEmpty) {
        return _buildErrorState(
          context,
          _tableController.errorMessage.value,
          () => _tableController.loadTableStatuses(_selectedFloorPlan!.id),
        );
      }

      final available = _tableController.tableStatuses
          .where((t) => t.status == TableStatus.available)
          .toList();

      if (available.isEmpty) {
        return _buildEmptyState(context);
      }

      return _buildTablesList(context, available);
    });
  }

  Widget _buildTablesList(
    BuildContext context,
    List<table_entity.TableStatusEntity> tables,
  ) {
    // IMPORTANT: usamos Wrap (no GridView con aspectRatio) porque cualquier
    // ratio fijo puede causar overflow cuando el contenido real (texto,
    // padding, fuente del sistema) supera la altura calculada. Con Wrap cada
    // card se dimensiona a su CONTENIDO real — es físicamente imposible que
    // desborde.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = _cardWidthForContainer(constraints.maxWidth);
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tables
                .map((t) => SizedBox(
                      width: cardWidth,
                      child: _TableCard(
                        table: t,
                        capacityLabel: _capacityLabel,
                        // IMPORTANTE: pasamos `null` como tableId. El segundo
                        // argumento del callback corresponde a `orders.table_id`
                        // (FK a la tabla `tables`), pero `t.id` es el id de la
                        // fila en `table_status` — no existe en `tables` y rompe
                        // la FK con error 500. Lo único que el backend
                        // necesita es `tableElementId` (id del elemento del
                        // floor plan).
                        onTap: () => widget.onTableSelected(
                          t.tableElementId,
                          null,
                          t.tableLabel ?? 'Mesa ${t.tableElementId}',
                        ),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  /// Calcula el ancho de cada card dado el ancho disponible del contenedor.
  /// No necesitamos calcular altura: el card se auto-dimensiona a su contenido.
  double _cardWidthForContainer(double available) {
    // Restamos el padding horizontal (12 * 2 = 24) y spacing entre cards.
    final usable = available - 24;
    if (usable < 340) return usable;                 // 1 col (mobile chico)
    if (usable < 560) return (usable - 10) / 2;       // 2 cols (mobile)
    if (usable < 860) return (usable - 20) / 3;       // 3 cols (tablet)
    if (usable < 1160) return (usable - 30) / 4;      // 4 cols (desktop)
    return (usable - 40) / 5;                          // 5 cols (desktop ancho)
  }

  String _capacityLabel(String raw) {
    // Backend manda strings tipo "four" en tableCapacity.
    const map = {
      'two': '2 personas',
      'four': '4 personas',
      'six': '6 personas',
      'eight': '8 personas',
      'ten': '10 personas',
    };
    return map[raw] ?? raw;
  }

  Widget _buildNoFloorPlanState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Elegí un plano arriba',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No hay mesas disponibles en este plano',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Todas están ocupadas, reservadas o en mantenimiento.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refrescar'),
            onPressed: _selectedFloorPlan == null
                ? null
                : () => _tableController
                    .loadTableStatuses(_selectedFloorPlan!.id),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Error al cargar mesas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Card unificado para mesas disponibles.
///
/// Layout HORIZONTAL compacto (ícono izquierda + info derecha + puntito verde).
/// Es inmune a overflow porque:
///   - La altura se ajusta al CONTENIDO (no hay aspectRatio forzado).
///   - Todas las filas usan `Flexible` / `Expanded` para que el texto largo
///     haga ellipsis en lugar de desbordar.
///   - `MainAxisSize.min` en los Columns internos.
///
/// Funciona bien en mobile (cards grandes, 1 columna) hasta desktop (cards
/// chicas, 5 columnas) sin tocar nada — solo cambia el ancho del SizedBox
/// que lo contiene.
class _TableCard extends StatelessWidget {
  final table_entity.TableStatusEntity table;
  final String Function(String) capacityLabel;
  final VoidCallback onTap;

  const _TableCard({
    required this.table,
    required this.capacityLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.table_restaurant,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mesa ${table.tableLabel ?? table.tableElementId}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (table.tableCapacity != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              capacityLabel(table.tableCapacity.toString()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
