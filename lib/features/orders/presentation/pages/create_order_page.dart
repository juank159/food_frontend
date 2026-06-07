// lib/features/orders/presentation/pages/create_order_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../controllers/order_form_controller.dart';
import '../widgets/cart_widget.dart';
import '../widgets/customer_info_widget.dart';
import '../widgets/product_selector_widget.dart';
import '../widgets/table_selector_widget.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Crear nueva orden — pantalla más usada por los operarios.ss
///
/// Layout:
///   - Header gradient con back, título, reset y un stepper visual que
///     marca: 1) Tipo, 2) Items, 3) Cliente/Mesa, 4) Cobro.
///   - Selector de tipo de orden en 3 tarjetas grandes con icono.
///   - Bloque de mesa o cliente (según el tipo) con look de chip moderno.
///   - En desktop: split horizontal (catálogo + cart). En mobile: tabs.
class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  late final OrderFormController controller;
  bool _isFromTableService = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<OrderFormController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleTableServiceArguments();
    });
  }

  void _handleTableServiceArguments() {
    final args = Get.arguments;
    if (args is! Map<String, dynamic>) return;

    final tableElementId = args['tableElementId'] as String?;
    final tableId = args['tableId'] as String?;
    final tableName = args['tableName'] as String?;
    final partySize = args['partySize'] as int?;
    final notes = args['notes'] as String?;
    final fromTableService = args['fromTableService'] as bool? ?? false;
    final fromTabSession = args['fromTabSession'] as String?;

    // Caso A: viene desde "ocupar mesa" en el servicio de mesas
    // (workflow legacy donde la mesa se ocupó antes de crear la orden).
    if (fromTableService) {
      if (tableElementId == null || tableId == null || tableName == null) {
        return;
      }
      controller.setTableFromService(
        tableElementId: tableElementId,
        tableId: tableId,
        tableName: tableName,
        partySize: partySize,
        notes: notes,
      );
      setState(() => _isFromTableService = true);
      AppSnackbar.show(
        'Mesa asignada',
        'La orden se creará para $tableName',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        colorText: AppColors.primary,
      );
      return;
    }

    // Caso B: viene desde una cuenta abierta ("Agregar ticket").
    //
    // **Clave del modelo:** seteamos `activeTabSessionId` en el
    // controller. Eso hace que:
    //   1. `canSubmit` relaje los requisitos de cliente (la cuenta es
    //      la unidad de pago — no se pide nombre para un takeaway que
    //      pertenece a la mesa 5, solo dirección+phone para delivery).
    //   2. `submitOrder` envíe `tab_session_id` al backend, garantizando
    //      que el ticket se una a ESTA cuenta específica (sin depender
    //      del lookup por mesa que falla cuando es delivery sin mesa).
    if (fromTabSession != null) {
      controller.activeTabSessionId.value = fromTabSession;
      controller.orderType.value = OrderType.dineIn;
      if (tableElementId != null) {
        controller.selectTable(
          tableElementId: tableElementId,
          tableId: tableId,
          tableName: tableName,
        );
      }
      if (tableName != null) {
        AppSnackbar.show(
          'Agregando a la cuenta',
          'Mesa $tableName · podés cambiar el tipo (en local / para llevar / domicilio)',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          colorText: AppColors.primary,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveConfig(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildOrderTypeSelector(responsive),
            _buildContextSection(),
            const SizedBox(height: 4),
            Expanded(
              child: responsive.isDesktop
                  ? _buildWideScreenLayout(responsive)
                  : _buildNarrowScreenLayout(responsive),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      final orderType = controller.orderType.value;
      final hasContext = orderType == OrderType.dineIn
          ? controller.selectedTableName.value != null
          : (controller.customerName.value?.isNotEmpty ?? false);
      final hasItems = controller.hasItems;
      final stepIndex = !hasContext ? 1 : (!hasItems ? 2 : 3);
      return Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
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
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva orden',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tomá el pedido en pocos pasos',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Reiniciar',
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _showResetDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StepperBar(
              labels: const ['Tipo', 'Datos', 'Items', 'Cobro'],
              currentIndex: stepIndex,
            ),
          ],
        ),
      );
    });
  }

  // ─────────────────────── Order type selector ───────────────────────

  Widget _buildOrderTypeSelector(ResponsiveConfig responsive) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Obx(() {
        final selected = controller.orderType.value;
        return Row(
          children: [
            Expanded(
              child: _OrderTypeCard(
                icon: Icons.restaurant,
                label: 'En el local',
                selected: selected == OrderType.dineIn,
                disabled: _isFromTableService && selected != OrderType.dineIn,
                onTap: _isFromTableService
                    ? null
                    : () => controller.setOrderType(OrderType.dineIn),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OrderTypeCard(
                icon: Icons.shopping_bag_outlined,
                label: 'Para llevar',
                selected: selected == OrderType.takeaway,
                disabled: _isFromTableService,
                onTap: _isFromTableService
                    ? null
                    : () => controller.setOrderType(OrderType.takeaway),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OrderTypeCard(
                icon: Icons.delivery_dining,
                label: 'Delivery',
                selected: selected == OrderType.delivery,
                disabled: _isFromTableService,
                onTap: _isFromTableService
                    ? null
                    : () => controller.setOrderType(OrderType.delivery),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─────────────────────────── Context (mesa / cliente) ───────────────────────────

  Widget _buildContextSection() {
    return Obx(() {
      final orderType = controller.orderType.value;
      final inTab = controller.activeTabSessionId.value != null;

      // Cuando estamos agregando un ticket a una cuenta abierta,
      // mostramos una "banner" indicando a qué cuenta pertenece. Eso
      // reemplaza el contexto normal de mesa/cliente para casos
      // dine-in/takeaway (la cuenta ya identifica el grupo).
      // Para delivery dentro de una cuenta seguimos mostrando el
      // contexto de cliente, pero en formato compacto debajo del
      // banner — necesitamos la dirección de entrega.
      if (inTab) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _buildTabSessionBanner(),
              if (orderType == OrderType.delivery) ...[
                const SizedBox(height: 8),
                _buildCustomerContext(),
              ],
            ],
          ),
        );
      }

      if (orderType == OrderType.dineIn) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildTableContext(),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _buildCustomerContext(),
      );
    });
  }

  /// Banner verde indicando que el ticket se suma a una cuenta abierta.
  /// Esto reemplaza visualmente el contexto de cliente/mesa porque la
  /// cuenta ya identifica al grupo.
  Widget _buildTabSessionBanner() {
    final tableName = controller.selectedTableName.value;
    final orderType = controller.orderType.value;
    final label = tableName != null && tableName.isNotEmpty
        ? 'Agregando a Mesa $tableName'
        : 'Agregando a cuenta abierta';
    final subtitle = orderType == OrderType.delivery
        ? 'Pedido para entregar — los datos de la cuenta los hereda'
        : 'La cuenta es quien paga · no se piden datos del cliente';
    return _ContextCard(
      icon: Icons.receipt_long,
      title: label,
      subtitle: subtitle,
      accent: AppColors.success,
      onEdit: null,
    );
  }

  Widget _buildTableContext() {
    final tableName = controller.selectedTableName.value;
    if (tableName == null) {
      return _ContextCallToAction(
        icon: Icons.table_restaurant,
        label: 'Seleccionar mesa',
        accent: AppColors.primary,
        onTap: () => _showTableSelector(context),
      );
    }
    return _ContextCard(
      icon: _isFromTableService ? Icons.lock_outline : Icons.table_restaurant,
      title: tableName,
      subtitle: _isFromTableService
          ? 'Asignada desde servicio de mesas'
          : 'Mesa seleccionada',
      accent: AppColors.primary,
      onEdit: _isFromTableService ? null : () => _showTableSelector(context),
    );
  }

  Widget _buildCustomerContext() {
    final orderType = controller.orderType.value;
    final isDelivery = orderType == OrderType.delivery;
    final inTab = controller.activeTabSessionId.value != null;
    final customerName = controller.customerName.value;
    final street = controller.deliveryStreet.value;

    // Dentro de una cuenta abierta + delivery, lo que falta para
    // procesar es la DIRECCIÓN — no el cliente. El CTA debe pedir eso.
    final needsDeliveryData = inTab &&
        isDelivery &&
        (street == null || street.isEmpty);

    // Sin cliente todavía: CTA grande "Agregar cliente" / "Agregar
    // datos de entrega" — label depende del tipo para que el operario
    // entienda qué le van a pedir.
    if (needsDeliveryData ||
        (!inTab && (customerName == null || customerName.isEmpty))) {
      return _ContextCallToAction(
        icon: isDelivery ? Icons.delivery_dining : Icons.person_outline,
        label: isDelivery ? 'Agregar dirección de entrega' : 'Agregar cliente',
        accent: isDelivery ? AppColors.warning : AppColors.info,
        onTap: () => _showCustomerInfoDialog(context),
      );
    }

    // Dentro de cuenta + delivery con dirección ya cargada — mostramos
    // tarjeta de confirmación. No hace falta nombre acá.
    if (inTab && isDelivery) {
      final phone = controller.customerPhone.value;
      return _ContextCard(
        icon: Icons.delivery_dining,
        title: street ?? '',
        subtitle: (phone != null && phone.isNotEmpty)
            ? 'Teléfono: $phone'
            : 'Sin teléfono — agregalo para coordinar entrega',
        accent: (phone != null && phone.isNotEmpty)
            ? AppColors.info
            : AppColors.error,
        trailingIcon: (phone != null && phone.isNotEmpty)
            ? null
            : Icons.warning_amber_outlined,
        onEdit: () => _showCustomerInfoDialog(context),
      );
    }

    final phone = controller.customerPhone.value;

    // Para delivery, además de nombre/teléfono, advertimos si falta la
    // dirección — el canSubmit lo bloquea igual, pero el feedback
    // visual ayuda al operario a entender por qué no puede crear la orden.
    final isDeliveryIncomplete = isDelivery &&
        ((phone == null || phone.isEmpty) ||
            (street == null || street.isEmpty));

    final subtitle = _composeContextSubtitle(
      isDelivery: isDelivery,
      phone: phone,
      street: street,
    );

    return _ContextCard(
      icon: isDelivery ? Icons.delivery_dining : Icons.person,
      title: customerName ?? 'Cliente',
      subtitle: subtitle,
      accent: isDeliveryIncomplete ? AppColors.error : AppColors.info,
      // Cuando hay datos incompletos para delivery, mostrar un trailing
      // indicativo para que el operario sepa que tiene que abrir el form.
      trailingIcon: isDeliveryIncomplete ? Icons.warning_amber_outlined : null,
      onEdit: () => _showCustomerInfoDialog(context),
    );
  }

  /// Arma el subtítulo del ContextCard. Para delivery prioriza la
  /// dirección (la info más útil al ver el card) y agrega el teléfono
  /// si está. Para takeaway/dine-in solo el teléfono.
  String _composeContextSubtitle({
    required bool isDelivery,
    required String? phone,
    required String? street,
  }) {
    if (isDelivery) {
      final hasStreet = street != null && street.isNotEmpty;
      final hasPhone = phone != null && phone.isNotEmpty;
      if (!hasStreet && !hasPhone) return 'Falta dirección y teléfono';
      if (!hasStreet) return 'Falta dirección';
      if (!hasPhone) return '$street · Falta teléfono';
      return '$street · $phone';
    }
    if (phone != null && phone.isNotEmpty) return phone;
    return 'Cliente asignado';
  }

  // ─────────────────────────── Layout responsive ───────────────────────────

  Widget _buildWideScreenLayout(ResponsiveConfig responsive) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ProductSelectorWidget(orderController: controller),
          ),
          Container(width: 1, color: AppColors.border),
          LayoutBuilder(
            builder: (context, c) {
              final totalW = MediaQuery.of(context).size.width;
              final panelW = totalW >= 1400
                  ? 450.0
                  : totalW >= 1100
                  ? 380.0
                  : (totalW * 0.38).clamp(280.0, 420.0);
              return SizedBox(
                width: panelW,
                child: CartWidget(controller: controller),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowScreenLayout(ResponsiveConfig responsive) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.restaurant_menu, size: 18),
                    text: 'Productos',
                    height: 56,
                  ),
                  Tab(
                    icon: Obx(
                      () => Badge(
                        label: Text(controller.totalItems.toString()),
                        isLabelVisible: controller.hasItems,
                        backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                        child: const Icon(Icons.shopping_cart, size: 18),
                      ),
                    ),
                    text: 'Carrito',
                    height: 56,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProductSelectorWidget(orderController: controller),
                  CartWidget(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Sheets / dialogs ───────────────────────────

  void _showTableSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        height: MediaQuery.of(context).size.height * 0.75,
        child: TableSelectorWidget(
          onTableSelected: (tableElementId, tableId, tableName) {
            controller.selectTable(
              tableElementId: tableElementId,
              tableId: tableId,
              tableName: tableName,
            );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showCustomerInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Insets más generosos en mobile para que el dialog no toque
        // los bordes — el form ahora puede ser largo (delivery con
        // dirección + fee) y se aprecia el aire.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
          child: CustomerInfoWidget(
            orderType: controller.orderType.value,
            initialName: controller.customerName.value,
            initialPhone: controller.customerPhone.value,
            initialEmail: controller.customerEmail.value,
            initialDeliveryStreet: controller.deliveryStreet.value,
            initialDeliveryCity: controller.deliveryCity.value,
            initialDeliveryNotes: controller.deliveryNotes.value,
            initialDeliveryFee: controller.deliveryFee.value > 0
                ? controller.deliveryFee.value
                : null,
            onSave: (result) {
              controller.setCustomerInfo(
                name: result.name,
                phone: result.phone,
                email: result.email,
              );
              if (controller.orderType.value == OrderType.delivery) {
                controller.setDeliveryAddress(
                  street: result.deliveryStreet,
                  city: result.deliveryCity,
                  notes: result.deliveryNotes,
                );
                controller.setDeliveryFee(result.deliveryFee ?? 0);
              }
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reiniciar orden'),
        content: const Text(
          '¿Querés reiniciar la orden? Se van a perder todos los datos ingresados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              controller.resetForm();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Stepper ───────────────────────────

/// Barra de progreso con etiquetas debajo. `currentIndex` es 1-based: 1
/// significa "completaste el paso 1" (Tipo) y vamos por el 2.
class _StepperBar extends StatelessWidget {
  final List<String> labels;
  final int currentIndex;

  const _StepperBar({required this.labels, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(
                              height: 2,
                              color: i <= currentIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: i < currentIndex
                            ? Colors.white
                            : (i == currentIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.18)),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: i < currentIndex
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: AppColors.primary,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: i == currentIndex
                                    ? AppColors.primary
                                    : Colors.white,
                              ),
                            ),
                    ),
                    Expanded(
                      child: i == labels.length - 1
                          ? const SizedBox()
                          : Container(
                              height: 2,
                              color: i < currentIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == currentIndex
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i <= currentIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────── Pieces ───────────────────────────

class _OrderTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _OrderTypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled ? AppColors.textHint : AppColors.primary;
    return Material(
      color: selected ? AppColors.primary : AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextCallToAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ContextCallToAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              Icon(Icons.add, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onEdit;
  /// Icono de advertencia opcional a la derecha. Lo usamos para
  /// señalar campos incompletos (ej. delivery sin dirección).
  final IconData? trailingIcon;

  const _ContextCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onEdit,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailingIcon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(trailingIcon, size: 20, color: accent),
            ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: accent),
              onPressed: onEdit,
              tooltip: 'Editar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }
}
