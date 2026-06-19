import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../payments/presentation/widgets/widgets.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../domain/entities/order.dart';
import '../controllers/order_detail_controller.dart';
import '../widgets/order_items_list.dart';
import '../widgets/order_status_actions.dart';

/// Detalle de orden — moderno con header coloreado por estado, timeline
/// del ciclo de vida, items, pagos y acciones agrupadas.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final OrderDetailController controller;
  bool _autoPayHandled = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<OrderDetailController>();
    // OJO: el parámetro de la ruta `/orders/:id` (definido en
    // `AppRoutes.orderDetail`) se llama `id`, no `orderId`. Antes acá
    // se leía `Get.parameters['orderId']` que siempre era `null`, así
    // que `loadOrder` nunca se disparaba y la pantalla mostraba
    // "No se encontró la orden" sin haber hecho el GET al backend.
    final orderId = Get.parameters['id'] ?? '';
    if (orderId.isNotEmpty && !controller.hasOrder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadOrder(orderId).then((_) => _maybeAutoOpenPay());
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoOpenPay());
    }
  }

  /// Si la card de la lista nos navegó con `auto_open_pay: true`,
  /// disparamos el dialog de cobro automáticamente apenas la orden está
  /// cargada y es realmente cobrable. Esto evita el doble click "abrir
  /// detalle → tocar Pagar" para el flujo más común.
  void _maybeAutoOpenPay() {
    if (_autoPayHandled || !mounted) return;
    final args = Get.arguments;
    final wants = args is Map && args['auto_open_pay'] == true;
    if (!wants) return;
    if (!controller.hasOrder || !controller.canProcessPayment) return;
    _autoPayHandled = true;
    _showPaymentDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final orderId = Get.parameters['id'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (controller.isLoading.value && !controller.hasOrder) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Cargando orden…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        if (controller.errorMessage.value != null && !controller.hasOrder) {
          return SafeArea(
            child: AppErrorState(
              message: controller.errorMessage.value!,
              onRetry: () => controller.loadOrder(orderId),
            ),
          );
        }
        if (!controller.hasOrder) {
          return const SafeArea(
            child: Center(
              child: Text(
                'No se encontró la orden',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        final order = controller.currentOrder!;
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _OrderHeader(order: order, onRefresh: controller.refresh),
                const SizedBox(height: 16),
                _StatusTimeline(order: order),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Banner self-order: solo aparece si la orden
                      // nació por QR Y está en pending_review. Permite
                      // aprobar/rechazar desde el detalle (coherente
                      // con la bandeja de pendientes — mismo botón,
                      // mismo efecto).
                      if (controller.isPendingReviewSelfOrder) ...[
                        _PendingReviewBanner(controller: controller),
                        const SizedBox(height: 16),
                      ],
                      OrderItemsList(order: order, controller: controller),
                      const SizedBox(height: 16),
                      _buildPaymentSection(context, order),
                      const SizedBox(height: 16),
                      // El card genérico de "Cambiar Estado" NO se muestra
                      // para self-orders pending_review — usan el banner
                      // dedicado de arriba.
                      if (!controller.isPendingReviewSelfOrder)
                        OrderStatusActions(controller: controller),
                      if (order.hasSpecialInstructions) ...[
                        const SizedBox(height: 16),
                        _SpecialInstructionsCard(
                          instructions: order.specialInstructions!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      // Bottom action bar fija con el botón primario. Reemplaza al
      // `FloatingActionButton.extended('Procesar pago')` anterior — un
      // FAB con label largo se ve apretado, choca con safe area en
      // dispositivos chicos y oculta contenido. En una pantalla POS
      // el CTA crítico debe ser un botón ancho fijo en el footer,
      // mucho más usable.
      bottomNavigationBar: Obx(() {
        if (!controller.canProcessPayment) return const SizedBox.shrink();
        final order = controller.currentOrder;
        // Si ya hubo un abono parcial, el botón cobra el SALDO restante
        // (no el total). Antes mostraba el total completo aunque el
        // cliente ya hubiera abonado, confundiendo al cajero.
        final hasPartial =
            order != null && order.paidAmount > 0.01 && !order.isPaymentCompleted;
        final amountToCharge =
            order != null ? (hasPartial ? order.balance : order.totalAmount) : 0.0;
        final totalLabel = order != null
            ? ' · ${CurrencyFormatter.format(amountToCharge)}'
            : '';
        final buttonText = hasPartial ? 'Cobrar restante' : 'Procesar pago';
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showPaymentDialog(context),
                icon: const Icon(Icons.payment, size: 20),
                label: Text('$buttonText$totalLabel'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─────────────────────── Sub-secciones ───────────────────────

  Widget _buildPaymentSection(BuildContext context, Order order) {
    final theme = Theme.of(context);
    final paymentController = Get.find<PaymentController>();
    return Obx(() {
      final payments = paymentController.payments
          .where((p) => p.orderId == order.id)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentSummaryCard(
            payments: payments,
            orderTotal: order.totalAmount,
            onViewDetails: payments.isNotEmpty
                ? () => _showPaymentHistory(context)
                : null,
            onAddPayment: !order.isPaymentCompleted
                ? () => _showPaymentDialog(context)
                : null,
          ),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.history,
                        color: AppColors.info,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Historial de pagos',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: PaymentHistoryWidget(
                      orderId: order.id,
                      onRefund: controller.refresh,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  void _showPaymentDialog(BuildContext context) {
    final order = controller.currentOrder!;
    final paymentController = Get.find<PaymentController>();
    showDialog(
      context: context,
      builder: (context) => ProcessPaymentDialog(
        orderId: order.id,
        orderTotal: order.totalAmount,
        // Si la orden tiene pagos parciales previos, el cobro restante
        // es el balance — NO el total. Sin pasar esto, el dialog le
        // pedía al cajero el total completo aunque ya hubiera abonado
        // antes.
        amountDue: order.balance,
        controller: paymentController,
      ),
    );
    // OJO: NO hacemos `controller.refresh()` acá. El PaymentController
    // ya dispara `_notifyOrderChanged(orderId)` al success, que recarga
    // este detalle automáticamente — sin esto teníamos un GET extra
    // por cada cobro.
  }

  void _showPaymentHistory(BuildContext context) {
    final order = controller.currentOrder!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: PaymentHistoryWidget(
                    orderId: order.id,
                    onRefund: () {
                      controller.refresh();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Header colored ───────────────────────────

/// Header con gradient teñido por el color del estado actual de la orden.
/// Decisión deliberada: el detalle de orden NO usa el `AppGradientHeader`
/// estándar (naranja del brand) para que el operario vea de un vistazo en
/// qué estado está esta orden particular.
class _OrderHeader extends StatelessWidget {
  final Order order;
  final Future<void> Function() onRefresh;
  const _OrderHeader({required this.order, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
              const Spacer(),
              // Editar metadata (solo para órdenes en PENDING — una vez
              // confirmada la cocina, ya no tiene sentido cambiar
              // instrucciones o ETA).
              if (order.status == OrderStatus.pending)
                IconButton(
                  tooltip: 'Editar orden',
                  onPressed: () async {
                    final result = await Get.toNamed(
                      AppRoutes.buildEditOrder(order.id),
                      arguments: order,
                    );
                    if (result != null) {
                      await onRefresh();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white),
                ),
              // Menú de impresión térmica POS (recibo + comanda).
              // Vive en el header para que sea accesible siempre,
              // incluso en órdenes ya completadas (re-imprimir copia).
              _PrintMenuButton(orderId: order.id),
              IconButton(
                tooltip: 'Refrescar',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.status.displayName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.orderType.displayName} · ${DateFormat('dd MMM, HH:mm').format(order.createdAt)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // KPI hero: total + estado de pago
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(order.totalAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.isPaymentCompleted
                            ? Icons.check_circle
                            : Icons.schedule,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.isPaymentCompleted ? 'Pagado' : 'Pendiente',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Chips de contexto: origen (mesa/para llevar/domicilio),
          // cliente, items, ETA. El chip de origen siempre aparece
          // primero — clave para saber a dónde entregar la orden
          // cuando está lista.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOriginChip(order),
              if (order.hasCustomer)
                _ContextChip(
                  icon: Icons.person_outline,
                  label: order.customerName ?? 'Cliente',
                ),
              _ContextChip(
                icon: Icons.shopping_bag_outlined,
                label:
                    '${order.totalItems} ${order.totalItems == 1 ? "item" : "items"}',
              ),
              if (order.estimatedTime != null && order.estimatedTime! > 0)
                _ContextChip(
                  icon: Icons.schedule,
                  label: '${order.estimatedTime} min',
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingReview:
        // Self-order esperando aprobación del mesero — color de alerta
        // distinto al de pending normal para que se vea distinto en
        // la timeline.
        return Colors.deepOrange;
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return const Color(0xFF8E44AD);
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivered:
        return const Color(0xFF14B8A6);
      case OrderStatus.completed:
        return AppColors.textSecondary;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  /// Chip de origen de la orden (mesa o tipo de servicio). Siempre se
  /// pinta — si la orden es dine-in pero no tiene mesa asignada, decimos
  /// "Sin mesa" en vez de ocultar el chip, porque saber DÓNDE entregar
  /// es lo más importante en este flujo.
  Widget _buildOriginChip(Order order) {
    if (order.hasTable) {
      // Usamos `displayTableLabel` que prioriza el snapshot legible
      // (`tableLabel`) sobre `tableName` o `tableElementId`. Para
      // self-orders por QR llega como "Mesa 1 · Areas verdes".
      return _ContextChip(
        icon: Icons.table_restaurant,
        label: order.displayTableLabel,
      );
    }
    switch (order.orderType) {
      case OrderType.takeaway:
        return const _ContextChip(
          icon: Icons.takeout_dining_outlined,
          label: 'Para llevar',
        );
      case OrderType.delivery:
        return const _ContextChip(
          icon: Icons.delivery_dining_outlined,
          label: 'Domicilio',
        );
      case OrderType.dineIn:
        return const _ContextChip(
          icon: Icons.table_restaurant,
          label: 'Sin mesa',
        );
    }
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContextChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Status timeline ───────────────────────────

/// Timeline horizontal del ciclo de vida de la orden. Patrón clásico de
/// apps de delivery (Uber Eats, Rappi, DoorDash) — el cliente / operario
/// ve de inmediato dónde está y qué falta.
///
/// Si la orden está cancelada mostramos un estado especial.
class _StatusTimeline extends StatelessWidget {
  final Order order;
  const _StatusTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.isCancelled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Orden cancelada',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                    if (order.cancelledAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM, HH:mm').format(order.cancelledAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final steps = _buildSteps(order);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progreso',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _TimelineNode(
                    label: steps[i].label,
                    state: steps[i].state,
                    showLineLeft: i > 0,
                    showLineRight: i < steps.length - 1,
                    leftLineActive: i > 0 && steps[i - 1].state != _StepState.upcoming,
                    rightLineActive: i < steps.length - 1 &&
                        steps[i].state == _StepState.done,
                    icon: steps[i].icon,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static List<_Step> _buildSteps(Order order) {
    final stages = const [
      (OrderStatus.pending, 'Recibida', Icons.receipt_long),
      (OrderStatus.confirmed, 'Confirmada', Icons.check_circle_outline),
      (OrderStatus.preparing, 'En cocina', Icons.restaurant),
      (OrderStatus.ready, 'Lista', Icons.done_all),
      (OrderStatus.completed, 'Entregada', Icons.verified),
    ];
    final currentIndex =
        stages.indexWhere((s) => s.$1 == order.status);
    return [
      for (var i = 0; i < stages.length; i++)
        _Step(
          label: stages[i].$2,
          icon: stages[i].$3,
          state: () {
            if (currentIndex < 0) return _StepState.upcoming;
            if (i < currentIndex) return _StepState.done;
            if (i == currentIndex) return _StepState.current;
            return _StepState.upcoming;
          }(),
        ),
    ];
  }
}

class _Step {
  final String label;
  final IconData icon;
  final _StepState state;
  const _Step({
    required this.label,
    required this.icon,
    required this.state,
  });
}

enum _StepState { done, current, upcoming }

class _TimelineNode extends StatelessWidget {
  final String label;
  final _StepState state;
  final IconData icon;
  final bool showLineLeft;
  final bool showLineRight;
  final bool leftLineActive;
  final bool rightLineActive;

  const _TimelineNode({
    required this.label,
    required this.state,
    required this.icon,
    required this.showLineLeft,
    required this.showLineRight,
    required this.leftLineActive,
    required this.rightLineActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = state == _StepState.upcoming
        ? AppColors.divider
        : AppColors.primary;
    final iconColor =
        state == _StepState.upcoming ? AppColors.textHint : Colors.white;
    final fillColor = state == _StepState.upcoming
        ? AppColors.background
        : AppColors.primary;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: showLineLeft
                  ? Container(
                      height: 2,
                      color: leftLineActive
                          ? AppColors.primary
                          : AppColors.divider,
                    )
                  : const SizedBox(),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              alignment: Alignment.center,
              child: state == _StepState.done
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Icon(icon, size: 14, color: iconColor),
            ),
            Expanded(
              child: showLineRight
                  ? Container(
                      height: 2,
                      color: rightLineActive
                          ? AppColors.primary
                          : AppColors.divider,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: state == _StepState.current
                ? FontWeight.w800
                : FontWeight.w500,
            color: state == _StepState.upcoming
                ? AppColors.textHint
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Special instructions ───────────────────────────

class _SpecialInstructionsCard extends StatelessWidget {
  final String instructions;
  const _SpecialInstructionsCard({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.sticky_note_2_outlined,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instrucciones especiales',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instructions,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Menú de impresión térmica POS (recibo + comanda × 80mm/58mm).
// Vive acá porque es específico de esta pantalla y depende del
// `orderId` que viene del header.
// =====================================================================
class _PrintMenuButton extends StatefulWidget {
  final String orderId;
  const _PrintMenuButton({required this.orderId});

  @override
  State<_PrintMenuButton> createState() => _PrintMenuButtonState();
}

class _PrintMenuButtonState extends State<_PrintMenuButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Re-imprimir',
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.print, color: Colors.white),
      onSelected: (value) => _handle(value),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'receipt',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.receipt_long),
            title: Text('Recibo cliente'),
            subtitle: Text('Usa impresora configurada en Caja'),
          ),
        ),
        PopupMenuItem(
          value: 'kitchen',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.restaurant_menu),
            title: Text('Comanda cocina'),
            subtitle: Text('Usa impresora configurada en Cocina'),
          ),
        ),
      ],
    );
  }

  Future<void> _handle(String value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Usamos el orchestrator manual (con snackbar de "configurar" si
      // no hay impresora default). Resuelve la impresora del tenant
      // automáticamente — no hardcodeamos 80mm/58mm.
      if (value == 'receipt') {
        await PrintingOrchestrator.printReceiptManual(
          orderId: widget.orderId,
        );
      } else {
        await PrintingOrchestrator.printKitchenManual(
          orderId: widget.orderId,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// =====================================================================
// Banner self-order pendiente de aprobación.
// Aparece solo si el detalle abierto es de una orden creada por QR
// (source = qr_self_order) Y aún está en pending_review. Reemplaza
// al card genérico "Cambiar Estado" con botones más explícitos:
// Aprobar (→ envía a cocina) / Rechazar (con razón obligatoria).
// =====================================================================
class _PendingReviewBanner extends StatelessWidget {
  final OrderDetailController controller;
  const _PendingReviewBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isUpdating = controller.isUpdatingStatus.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepOrange.withValues(alpha: 0.10),
              Colors.deepOrange.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.deepOrange.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pedido por QR · Esperando tu aprobación',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.deepOrange,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'El cliente lo envió desde su celular. '
                        'Confirmá para que entre a cocina.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUpdating
                        ? null
                        : () => _confirmReject(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: isUpdating
                        ? null
                        : () => controller.approveSelfOrder(toConfirmed: true),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Aprobar y enviar a cocina'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _confirmReject(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Indicá brevemente por qué rechazás el pedido. '
              'Esta nota queda en el historial y el cliente verá el '
              'cambio en su pantalla de tracking.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej: mesa vacía, cliente se fue, pedido erróneo',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(reasonCtrl.text.trim()),
            child: const Text('Rechazar pedido'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      await controller.rejectSelfOrder(reason);
    }
  }
}
