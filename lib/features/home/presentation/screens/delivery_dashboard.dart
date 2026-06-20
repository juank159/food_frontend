import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';

/// Pantalla del rol `delivery`. Lista las órdenes tipo delivery que
/// están listas para entregar o ya están en camino.
///
/// **Funcionalidad clave para el repartidor:**
///   - Ver dirección + teléfono de cada cliente.
///   - Botón directo "Llamar" para teléfono (`tel:`).
///   - Botón directo "Mapa" para abrir Google Maps con la dirección.
///   - Botón "Salgo a entregar" → mueve a `delivered` (en tránsito).
///   - Botón "Entregado" → mueve a `completed`.
class DeliveryDashboard extends StatelessWidget {
  const DeliveryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OrdersController>();
    final authController = Get.find<AuthController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.showOnlyActive.value) {
        controller.showOnlyActive.value = true;
        controller.loadActiveOrders();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(authController, controller),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && !controller.hasOrders) {
                  return const Center(child: CircularProgressIndicator());
                }
                final deliveries = _deliveryOrders(controller);
                if (deliveries.isEmpty) return _buildEmpty();
                return RefreshIndicator(
                  onRefresh: controller.refreshOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: deliveries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _DeliveryCard(
                      order: deliveries[i],
                      controller: controller,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Órdenes delivery visibles: ready (listas para salir) +
  /// delivered (ya salieron, esperando confirmación). Ordenadas
  /// por más antiguas primero.
  List<Order> _deliveryOrders(OrdersController c) {
    final list = c.orders.where((o) {
      return o.orderType == OrderType.delivery &&
          (o.status == OrderStatus.ready ||
              o.status == OrderStatus.delivered ||
              o.status == OrderStatus.preparing);
    }).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Widget _buildHeader(
    AuthController authController,
    OrdersController controller,
  ) {
    final name = authController.currentUser?.firstName ?? 'Repartidor';
    return Obx(() {
      final list = _deliveryOrders(controller);
      final ready = list.where((o) => o.status == OrderStatus.ready).length;
      final inTransit =
          list.where((o) => o.status == OrderStatus.delivered).length;
      return AppGradientHeader(
        title: 'Repartos · $name',
        subtitle: '$ready listas · $inTransit en camino',
        trailing: GestureDetector(
          onTap: controller.refreshOrders,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 22),
          ),
        ),
      );
    });
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.delivery_dining,
              size: 44,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin repartos en cola',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando la cocina marque pedidos listos\naparecerán acá para entregar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Order order;
  final OrdersController controller;

  const _DeliveryCard({required this.order, required this.controller});

  @override
  Widget build(BuildContext context) {
    final inTransit = order.status == OrderStatus.delivered;
    final accent = inTransit ? AppColors.warning : AppColors.info;
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final address = _formatAddress(order.deliveryAddress);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: accent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? 'Cliente sin nombre',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#${order.orderNumber} · ${minutes}m',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inTransit ? 'EN CAMINO' : 'LISTA',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Datos del cliente y dirección.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Dirección',
                    value: address,
                  ),
                if (order.customerPhone != null &&
                    order.customerPhone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: order.customerPhone!,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Total: ${CurrencyFormatter.format(order.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: order.paymentStatus == PaymentStatus.completed
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.paymentStatus == PaymentStatus.completed
                            ? 'Pagado'
                            : 'Cobrar al entregar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: order.paymentStatus == PaymentStatus.completed
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Acciones rápidas: llamar + mapa + estado.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                if (order.customerPhone != null &&
                    order.customerPhone!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(order.customerPhone!),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Llamar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (address.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openMap(address),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Mapa'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: _PrimaryAction(
              order: order,
              controller: controller,
              inTransit: inTransit,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress(Map<String, dynamic>? addr) {
    if (addr == null) return '';
    final parts = <String>[];
    final street = addr['street']?.toString().trim();
    final city = addr['city']?.toString().trim();
    final notes = addr['notes']?.toString().trim();
    if (street != null && street.isNotEmpty) parts.add(street);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (notes != null && notes.isNotEmpty) parts.add('($notes)');
    return parts.join(', ');
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppSnackbar.show('No se pudo llamar', 'Revisá los permisos del dispositivo.');
    }
  }

  Future<void> _openMap(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      AppSnackbar.show('No se pudo abrir el mapa', 'Verificá tu conexión.');
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final Order order;
  final OrdersController controller;
  final bool inTransit;

  const _PrimaryAction({
    required this.order,
    required this.controller,
    required this.inTransit,
  });

  @override
  Widget build(BuildContext context) {
    if (inTransit) {
      return FilledButton.icon(
        onPressed: () => _move(OrderStatus.completed),
        icon: const Icon(Icons.task_alt),
        label: const Text(
          'Entregado',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => _move(OrderStatus.delivered),
      icon: const Icon(Icons.directions_run),
      label: const Text(
        'Salgo a entregar',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _move(OrderStatus next) async {
    HapticFeedback.mediumImpact();
    await controller.updateOrderStatus(order.id, next);
  }
}
