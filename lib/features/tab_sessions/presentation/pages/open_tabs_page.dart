// lib/features/tab_sessions/presentation/pages/open_tabs_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/open_tabs_controller.dart';
import '../widgets/open_tabs_view.dart';

/// Vista de cuentas abiertas — el "estado del negocio en vivo".
///
/// El cuerpo (stats + lista + "Abrir cuenta libre") vive en
/// `OpenTabsView`, compartido con el segmento "Cuentas abiertas" embebido
/// en la pantalla de Órdenes — UNA sola implementación, dos lugares.
class OpenTabsPage extends GetView<OpenTabsController> {
  const OpenTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            const Expanded(child: OpenTabsView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: 'Cuentas abiertas',
      subtitle: 'Mesas y deliveries activos en este momento',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      trailing: GestureDetector(
        onTap: controller.load,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.refresh, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
