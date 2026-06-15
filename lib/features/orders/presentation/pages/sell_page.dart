import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../payments/presentation/widgets/process_payment_dialog.dart';
import '../controllers/order_form_controller.dart';
import '../models/sell_mode.dart';
import '../widgets/cart_widget.dart';
import '../widgets/customer_info_widget.dart';
import '../widgets/product_selector_widget.dart';
import '../widgets/sell_mode_sheet.dart';

/// Pantalla **única** de venta. Reemplaza `CreateOrderPage` +
/// `QuickSalePage` + el flujo "abrir cuenta libre desde Cuentas".
///
/// **Modelo mental:**
/// El operario está siempre en el mismo lugar (el catálogo). Lo único
/// que cambia es A QUIÉN le está vendiendo — eso se cambia tocando el
/// **pill superior** que abre un sheet con las opciones (mostrador,
/// mesa, para llevar, domicilio, cuenta libre, cuenta existente).
///
/// **Sin más navegación de "tipo de orden", "elegí mesa", "datos del
/// cliente"** como pasos separados. Todo se decide desde el pill y
/// solo aparecen los inputs estrictamente necesarios para el modo
/// elegido (ej. teléfono+dirección solo si delivery).
///
/// **Args opcionales** (compat con callers viejos):
///   - `mode`: `SellMode` directo a aplicar (preset al entrar).
///   - `tableElementId` + `tableId` + `tableName`: para "Tomar mesa"
///     desde el plano.
///   - `fromTabSession` (string id) + `tableElementId`/`tableName`:
///     para "Agregar ticket" desde una cuenta abierta.
class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  late final OrderFormController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<OrderFormController>();
    // Diferimos al próximo frame para evitar `setState during build`
    // si los args incluyen un mode que dispara cambios reactivos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialMode();
    });
  }

  void _applyInitialMode() {
    final args = Get.arguments;
    if (args is! Map) return;
    final mode = args['mode'];
    if (mode is SellMode) {
      controller.applyMode(mode);
      return;
    }
    // Compat con callers viejos que pasan args sueltos.
    final tabSessionId = args['fromTabSession'] as String?;
    final tableElementId = args['tableElementId'] as String?;
    final tableId = args['tableId'] as String?;
    final tableName = args['tableName'] as String?;
    if (tabSessionId != null) {
      controller.applyMode(SellMode.tabSession(
        sessionId: tabSessionId,
        sessionLabel: tableName ?? 'Cuenta abierta',
        tableElementId: tableElementId,
        tableId: tableId,
        tableName: tableName,
      ));
    } else if (tableElementId != null && tableName != null) {
      controller.applyMode(SellMode.dineIn(
        tableElementId: tableElementId,
        tableId: tableId,
        tableName: tableName,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(controller: controller),
            _ModePill(controller: controller),
            Obx(() => _DynamicInputs(mode: controller.currentMode.value)),
            Expanded(
              child: ProductSelectorWidget(orderController: controller),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(controller: controller),
    );
  }
}

// ─────────────────────────── Header ───────────────────────────

class _Header extends StatelessWidget {
  final OrderFormController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppGradientHeader(
      title: 'Vender',
      subtitle: 'Tocá productos para armar el ticket',
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
      trailing: Obx(() {
        if (controller.cartItems.isEmpty) return const SizedBox(width: 40);
        return GestureDetector(
          onTap: () => _confirmClear(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Vaciar carrito?'),
        content: const Text('Se quitarán todos los productos cargados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (ok == true) controller.clearCart();
  }
}

// ─────────────────────────── Pill (modo actual) ───────────────────────────

class _ModePill extends StatelessWidget {
  final OrderFormController controller;
  const _ModePill({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Obx(() {
        final mode = controller.currentMode.value;
        return Material(
          color: mode.pillColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openModeSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: mode.pillColor.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: mode.pillColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(mode.pillIcon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'VENDIENDO A',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          mode.pillLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: mode.pillColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: mode.pillColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cambiar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.swap_horiz, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _openModeSheet(BuildContext context) async {
    final newMode = await showModalBottomSheet<SellMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SellModeSheet(currentMode: controller.currentMode.value),
    );
    if (newMode != null) {
      controller.applyMode(newMode);
    }
  }
}

// ─────────────── Inputs dinámicos según el modo ───────────────

/// Cuando el modo es `delivery` mostramos un mini-formulario inline
/// con teléfono + dirección. Para los otros modos no aparece (el
/// catálogo ocupa toda la pantalla). Tener los inputs siempre visibles
/// pero compactos ahorra una navegación.
class _DynamicInputs extends StatelessWidget {
  final SellMode mode;
  const _DynamicInputs({required this.mode});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OrderFormController>();
    // Solo delivery requiere datos inline (teléfono + dirección). En
    // los otros modos el catálogo ocupa toda la pantalla — más espacio
    // para los productos.
    if (mode.orderType != OrderType.delivery) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: CustomerInfoWidget(
        orderType: mode.orderType,
        initialName: controller.customerName.value,
        initialPhone: controller.customerPhone.value,
        initialEmail: controller.customerEmail.value,
        initialDeliveryStreet: controller.deliveryStreet.value,
        initialDeliveryCity: controller.deliveryCity.value,
        initialDeliveryNotes: controller.deliveryNotes.value,
        initialDeliveryFee: controller.deliveryFee.value,
        onSave: (info) {
          controller.setCustomerInfo(
            name: info.name,
            phone: info.phone,
            email: info.email,
          );
          controller.setDeliveryAddress(
            street: info.deliveryStreet,
            city: info.deliveryCity,
            notes: info.deliveryNotes,
          );
          if (info.deliveryFee != null) {
            controller.setDeliveryFee(info.deliveryFee!);
          }
        },
      ),
    );
  }
}

// ─────────────────────────── Bottom bar ───────────────────────────

class _BottomBar extends StatelessWidget {
  final OrderFormController controller;
  const _BottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasItems = controller.cartItems.isNotEmpty;
      final blocker = controller.submitBlockerReason;
      final mode = controller.currentMode.value;

      // Sin items mostramos un hint compacto en lugar de un botón
      // disabled gigante. El operario sabe que tiene que tocar productos.
      if (!hasItems) {
        return Material(
          elevation: 12,
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: const [
                  Icon(Icons.touch_app_outlined,
                      color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tocá productos para empezar a armar el ticket',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final isLoading = controller.isLoading.value;
      final canTap = blocker == null && !isLoading;
      final ctaLabel = _ctaLabelForMode(mode);

      return Material(
        elevation: 12,
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showCartSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          _CartIconBadge(count: controller.totalItems),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${controller.totalItems} ${controller.totalItems == 1 ? "ítem" : "ítems"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(controller.total),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: canTap ? () => _checkout(context, mode) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: mode.pillColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor:
                          AppColors.border.withValues(alpha: 0.6),
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            blocker == null
                                ? _ctaIconForMode(mode)
                                : Icons.info_outline,
                            size: 22,
                          ),
                    label: Text(
                      isLoading ? 'Procesando…' : (blocker ?? ctaLabel),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  String _ctaLabelForMode(SellMode mode) {
    if (mode.autoPayAfterSubmit) return 'Cobrar';
    // Cuenta abierta o mesa: el ticket se suma, no se cobra acá.
    return 'Enviar ticket';
  }

  IconData _ctaIconForMode(SellMode mode) {
    if (mode.autoPayAfterSubmit) return Icons.point_of_sale;
    return Icons.send;
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: CartWidget(controller: controller),
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, SellMode mode) async {
    await controller.submitOrder();
    if (!context.mounted) return;
    final order = controller.lastCreatedOrder.value;
    if (order == null) return; // submitOrder ya mostró el error.

    // La comanda de cocina se imprime dentro de `submitOrder` (cubre TODOS
    // los modos, incluida cuenta libre/mesa donde acá `order` sería null).

    if (mode.autoPayAfterSubmit) {
      // Mostrador, takeaway, delivery: cobramos directo.
      final paymentController = Get.find<PaymentController>();
      final result = await showDialog(
        context: context,
        builder: (_) => ProcessPaymentDialog(
          orderId: order.id,
          orderTotal: order.totalAmount,
          controller: paymentController,
        ),
      );
      if (!context.mounted) return;
      if (result != null) {
        HapticFeedback.mediumImpact();
        AppSnackbar.show(
          '¡Venta cobrada!',
          'Orden #${order.orderNumber} · ${CurrencyFormatter.format(order.totalAmount)}',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          duration: const Duration(seconds: 2),
        );
      } else {
        AppSnackbar.show(
          'Orden guardada',
          'La orden #${order.orderNumber} quedó pendiente de cobro.',
        );
      }
      // Reset para vender al próximo cliente sin navegación.
      controller.resetForm();
    } else {
      // Mesa o cuenta abierta: el ticket ya se sumó. Si la orden vino
      // con `tabSessionId` (porque ya estaba en una cuenta o el backend
      // la creó automáticamente al ser dine-in), vamos al detalle de
      // la cuenta. Si no, simplemente volvemos atrás.
      final sessionId = mode.tabSessionId ?? order.tabSessionId;
      controller.resetForm();
      if (sessionId != null && sessionId.isNotEmpty) {
        await Get.offNamed<dynamic>(
          AppRoutes.tabSessionDetail.replaceAll(':id', sessionId),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }
}

class _CartIconBadge extends StatelessWidget {
  final int count;
  const _CartIconBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          Icons.shopping_cart_outlined,
          color: AppColors.textPrimary,
          size: 24,
        ),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
