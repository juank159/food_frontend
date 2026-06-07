import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../controllers/subscription_controller.dart';

class SubscriptionFeaturesList extends GetView<SubscriptionController> {
  const SubscriptionFeaturesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final usage = controller.usage.value;
      if (usage == null) return const SizedBox.shrink();

      final features = usage.features;
      if (features.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: AppColors.secondary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Características',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...features.entries.map((entry) {
              final isAvailable = entry.value == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle : Icons.cancel,
                      color: isAvailable ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getFeatureLabel(entry.key),
                        style: TextStyle(
                          fontSize: 14,
                          color: isAvailable
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  String _getFeatureLabel(String key) {
    const labels = {
      // Core Features
      'multi_location': 'Múltiples Ubicaciones',
      'custom_domain': 'Dominio Personalizado',
      'api_access': 'Acceso a API',
      'white_label': 'Marca Blanca',

      // Reports & Analytics
      'basic_reports': 'Reportes Básicos',
      'advanced_reports': 'Reportes Avanzados',
      'analytics_dashboard': 'Panel de Analíticas',
      'export_data': 'Exportar Datos',

      // Inventory
      'inventory_management': 'Gestión de Inventario',
      'low_stock_alerts': 'Alertas de Stock Bajo',
      'purchase_orders': 'Órdenes de Compra',

      // Customer Features
      'loyalty_program': 'Programa de Lealtad',
      'customer_feedback': 'Retroalimentación de Clientes',
      'marketing_tools': 'Herramientas de Marketing',

      // Support
      'email_support': 'Soporte por Email',
      'priority_support': 'Soporte Prioritario',
      'phone_support': 'Soporte Telefónico',
      'dedicated_account_manager': 'Gerente de Cuenta Dedicado',
    };
    return labels[key] ?? key;
  }
}
