import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/inventory/services/inventory_stock_service.dart';
import '../../config/theme/app_colors.dart';
import '../../di/injection_container.dart';
import '../../routes/navigation_service.dart';
import '../../services/branch/branch_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_cache_service.dart';
import '../../services/push_notification_service.dart';
import '../../utils/app_snackbar.dart';
import '../sheet_handle.dart';

/// Barra de sede en el inicio. Solo aparece si el negocio tiene más de
/// una sede: muestra en qué sede está ESTE dispositivo y deja cambiarla
/// (y al admin/gerente, ver todas las sedes en listados y reportes).
class BranchBar extends StatefulWidget {
  final bool canViewAll;
  const BranchBar({super.key, required this.canViewAll});

  @override
  State<BranchBar> createState() => _BranchBarState();
}

class _BranchBarState extends State<BranchBar> {
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    // Avisos de la conciliación de sede (dispositivo nuevo / empleado de
    // otra sede). Fuera del build: nunca se mutan Rx durante el build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePending());
    final service = BranchService.maybe;
    if (service != null) {
      _worker = everAll([service.needsChoice, service.notice], (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handlePending());
      });
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  void _handlePending() {
    final service = BranchService.maybe;
    if (service == null || !mounted) return;
    final msg = service.notice.value;
    if (msg != null) {
      service.notice.value = null;
      AppSnackbar.show('Sede', msg, duration: const Duration(seconds: 6));
    }
    if (service.needsChoice.value && service.isMulti) {
      service.needsChoice.value = false;
      showBranchPicker(context, firstTime: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = BranchService.maybe;
    if (service == null) return const SizedBox.shrink();
    return Obx(() {
      if (!service.isMulti) return const SizedBox.shrink();
      final current = service.current.value;
      final all = service.viewAll.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: all ? Colors.amber.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showBranchPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: all ? Colors.amber.shade300 : AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current?.name ?? 'Elegí la sede',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          all
                              ? 'Viendo TODAS las sedes (lo que vendas queda en esta)'
                              : 'Sede de este dispositivo',
                          maxLines: 2,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (widget.canViewAll) ...[
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: all,
                          onChanged: (v) => _setViewAll(v),
                        ),
                        const Text('Todas', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _setViewAll(bool v) async {
    await BranchService.maybe?.setViewAll(v);
    // Los listados en pantalla se piden de nuevo con el alcance nuevo.
    NavigationService.toHome(clearStack: true);
  }
}

/// Hoja para elegir la sede del dispositivo.
Future<void> showBranchPicker(BuildContext context, {bool firstTime = false}) async {
  final service = BranchService.maybe;
  if (service == null) return;
  final picked = await showModalBottomSheet<BranchInfo>(
    context: context,
    isScrollControlled: true,
    isDismissible: !firstTime,
    enableDrag: !firstTime,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(
              firstTime ? '¿En qué sede está este dispositivo?' : 'Cambiar sede del dispositivo',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Lo que se venda, cobre y descuente de inventario desde acá queda en esa sede. '
              'El dispositivo la recuerda.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in service.mine)
                    ListTile(
                      leading: Icon(
                        service.current.value?.id == b.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.primary,
                      ),
                      title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [if (b.isDefault) 'Sede principal', if (b.address != null && b.address!.isNotEmpty) b.address!]
                            .join(' · '),
                      ),
                      onTap: () => Navigator.pop(ctx, b),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;
  if (picked.id == service.current.value?.id) {
    await service.select(picked); // confirma la elegida por defecto
    return;
  }
  await switchBranch(picked);
}

/// Cambia la sede del dispositivo y recarga la app con los datos de esa
/// sede. Lo pendiente sin internet NO se pierde ni cambia de sede: cada
/// operación encolada recuerda la suya.
Future<void> switchBranch(BranchInfo branch) async {
  final service = BranchService.maybe;
  if (service == null) return;
  final online = !Get.isRegistered<ConnectivityService>() ||
      Get.find<ConnectivityService>().isOnline.value;
  await service.select(branch);
  // Lo guardado en el dispositivo es de la sede anterior (mesas, cuentas,
  // stock…). Con internet se borra y se vuelve a pedir; sin internet se
  // deja para no quedarse sin nada que mostrar.
  if (online && sl.isRegistered<LocalCacheService>()) {
    await sl<LocalCacheService>().clearAll();
  }
  InventoryStockService.maybe?.start();
  if (online) PushNotificationService.registerToken(sl<Dio>()).ignore();
  AppSnackbar.show(
    'Sede cambiada',
    online
        ? 'Este dispositivo ahora trabaja en "${branch.name}".'
        : 'Ahora en "${branch.name}". Sin internet: los datos de la sede se actualizan al reconectar.',
  );
  NavigationService.toHome(clearStack: true);
}
