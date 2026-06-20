import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/orders_controller.dart';
import '../widgets/order_card.dart';

/// "Por cobrar" — órdenes con saldo pendiente, SIN filtro de fecha.
///
/// Es el flujo "el cliente pide y paga después": acá se ven todas las
/// órdenes consumidas/creadas que todavía deben plata, de cualquier día.
/// Al tocar una se va al detalle y se cobra con el flujo normal (parcial
/// o total). Reusa `OrdersController` (ya registrado) y `OrderCard`.
class UnpaidOrdersPage extends GetView<OrdersController> {
  const UnpaidOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Refrescamos al entrar para tener el listado al día.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadUnpaidOrders();
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(() => AppGradientHeader(
                  title: 'Por cobrar',
                  subtitle: controller.unpaidOrders.isEmpty
                      ? 'Sin saldos pendientes'
                      : '${controller.unpaidCount} '
                          '${controller.unpaidCount == 1 ? "orden" : "órdenes"} · '
                          '${CurrencyFormatter.format(controller.unpaidTotal)} pendiente',
                  leading: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  trailing: IconButton(
                    tooltip: 'Refrescar',
                    onPressed: controller.loadUnpaidOrders,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                )),
            _buildSearch(),
            Expanded(
              child: Obx(() {
                final list = controller.filteredUnpaid;
                if (controller.unpaidOrders.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.price_check,
                    title: 'Todo cobrado',
                    message:
                        'No hay órdenes con saldo pendiente. Cuando alguien '
                        'pida y quede a deber, aparecerá acá.',
                    accent: AppColors.success,
                  );
                }
                if (list.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.search_off,
                    title: 'Sin resultados',
                    message: 'Ninguna orden por cobrar coincide con la búsqueda.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.loadUnpaidOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final order = list[i];
                      return OrderCard(
                        order: order,
                        onTap: () => NavigationService.toOrderDetail(order.id),
                        // Cobro directo: abre el detalle con el dialog de
                        // pago auto. Para órdenes de cuenta abierta, va a
                        // la cuenta (cobro consolidado).
                        onCharge: order.belongsToTabSession
                            ? null
                            : () => Get.toNamed(
                                  '/orders/${order.id}',
                                  arguments: {'auto_open_pay': true},
                                ),
                        onOpenTabSession: order.belongsToTabSession
                            ? () => Get.toNamed(
                                  '/tab-sessions/${order.tabSessionId}',
                                )
                            : null,
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        onChanged: controller.setUnpaidSearchQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por cliente, #, mesa, teléfono…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}
