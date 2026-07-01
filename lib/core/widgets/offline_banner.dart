import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/app_sync_service.dart';
import '../services/connectivity_service.dart';

/// Banner que aparece en la parte superior de la app cuando no hay conexión.
/// Se oculta automáticamente al reconectar.
///
/// Uso — envuelve el body de cualquier Scaffold:
///   ```dart
///   Column(children: [
///     const OfflineBanner(),
///     Expanded(child: _buildContent()),
///   ])
///   ```
///
/// O usar el mixin [OfflineAwareScreen] para aplicarlo automáticamente.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityService>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final online = ConnectivityService.to.isOnline.value;
      final syncing = Get.isRegistered<AppSyncService>()
          ? AppSyncService.to.isSyncing.value
          : false;
      final pending = Get.isRegistered<AppSyncService>()
          ? AppSyncService.to.pendingCount.value
          : 0;

      if (online && !syncing && pending == 0) {
        return const SizedBox.shrink();
      }

      final Color bgColor;
      final IconData icon;
      final String message;

      if (!online) {
        bgColor = const Color(0xFFB71C1C);
        icon = Icons.wifi_off_rounded;
        message = pending > 0
            ? 'Sin conexión · $pending operación${pending > 1 ? "es" : ""} pendiente${pending > 1 ? "s" : ""}'
            : 'Sin conexión · Modo offline';
      } else if (syncing) {
        bgColor = const Color(0xFF1565C0);
        icon = Icons.sync_rounded;
        message = 'Sincronizando operaciones pendientes…';
      } else {
        bgColor = const Color(0xFF2E7D32);
        icon = Icons.cloud_upload_outlined;
        message = '$pending pendiente${pending > 1 ? "s" : ""} por sincronizar';
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: bgColor,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: SafeArea(
          bottom: false,
          top: false,
          child: Row(
            children: [
              syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!online && pending > 0)
                GestureDetector(
                  onTap: () {
                    Get.dialog(_PendingOpsDialog());
                  },
                  child: const Text(
                    'Ver',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Dialog que muestra las operaciones pendientes en la cola offline.
class _PendingOpsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final syncService = Get.isRegistered<AppSyncService>()
        ? AppSyncService.to
        : null;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.schedule_outlined),
          SizedBox(width: 8),
          Text('Operaciones pendientes'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (syncService == null || syncService.queueLength == 0)
              const Text('No hay operaciones pendientes.')
            else
              Obx(() => Text(
                    '${syncService.pendingCount.value} operación${syncService.pendingCount.value > 1 ? "es" : ""} en cola.\n'
                    'Se enviarán al servidor automáticamente al recuperar la conexión.',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Los pedidos y pagos creados offline se guardan de forma segura en el dispositivo.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
