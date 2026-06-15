import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_variant.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/selected_modifier.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../models/sell_mode.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Cart Item Model
/// Modelo para items en el carrito
class CartItem {
  final Product product;
  int quantity;
  double unitPrice;
  String? specialInstructions;
  ProductVariant? selectedVariant;
  List<SelectedModifier> selectedModifiers;
  /// Cremas/sabores elegidos (uno por bola; pueden repetirse). `flavorIds`
  /// viaja al backend; `flavorNames` es para mostrar en el carrito.
  List<String> flavorIds;
  List<String> flavorNames;

  CartItem({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
    this.specialInstructions,
    this.selectedVariant,
    List<SelectedModifier>? selectedModifiers,
    List<String>? flavorIds,
    List<String>? flavorNames,
  })  : unitPrice = unitPrice ?? product.basePrice,
        selectedModifiers = selectedModifiers ?? [],
        flavorIds = flavorIds ?? [],
        flavorNames = flavorNames ?? [];

  /// Calcula el precio base considerando variante
  double get effectiveBasePrice {
    if (selectedVariant != null) {
      return selectedVariant!.calculateFinalPrice(product.basePrice);
    }
    return unitPrice;
  }

  /// Calcula el precio total de los modificadores por unidad
  double get modifiersPrice =>
      selectedModifiers.fold<double>(0.0, (sum, mod) => sum + mod.subtotal);

  /// Calcula el precio de una unidad del producto (base + variante + modificadores)
  double get pricePerUnit => effectiveBasePrice + modifiersPrice;

  /// Calcula el subtotal del item (precio por unidad * cantidad)
  double get subtotal => pricePerUnit * quantity;

  /// Verifica si tiene modificadores
  bool get hasModifiers => selectedModifiers.isNotEmpty;

  /// Obtiene los modificadores con costo
  List<SelectedModifier> get paidModifiers =>
      selectedModifiers.where((m) => m.hasCost).toList();

  /// Obtiene los modificadores sin costo (remociones)
  List<SelectedModifier> get freeModifiers =>
      selectedModifiers.where((m) => !m.hasCost).toList();

  /// Convertir a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'unit_price': effectiveBasePrice, // Enviar precio con variante ya calculado
      'special_instructions': specialInstructions,
      if (selectedVariant != null) 'variant_id': selectedVariant!.id,
      if (selectedModifiers.isNotEmpty)
        'modifiers': selectedModifiers.map((m) => m.toJson()).toList(),
      if (flavorIds.isNotEmpty) 'flavor_ids': flavorIds,
    };
  }

  /// Crear una copia con cambios
  CartItem copyWith({
    Product? product,
    int? quantity,
    double? unitPrice,
    String? specialInstructions,
    ProductVariant? selectedVariant,
    List<SelectedModifier>? selectedModifiers,
    List<String>? flavorIds,
    List<String>? flavorNames,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      flavorIds: flavorIds ?? this.flavorIds,
      flavorNames: flavorNames ?? this.flavorNames,
    );
  }
}

/// Order Form Controller
/// Controlador para el formulario de creación de órdenes con carrito
class OrderFormController extends GetxController {
  final CreateOrderUseCase createOrderUseCase;

  OrderFormController({required this.createOrderUseCase});

  @override
  void onInit() {
    super.onInit();
    // Sincronizar el estado con el modo por defecto (Mostrador). Sin esto,
    // `currentMode` arranca en counter pero `orderType` queda en su default
    // dineIn y `isQuickSale` en false → la pantalla EXIGE mesa aunque el
    // pill diga "Mostrador" (el bug que reportó el usuario). `_applyInitialMode`
    // de SellPage solo corre cuando hay args, así que el caso "Nueva orden"
    // sin args quedaba inconsistente. Aplicar el modo acá lo deja coherente
    // siempre; si llegan args, SellPage vuelve a llamar applyMode y gana ese.
    applyMode(currentMode.value);
    // Cargar tax_settings + tip_settings del tenant para que los cálculos
    // del cart usen la misma lógica que el backend (una sola request).
    loadTenantPricingSettings();
  }

  // Observable State
  final RxList<CartItem> cartItems = <CartItem>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<String?> errorMessage = Rx<String?>(null);

  // Order Form Data
  final Rx<OrderType> orderType = OrderType.dineIn.obs;
  final Rx<String?> selectedTableId = Rx<String?>(null);
  final Rx<String?> selectedTableElementId = Rx<String?>(null);
  final Rx<String?> selectedTableName = Rx<String?>(null);
  final Rx<String?> customerId = Rx<String?>(null);
  final Rx<String?> customerName = Rx<String?>(null);
  final Rx<String?> customerPhone = Rx<String?>(null);
  final Rx<String?> customerEmail = Rx<String?>(null);
  final Rx<String?> specialInstructions = Rx<String?>(null);

  /// Cuenta abierta (TabSession) a la que se debe adjuntar este ticket.
  ///
  /// Cuando está seteado:
  /// - La cuenta es la unidad de pago. Los datos del cliente se
  ///   vuelven opcionales (mesa es la referencia para takeaway,
  ///   solo dirección+phone para delivery).
  /// - El backend recibe `tab_session_id` y une el ticket nuevo a esa
  ///   cuenta — el operario no tiene que abrirla manualmente.
  ///
  /// Se setea desde la pantalla "Agregar ticket" en una cuenta abierta.
  final Rx<String?> activeTabSessionId = Rx<String?>(null);

  /// Modo "Venta Express" — venta de mostrador para clientes que no
  /// se sientan (gaseosa, cigarrillos, snack). Cuando true:
  ///   - `orderType` se fuerza a `takeaway`.
  ///   - El nombre del cliente NO es obligatorio (default: "Mostrador").
  ///   - La UI muestra solo catálogo + carrito + botón "Cobrar".
  ///   - Al confirmar, se navega DIRECTO al cobro (no a OrderDetail).
  final RxBool isQuickSale = false.obs;

  /// Última orden creada exitosamente — la `QuickSalePage` la usa para
  /// abrir el dialog de cobro sin tener que esperar el `Get.back(result)`
  /// (en venta express no popeamos la pantalla, queremos quedarnos).
  final Rx<Order?> lastCreatedOrder = Rx<Order?>(null);

  /// Destino actual de la venta (mostrador / mesa / takeaway / delivery
  /// / cuenta abierta). Se cambia desde el pill superior de `SellPage`
  /// sin navegar a otra pantalla. Cualquier cambio sincroniza
  /// `orderType`, `tableElementId`, `tabSessionId`, etc. vía
  /// `applyMode`. Default = mostrador (venta más rápida).
  final Rx<SellMode> currentMode = (const SellMode.counter()).obs;

  // Delivery address — relevante solo cuando `orderType == delivery`. Se
  // empaqueta como `Map` en el JSON de la orden (`delivery_address`). Si
  // los 3 strings están vacíos, no se manda el map.
  final Rx<String?> deliveryStreet = Rx<String?>(null);
  final Rx<String?> deliveryCity = Rx<String?>(null);
  final Rx<String?> deliveryNotes = Rx<String?>(null);

  final RxDouble discountAmount = 0.0.obs;
  final RxDouble discountPercentage = 0.0.obs;
  final RxDouble deliveryFee = 0.0.obs;
  final RxDouble tipAmount = 0.0.obs;
  final Rx<PaymentMethod?> paymentMethod = Rx<PaymentMethod?>(null);

  // Tax Configuration cargada del tenant (settings.tax_settings).
  // Defaults sensatos hasta que llegue la respuesta del servidor.
  final RxBool taxEnabled = true.obs;
  final RxDouble taxRate = 0.0.obs;
  final RxBool taxIncludedInPrice = true.obs;
  final RxString taxName = 'IVA'.obs;

  // Tip Configuration cargada del tenant (settings.tip_settings).
  // Espejo del bloque tax: la UI lee de acá para decidir qué mostrar y el
  // backend valida contra lo mismo al crear la orden. Defaults sensatos
  // (sugerida, 10/15/20, sobre subtotal con descuento, monto manual ok).
  final RxBool tipEnabled = true.obs;
  // Modo: disabled | suggested | mandatory.
  final RxString tipMode = 'suggested'.obs;
  // Base: subtotal | subtotal_with_tax | subtotal_after_discount.
  final RxString tipCalculationBase = 'subtotal_after_discount'.obs;
  final RxBool tipAllowCustomAmount = true.obs;
  final RxList<double> tipSuggestedPercentages =
      <double>[0.10, 0.15, 0.20].obs;
  final RxDouble tipDefaultPercentage = 0.10.obs;
  final RxDouble tipMaxPercentage = 0.0.obs; // 0 = sin tope
  final RxList<String> tipAppliesToOrderTypes = <String>[].obs;

  /// Carga tax_settings + tip_settings del tenant. Una sola request al
  /// endpoint /tenants/:id, mismos defaults que el backend.
  Future<void> loadTenantPricingSettings() async {
    try {
      final dio = GetIt.I<Dio>();
      final local = GetIt.I<AuthLocalDataSource>();
      final tenantId = await local.getTenantId();
      if (tenantId == null) return;
      final res = await dio.get('/tenants/$tenantId');
      final settings = (res.data['settings'] as Map<String, dynamic>?) ?? {};

      // Tax
      final tax = (settings['tax_settings'] as Map<String, dynamic>?) ?? {};
      taxEnabled.value = (tax['tax_enabled'] as bool?) ?? true;
      final rateAny = tax['tax_rate'];
      taxRate.value = rateAny is num ? rateAny.toDouble() : 0.0;
      taxIncludedInPrice.value =
          (tax['tax_included_in_price'] as bool?) ?? true;
      taxName.value = (tax['tax_name'] as String?) ?? 'IVA';

      // Tip
      final tip = (settings['tip_settings'] as Map<String, dynamic>?) ?? {};
      tipEnabled.value = (tip['tip_enabled'] as bool?) ?? true;
      tipMode.value = (tip['mode'] as String?) ?? 'suggested';
      tipCalculationBase.value =
          (tip['calculation_base'] as String?) ?? 'subtotal_after_discount';
      tipAllowCustomAmount.value =
          (tip['allow_custom_amount'] as bool?) ?? true;

      final defPct = tip['default_percentage'];
      tipDefaultPercentage.value =
          defPct is num ? defPct.toDouble() : 0.10;

      final suggested = tip['suggested_percentages'];
      tipSuggestedPercentages.clear();
      if (suggested is List) {
        for (final v in suggested) {
          if (v is num) tipSuggestedPercentages.add(v.toDouble());
        }
      }
      if (tipSuggestedPercentages.isEmpty) {
        tipSuggestedPercentages.addAll([0.10, 0.15, 0.20]);
      }

      final maxPct = tip['max_percentage'];
      tipMaxPercentage.value = maxPct is num ? maxPct.toDouble() : 0.0;

      tipAppliesToOrderTypes.clear();
      final applies = tip['applies_to_order_types'];
      if (applies is List) {
        for (final v in applies) {
          if (v is String) tipAppliesToOrderTypes.add(v);
        }
      }

      // Si el modo es "mandatory" y aún no hay propina cargada, pre-seleccionamos
      // el default para que el operario vea desde el inicio que va a cobrarse.
      if (tipMode.value == 'mandatory' &&
          tipAmount.value == 0 &&
          _tipAppliesToCurrentOrderType()) {
        tipAmount.value = tipBaseAmount * tipDefaultPercentage.value;
      }
    } catch (_) {
      // En error, mantenemos defaults — no bloquea la UI.
    }
  }

  /// Indica si la propina está activa y debe mostrarse en la UI para el
  /// `orderType` actual. Refleja exactamente lo que hace `_resolveTipAmount`
  /// del backend: si `applies_to_order_types` está vacío, aplica a todos.
  bool get isTipApplicable {
    if (!tipEnabled.value) return false;
    if (tipMode.value == 'disabled') return false;
    return _tipAppliesToCurrentOrderType();
  }

  bool _tipAppliesToCurrentOrderType() {
    if (tipAppliesToOrderTypes.isEmpty) return true;
    return tipAppliesToOrderTypes.contains(orderType.value.value);
  }

  /// Base sobre la que se calculan los porcentajes sugeridos. Espejo de
  /// `_tipBaseAmount` del backend.
  double get tipBaseAmount {
    switch (tipCalculationBase.value) {
      case 'subtotal_with_tax':
        return _taxableAmount + taxAmount;
      case 'subtotal':
      case 'subtotal_after_discount':
      default:
        return _taxableAmount;
    }
  }

  /// Tope absoluto en moneda derivado de `tipMaxPercentage`. Si es 0,
  /// no hay tope (devuelve null).
  double? get tipMaxAmount {
    if (tipMaxPercentage.value <= 0) return null;
    return tipBaseAmount * tipMaxPercentage.value;
  }

  // Computed Properties
  double get subtotal =>
      cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

  double get effectiveDiscount {
    if (discountAmount.value > 0) return discountAmount.value;
    if (discountPercentage.value > 0) {
      return subtotal * (discountPercentage.value / 100);
    }
    return 0.0;
  }

  /// Importe imponible (subtotal menos descuento, nunca negativo).
  double get _taxableAmount =>
      (subtotal - effectiveDiscount).clamp(0.0, double.infinity);

  /// IVA — respeta las 3 modalidades del tenant. Mismas fórmulas que el
  /// backend (orders.service.ts:calculateTotals) para que la UI muestre
  /// exactamente lo que el cliente paga.
  double get taxAmount {
    if (!taxEnabled.value || taxRate.value <= 0) return 0;
    if (taxIncludedInPrice.value) {
      // El IVA ya está dentro del subtotal — solo lo desglosamos.
      return _taxableAmount - _taxableAmount / (1 + taxRate.value);
    }
    return _taxableAmount * taxRate.value;
  }

  double get total {
    final base = !taxEnabled.value ||
            taxRate.value <= 0 ||
            taxIncludedInPrice.value
        ? _taxableAmount
        : _taxableAmount + (_taxableAmount * taxRate.value);
    return base + deliveryFee.value + tipAmount.value;
  }

  int get totalItems => cartItems.fold(0, (sum, item) => sum + item.quantity);

  bool get hasItems => cartItems.isNotEmpty;

  bool get canSubmit {
    if (!hasItems) return false;

    // Cuando estamos agregando un ticket a una cuenta abierta, la
    // cuenta es la unidad de pago. Relajamos los requisitos de cliente
    // — la mesa/cuenta ya identifica quién paga. Solo delivery sigue
    // exigiendo dirección+teléfono porque son datos de ENTREGA, no de
    // identificación.
    final inTab = activeTabSessionId.value != null;

    // dine-in: requiere mesa seleccionada (a menos que venga de cuenta
    // abierta — la cuenta ya tiene la mesa).
    if (orderType.value == OrderType.dineIn &&
        !inTab &&
        selectedTableElementId.value == null) {
      return false;
    }

    // takeaway: nombre obligatorio SOLO cuando es ticket suelto. En
    // una cuenta abierta o en Venta Express, no se exige (la mesa /
    // mostrador identifica al cliente).
    if (orderType.value == OrderType.takeaway &&
        !inTab &&
        !isQuickSale.value) {
      final name = customerName.value?.trim() ?? '';
      if (name.isEmpty) return false;
    }

    // delivery: dirección + teléfono SIEMPRE obligatorios (datos de
    // entrega). Nombre obligatorio solo cuando es ticket suelto — en
    // una cuenta abierta el "cliente" puede heredarse del titular.
    if (orderType.value == OrderType.delivery) {
      final phone = customerPhone.value?.trim() ?? '';
      final street = deliveryStreet.value?.trim() ?? '';
      if (phone.isEmpty || street.isEmpty) return false;
      if (!inTab) {
        final name = customerName.value?.trim() ?? '';
        if (name.isEmpty) return false;
      }
    }

    return true;
  }

  /// Mensaje human-friendly que explica POR QUÉ `canSubmit` es false.
  /// La UI lo usa como label del botón cuando está disabled — mucho más
  /// claro que un botón gris sin explicación.
  ///
  /// Devuelve `null` si todo está OK (el botón puede usarse).
  String? get submitBlockerReason {
    if (!hasItems) return 'Agregá productos';
    final inTab = activeTabSessionId.value != null;
    if (orderType.value == OrderType.dineIn &&
        !inTab &&
        selectedTableElementId.value == null) {
      return 'Seleccioná una mesa';
    }
    if (orderType.value == OrderType.takeaway &&
        !inTab &&
        !isQuickSale.value) {
      final name = customerName.value?.trim() ?? '';
      if (name.isEmpty) return 'Falta nombre del cliente';
    }
    if (orderType.value == OrderType.delivery) {
      final phone = customerPhone.value?.trim() ?? '';
      final street = deliveryStreet.value?.trim() ?? '';
      if (phone.isEmpty) return 'Falta teléfono';
      if (street.isEmpty) return 'Falta dirección';
      if (!inTab) {
        final name = customerName.value?.trim() ?? '';
        if (name.isEmpty) return 'Falta nombre del cliente';
      }
    }
    return null;
  }

  /// Cuenta cuántas unidades del producto (opcionalmente filtrando por
  /// variante puntual) ya están en el carrito. Lo usamos para validar stock
  /// antes de agregar más unidades, sin contar dos veces el mismo line item.
  ///
  /// Si `variant` es `null`, se cuentan TODAS las líneas del producto
  /// (incluyendo las que tienen variante), ya que el stock que trackeamos
  /// hoy es a nivel `Product.currentStock` — `ProductVariant` no expone
  /// stock propio. Si se pasa una `variant`, restringimos al match exacto
  /// para que la UI pueda diferenciar variantes en el futuro.
  int _quantityInCart(Product product, {ProductVariant? variant}) {
    return cartItems.fold<int>(0, (sum, item) {
      if (item.product.id != product.id) return sum;
      if (variant != null && item.selectedVariant?.id != variant.id) {
        return sum;
      }
      return sum + item.quantity;
    });
  }

  /// Indica si el producto tiene control de stock activo y stock disponible
  /// (independiente del carrito). Lo expone público para que la grilla pueda
  /// pintar "Agotado" sin replicar la lógica.
  bool isProductOutOfStock(Product product, {ProductVariant? variant}) {
    if (variant != null && !variant.isAvailable) return true;
    if (!product.trackInventory) return false;
    final stock = product.currentStock;
    if (stock == null) return false;
    return stock <= 0;
  }

  /// Devuelve cuántas unidades adicionales de `product` (con o sin
  /// `variant`) podemos agregar al carrito antes de superar el stock.
  /// `null` = sin límite (no trackeamos inventario o no hay dato de stock).
  int? remainingStock(Product product, {ProductVariant? variant}) {
    if (variant != null && !variant.isAvailable) return 0;
    if (!product.trackInventory) return null;
    final stock = product.currentStock;
    if (stock == null) return null;
    final inCart = _quantityInCart(product, variant: variant);
    final remaining = stock - inCart;
    return remaining < 0 ? 0 : remaining;
  }

  /// Verifica si podemos agregar `qty` unidades del producto al carrito sin
  /// superar el stock. Se invoca desde `addToCart` y desde la grilla para
  /// decidir si habilitar/deshabilitar el botón.
  bool canAddToCart(
    Product product, {
    int qty = 1,
    ProductVariant? variant,
  }) {
    if (qty <= 0) return false;
    // Variante explícitamente marcada como no disponible: bloquea sin importar
    // el inventario del producto.
    if (variant != null && !variant.isAvailable) return false;
    if (!product.trackInventory) return true;
    final stock = product.currentStock;
    if (stock == null) return true;
    final inCart = _quantityInCart(product, variant: variant);
    return (inCart + qty) <= stock;
  }

  /// Add product to cart with optional variant and modifiers
  void addToCart(
    Product product, {
    int quantity = 1,
    ProductVariant? variant,
    List<SelectedModifier>? modifiers,
    String? specialInstructions,
    List<String>? flavorIds,
    List<String>? flavorNames,
    bool silent = false,
  }) {
    // Validación de stock — si el producto trackea inventario, no podemos
    // dejar que el carrito supere `currentStock` porque al confirmar la orden
    // el backend rechazaría la línea (o, peor, vendería algo que no hay).
    if (!canAddToCart(product, qty: quantity, variant: variant)) {
      AppSnackbar.show(
        'Stock insuficiente',
        product.name,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final notes = specialInstructions?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    final hasFlavors = flavorIds != null && flavorIds.isNotEmpty;

    // Si el producto tiene variantes, modificadores, cremas o nota
    // explícita, siempre se agrega como item nuevo — cada combinación es
    // única y dos clientes pueden pedir "sin cebolla" en pedidos distintos.
    if ((variant != null) ||
        (modifiers != null && modifiers.isNotEmpty) ||
        hasFlavors ||
        hasNotes) {
      cartItems.add(CartItem(
        product: product,
        quantity: quantity,
        selectedVariant: variant,
        selectedModifiers: modifiers ?? [],
        specialInstructions: hasNotes ? notes : null,
        flavorIds: flavorIds,
        flavorNames: flavorNames,
      ));
    } else {
      // Check if product already exists (sin variante ni modificadores ni nota)
      final existingIndex = cartItems.indexWhere(
        (item) =>
            item.product.id == product.id &&
            item.selectedVariant == null &&
            item.selectedModifiers.isEmpty &&
            (item.specialInstructions == null ||
                item.specialInstructions!.isEmpty),
      );

      if (existingIndex != -1) {
        // Update quantity
        cartItems[existingIndex].quantity += quantity;
        cartItems.refresh();
      } else {
        // Add new item
        cartItems.add(CartItem(product: product, quantity: quantity));
      }
    }

    // Feedback. En el agregado rápido (stepper inline en el catálogo) lo
    // omitimos: la cantidad del card ya cambia a la vista y un snackbar por
    // toque sería ruido que ralentiza al operario tocando varias veces.
    if (silent) return;

    final variantText = variant != null ? ' (${variant.name})' : '';
    final modifiersText = modifiers != null && modifiers.isNotEmpty
        ? ' + ${modifiers.length} modificadores'
        : '';

    AppSnackbar.show(
      'Producto agregado',
      '${product.name}$variantText$modifiersText x$quantity',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  /// Cantidad en el carrito de la línea "simple" de un producto: sin
  /// variante, sin modificadores y sin nota. Es la que maneja el stepper
  /// rápido del catálogo. Los items con variante/modificadores/nota se
  /// gestionan como líneas propias desde el carrito.
  int plainCartQuantity(Product product) {
    return cartItems
        .where((i) =>
            i.product.id == product.id &&
            i.selectedVariant == null &&
            i.selectedModifiers.isEmpty &&
            (i.specialInstructions == null ||
                i.specialInstructions!.isEmpty))
        .fold(0, (sum, i) => sum + i.quantity);
  }

  /// Quita una unidad de la línea simple del producto (stepper rápido).
  /// Si llega a 0, `updateQuantity` elimina la línea.
  void decrementPlain(Product product) {
    final idx = cartItems.indexWhere((i) =>
        i.product.id == product.id &&
        i.selectedVariant == null &&
        i.selectedModifiers.isEmpty &&
        (i.specialInstructions == null || i.specialInstructions!.isEmpty));
    if (idx == -1) return;
    updateQuantity(idx, cartItems[idx].quantity - 1);
  }

  /// Remove item from cart
  void removeFromCart(int index) {
    if (index >= 0 && index < cartItems.length) {
      final item = cartItems[index];
      cartItems.removeAt(index);
      AppSnackbar.show(
        'Producto eliminado',
        item.product.name,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Update item quantity
  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < cartItems.length) {
      if (quantity <= 0) {
        removeFromCart(index);
      } else {
        // Validamos stock contra el resto del carrito (excluyendo esta misma
        // línea, que estamos por reescribir). Si el delta supera lo que
        // queda, bloqueamos y avisamos.
        final item = cartItems[index];
        if (item.product.trackInventory &&
            item.product.currentStock != null) {
          final otherInCart = _quantityInCart(
                item.product,
                variant: item.selectedVariant,
              ) -
              item.quantity;
          if (otherInCart + quantity > item.product.currentStock!) {
            AppSnackbar.show(
              'Stock insuficiente',
              item.product.name,
              snackPosition: SnackPosition.TOP,
              backgroundColor: Get.theme.colorScheme.error,
              colorText: Get.theme.colorScheme.onError,
              duration: const Duration(seconds: 3),
            );
            return;
          }
        }
        cartItems[index].quantity = quantity;
        cartItems.refresh();
      }
    }
  }

  /// Update item price
  void updateUnitPrice(int index, double price) {
    if (index >= 0 && index < cartItems.length) {
      cartItems[index].unitPrice = price;
      cartItems.refresh();
    }
  }

  /// Update item special instructions
  void updateItemInstructions(int index, String? instructions) {
    if (index >= 0 && index < cartItems.length) {
      cartItems[index].specialInstructions = instructions;
      cartItems.refresh();
    }
  }

  /// Clear cart
  void clearCart() {
    cartItems.clear();
    errorMessage.value = null;
  }

  /// Set order type
  void setOrderType(OrderType type) {
    orderType.value = type;
    // Clear table selection if not dine-in
    if (type != OrderType.dineIn) {
      selectedTableId.value = null;
      selectedTableElementId.value = null;
      selectedTableName.value = null;
    }
    // Clear customer info if dine-in
    if (type == OrderType.dineIn) {
      customerId.value = null;
      customerName.value = null;
      customerPhone.value = null;
      customerEmail.value = null;
    }
    // Limpiar bloque de delivery cuando el tipo cambia a algo que no
    // es delivery — evita que dirección + fee de un pedido viejo se
    // arrastren a una orden takeaway/dine-in y se contabilicen mal.
    if (type != OrderType.delivery) {
      deliveryStreet.value = null;
      deliveryCity.value = null;
      deliveryNotes.value = null;
      deliveryFee.value = 0.0;
    }
    // Re-evaluar propina: si el tenant restringió la propina a otros tipos
    // y este tipo no aplica, la limpiamos para que el total no la sume.
    // Si es mandatory y aún no hay valor, aplicamos el default.
    if (!isTipApplicable) {
      tipAmount.value = 0;
    } else if (tipMode.value == 'mandatory' && tipAmount.value == 0) {
      tipAmount.value = tipBaseAmount * tipDefaultPercentage.value;
    }
  }

  /// Select table for dine-in
  void selectTable({
    required String tableElementId,
    String? tableId,
    String? tableName,
  }) {
    selectedTableElementId.value = tableElementId;
    selectedTableId.value = tableId;
    selectedTableName.value = tableName;
  }

  /// Set table data from table service (pre-occupied table)
  /// This method is used when coming from the table service page
  /// where the table has already been occupied
  void setTableFromService({
    required String tableElementId,
    required String tableId,
    required String tableName,
    int? partySize,
    String? notes,
  }) {
    // Set order type to dine-in
    orderType.value = OrderType.dineIn;

    // Set table information
    selectedTableElementId.value = tableElementId;
    selectedTableId.value = tableId;
    selectedTableName.value = tableName;

    // Set special instructions if notes provided
    if (notes != null && notes.isNotEmpty) {
      specialInstructions.value = notes;
    }

    // Note: partySize is stored in table status but not in order form
    // It's already registered when occupying the table
  }

  /// Set customer info. Normalizamos strings vacíos a `null` para que
  /// `canSubmit` y el JSON enviado al backend sean consistentes.
  void setCustomerInfo({
    String? id,
    String? name,
    String? phone,
    String? email,
  }) {
    customerId.value = (id != null && id.trim().isEmpty) ? null : id;
    customerName.value =
        (name != null && name.trim().isEmpty) ? null : name?.trim();
    customerPhone.value =
        (phone != null && phone.trim().isEmpty) ? null : phone?.trim();
    customerEmail.value =
        (email != null && email.trim().isEmpty) ? null : email?.trim();
  }

  /// Apply discount amount
  void applyDiscountAmount(double amount) {
    discountAmount.value = amount;
    discountPercentage.value = 0.0; // Clear percentage
  }

  /// Apply discount percentage
  void applyDiscountPercentage(double percentage) {
    discountPercentage.value = percentage;
    discountAmount.value = 0.0; // Clear amount
  }

  /// Set delivery fee
  void setDeliveryFee(double fee) {
    deliveryFee.value = fee;
  }

  /// Set tip amount. Capamos al máximo configurado por el tenant para que el
  /// backend no rechace la orden. La propina debe ser >= 0.
  void setTipAmount(double tip) {
    if (!isTipApplicable) {
      tipAmount.value = 0;
      return;
    }
    final safe = tip < 0 ? 0.0 : tip;
    final cap = tipMaxAmount;
    tipAmount.value = (cap != null && safe > cap) ? cap : safe;
  }

  /// Set payment method
  void setPaymentMethod(PaymentMethod? method) {
    paymentMethod.value = method;
  }

  /// Set special instructions
  void setSpecialInstructions(String? instructions) {
    specialInstructions.value =
        (instructions == null || instructions.trim().isEmpty)
            ? null
            : instructions.trim();
  }

  /// Setea las instrucciones especiales de un item del carrito por índice.
  void updateItemSpecialInstructions(int index, String? instructions) {
    if (index < 0 || index >= cartItems.length) return;
    cartItems[index].specialInstructions =
        (instructions == null || instructions.trim().isEmpty)
            ? null
            : instructions.trim();
    cartItems.refresh();
  }

  /// Setea la dirección de entrega. Strings vacíos → `null`.
  void setDeliveryAddress({
    String? street,
    String? city,
    String? notes,
  }) {
    deliveryStreet.value =
        (street == null || street.trim().isEmpty) ? null : street.trim();
    deliveryCity.value =
        (city == null || city.trim().isEmpty) ? null : city.trim();
    deliveryNotes.value =
        (notes == null || notes.trim().isEmpty) ? null : notes.trim();
  }

  /// Construye el `deliveryAddress` para el JSON de la orden, o `null`
  /// si no hay datos.
  Map<String, dynamic>? get _composedDeliveryAddress {
    if (orderType.value != OrderType.delivery) return null;
    final hasAny = (deliveryStreet.value?.isNotEmpty ?? false) ||
        (deliveryCity.value?.isNotEmpty ?? false) ||
        (deliveryNotes.value?.isNotEmpty ?? false);
    if (!hasAny) return null;
    return {
      if (deliveryStreet.value != null) 'street': deliveryStreet.value,
      if (deliveryCity.value != null) 'city': deliveryCity.value,
      if (deliveryNotes.value != null) 'notes': deliveryNotes.value,
    };
  }

  /// Submit order
  Future<void> submitOrder() async {
    if (!canSubmit) {
      AppSnackbar.show(
        'Error',
        'Por favor completa todos los campos requeridos',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final items = cartItems.map((item) => item.toJson()).toList();

      // En Venta Express, si el operario no puso nombre, asignamos uno
      // genérico para que el backend tenga algo en `customer_name`
      // (algunos reportes y prints lo esperan no-vacío).
      final effectiveCustomerName = isQuickSale.value &&
              (customerName.value?.trim().isEmpty ?? true)
          ? 'Mostrador'
          : customerName.value;

      final result = await createOrderUseCase(
        orderType: orderType.value,
        tableId: selectedTableId.value,
        tableElementId: selectedTableElementId.value,
        tabSessionId: activeTabSessionId.value,
        customerId: customerId.value,
        customerName: effectiveCustomerName,
        customerPhone: customerPhone.value,
        customerEmail: customerEmail.value,
        deliveryAddress: _composedDeliveryAddress,
        items: items,
        specialInstructions: specialInstructions.value,
        discountAmount: discountAmount.value,
        discountPercentage: discountPercentage.value > 0
            ? discountPercentage.value
            : null,
        deliveryFee: deliveryFee.value,
        tipAmount: tipAmount.value,
        paymentMethod: paymentMethod.value,
      );

      result.fold(
        (failure) {
          String message = 'Error al crear la orden';
          if (failure is ValidationFailure) {
            message = failure.message;
          } else if (failure is NetworkFailure) {
            message = 'Error de conexión. Verifica tu internet.';
          } else if (failure is ServerFailure) {
            message = 'Error del servidor. Intenta nuevamente.';
          }
          errorMessage.value = message;
          AppSnackbar.show(
            'Error',
            message,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 5),
          );
        },
        (order) {
          // Imprimir la(s) comanda(s) de cocina automáticamente al
          // registrar el pedido — UNA por categoría (solo categorías con
          // `prints_kitchen` e items que requieren preparación). Va ACÁ
          // (y no en SellPage._checkout) porque para mesa/cuenta libre/
          // takeaway/delivery el submit hace `Get.back` y nunca setea
          // `lastCreatedOrder`, así que el checkout no alcanzaba a
          // imprimir. Fire-and-forget: el orquestador omite solo si no
          // hay impresora de cocina o no hay items para cocina.
          unawaited(PrintingOrchestrator.autoPrintKitchen(orderId: order.id));

          // En Venta Express NO mostramos snackbar de "Orden creada" ni
          // popeamos la pantalla — el caller se encarga del flujo (abrir
          // dialog de cobro, mostrar feedback final). Solo exponemos la
          // orden creada para que la pueda usar.
          if (isQuickSale.value) {
            lastCreatedOrder.value = order;
            return;
          }

          AppSnackbar.show(
            'Orden creada',
            'Orden #${order.orderNumber} creada exitosamente',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 3),
          );

          // Clear form and navigate back
          clearCart();
          Get.back(result: order);
        },
      );
    } catch (e) {
      errorMessage.value = 'Error inesperado: ${e.toString()}';
      AppSnackbar.show(
        'Error',
        'Error inesperado al crear la orden',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Cambia el destino de la venta. Sincroniza todos los flags
  /// derivados (`orderType`, `tableElementId`, `tabSessionId`,
  /// `isQuickSale`, etc.) en una sola llamada para que el `submitOrder`
  /// envíe los datos correctos sin que el caller tenga que setear cada
  /// campo individualmente.
  void applyMode(SellMode mode) {
    currentMode.value = mode;
    orderType.value = mode.orderType;
    selectedTableElementId.value = mode.tableElementId;
    selectedTableId.value = mode.tableId;
    selectedTableName.value = mode.tableName;
    activeTabSessionId.value = mode.tabSessionId;
    // El modo "Mostrador" relaja la validación de cliente: equivalente
    // al antiguo `isQuickSale`. Para los otros modos, exigimos los
    // datos correspondientes (ver `submitBlockerReason`).
    isQuickSale.value = mode.isCounter;

    // Al pasar a un modo nuevo limpiamos datos del modo anterior que ya
    // no aplican — evita arrastrar dirección de delivery cuando ahora
    // estamos en una mesa, por ejemplo.
    if (mode.orderType != OrderType.delivery) {
      deliveryStreet.value = null;
      deliveryCity.value = null;
      deliveryNotes.value = null;
      deliveryFee.value = 0.0;
    }
    // El nombre/teléfono del cliente NO los limpiamos: el operario
    // puede haber llenado los datos antes de cambiar de modo y
    // perderlos sería frustrante.
  }

  /// Reset form
  void resetForm() {
    clearCart();
    // En Venta Express mantenemos `takeaway` para que el operario siga
    // vendiendo sin re-configurar la pantalla. En el flujo normal,
    // dine-in es el default que el usuario espera al abrir "Nueva orden".
    orderType.value =
        isQuickSale.value ? OrderType.takeaway : OrderType.dineIn;
    selectedTableId.value = null;
    selectedTableElementId.value = null;
    selectedTableName.value = null;
    customerId.value = null;
    customerName.value = null;
    customerPhone.value = null;
    customerEmail.value = null;
    specialInstructions.value = null;
    deliveryStreet.value = null;
    deliveryCity.value = null;
    deliveryNotes.value = null;
    activeTabSessionId.value = null;
    discountAmount.value = 0.0;
    discountPercentage.value = 0.0;
    deliveryFee.value = 0.0;
    tipAmount.value = 0.0;
    paymentMethod.value = null;
    errorMessage.value = null;
    lastCreatedOrder.value = null;

    // Si el tenant tiene la propina como obligatoria y aplica al tipo
    // por defecto (dineIn), re-aplicamos el porcentaje default para que
    // el cobro siga siendo coherente con la política tras un reset.
    if (tipMode.value == 'mandatory' && _tipAppliesToCurrentOrderType()) {
      tipAmount.value = tipBaseAmount * tipDefaultPercentage.value;
    }
  }
}
