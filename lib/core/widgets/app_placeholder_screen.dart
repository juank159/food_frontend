import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/theme/app_colors.dart';
import 'app_empty_state.dart';
import 'app_gradient_header.dart';

/// Pantalla "en construcción" para rutas registradas pero aún sin
/// implementación. Mantiene el lenguaje visual del resto de la app
/// (gradient header + empty state) en lugar del cartel naranja viejo.
class AppPlaceholderScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String message;

  const AppPlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.construction,
    this.message =
        'Esta sección está en desarrollo. Volvé pronto para usarla.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              title: title,
              subtitle: subtitle ?? 'Próximamente',
              leading: Get.key.currentState?.canPop() == true
                  ? GestureDetector(
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
                    )
                  : null,
            ),
            Expanded(
              child: AppEmptyState(
                icon: icon,
                title: 'En desarrollo',
                message: message,
                actionLabel: Get.key.currentState?.canPop() == true
                    ? 'Volver'
                    : null,
                actionIcon: Icons.arrow_back,
                onAction: Get.key.currentState?.canPop() == true
                    ? () => Get.back()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla 404 — ruta inexistente. Misma estructura que el placeholder
/// pero con icono y mensaje apropiados.
class AppNotFoundScreen extends StatelessWidget {
  const AppNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Página no encontrada',
              subtitle: 'Ruta: ${Get.currentRoute}',
              leading: Get.key.currentState?.canPop() == true
                  ? GestureDetector(
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
                    )
                  : null,
            ),
            Expanded(
              child: AppEmptyState(
                icon: Icons.search_off,
                title: 'No encontramos esta pantalla',
                message:
                    'La ruta que intentaste abrir no existe o fue movida. '
                    'Volvé al inicio y probá de nuevo.',
                actionLabel: 'Ir al inicio',
                actionIcon: Icons.home,
                onAction: () => Get.offAllNamed('/home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
