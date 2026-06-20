import 'package:flutter/material.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';

/// "A quién le vendés" en la pantalla de venta unificada.
///
/// Antes había 4 pantallas distintas para iniciar una venta (Venta
/// Express, Crear Orden, Abrir Cuenta Libre, Tomar Mesa). Todas
/// terminaban en el mismo catálogo, solo cambiaba a qué se ataba la
/// orden. `SellMode` unifica esa decisión en un objeto inmutable que
/// vive en `OrderFormController` y se cambia desde un pill en la
/// pantalla `SellPage` — sin navegar a otra ruta.
///
/// **Tipos:**
///   - `counter`: venta de mostrador, sin mesa ni cliente. Cobro
///     inmediato tras submit (modo "Venta Express").
///   - `dineIn`: orden de mesa (creará/usará una cuenta de mesa).
///   - `takeaway`: para llevar — nombre opcional, sin mesa.
///   - `delivery`: domicilio — nombre + teléfono + dirección obligatorios.
///   - `tabSession`: agregar ticket a una cuenta ya abierta (libre o
///     de mesa). Después del submit vuelve a la cuenta.
sealed class SellMode {
  const SellMode();

  /// Etiqueta corta para mostrar en el pill superior.
  String get pillLabel;

  /// Etiqueta larga (subtítulo en el sheet de cambio de modo).
  String get pillSubtitle;

  /// Icono para el pill.
  IconData get pillIcon;

  /// Color de acento del pill.
  Color get pillColor;

  /// True cuando, tras crear la orden, queremos ABRIR el dialog de
  /// pago directo (modos sin cuenta abierta detrás). False cuando la
  /// orden se agrupa en una cuenta — ahí volvemos a la cuenta y el
  /// cobro es consolidado.
  bool get autoPayAfterSubmit;

  /// True solo para el modo "Mostrador" (venta express). Lo usa el
  /// controller para relajar la validación de cliente.
  bool get isCounter => false;

  /// Tipo de orden que va al backend.
  OrderType get orderType;

  /// Datos de mesa (solo dine-in directo, no para cuentas).
  String? get tableElementId => null;
  String? get tableId => null;
  String? get tableName => null;

  /// ID de la cuenta abierta a la que se adjunta el ticket (solo modo
  /// tabSession). El backend une el ticket nuevo a esa cuenta y los
  /// requisitos de cliente se relajan (la cuenta identifica al grupo).
  String? get tabSessionId => null;

  // ── Factories ─────────────────────────────────────────────────────

  /// Mostrador: venta express, sin mesa ni cliente.
  const factory SellMode.counter() = _CounterMode;

  /// Mesa: orden dine-in atada a una mesa específica.
  const factory SellMode.dineIn({
    required String tableElementId,
    String? tableId,
    required String tableName,
  }) = _DineInMode;

  /// Para llevar (sin mesa).
  const factory SellMode.takeaway() = _TakeawayMode;

  /// Domicilio.
  const factory SellMode.delivery() = _DeliveryMode;

  /// Ticket dentro de una cuenta abierta (libre o de mesa).
  /// `orderType` permite elegir si ESE ticket es en mesa / para llevar /
  /// domicilio, SIN sacarlo de la cuenta (se mantiene `sessionId`).
  const factory SellMode.tabSession({
    required String sessionId,
    required String sessionLabel,
    String? tableElementId,
    String? tableId,
    String? tableName,
    OrderType? orderType,
  }) = _TabSessionMode;

  /// Devuelve una copia del modo con otro `orderType`. Solo tiene efecto
  /// real en `tabSession` (para elegir tipo de entrega del ticket sin
  /// salir de la cuenta); en el resto devuelve el mismo modo.
  SellMode withOrderType(OrderType type) => this;
}

class _CounterMode extends SellMode {
  const _CounterMode();

  @override
  String get pillLabel => 'Mostrador';

  @override
  String get pillSubtitle => 'Cobro inmediato, sin mesa';

  @override
  IconData get pillIcon => Icons.point_of_sale;

  @override
  Color get pillColor => AppColors.accent;

  @override
  bool get autoPayAfterSubmit => true;

  @override
  bool get isCounter => true;

  @override
  OrderType get orderType => OrderType.takeaway;
}

class _DineInMode extends SellMode {
  @override
  final String tableElementId;
  @override
  final String? tableId;
  @override
  final String tableName;

  const _DineInMode({
    required this.tableElementId,
    this.tableId,
    required this.tableName,
  });

  @override
  String get pillLabel => 'Mesa $tableName';

  @override
  String get pillSubtitle => 'Servicio en mesa';

  @override
  IconData get pillIcon => Icons.table_restaurant;

  @override
  Color get pillColor => AppColors.primary;

  @override
  bool get autoPayAfterSubmit => false;

  @override
  OrderType get orderType => OrderType.dineIn;
}

class _TakeawayMode extends SellMode {
  const _TakeawayMode();

  @override
  String get pillLabel => 'Para llevar';

  @override
  String get pillSubtitle => 'Cliente retira en local';

  @override
  IconData get pillIcon => Icons.shopping_bag_outlined;

  @override
  Color get pillColor => AppColors.warning;

  @override
  bool get autoPayAfterSubmit => true;

  @override
  OrderType get orderType => OrderType.takeaway;
}

class _DeliveryMode extends SellMode {
  const _DeliveryMode();

  @override
  String get pillLabel => 'Domicilio';

  @override
  String get pillSubtitle => 'Reparto a la dirección del cliente';

  @override
  IconData get pillIcon => Icons.delivery_dining;

  @override
  Color get pillColor => AppColors.info;

  @override
  bool get autoPayAfterSubmit => true;

  @override
  OrderType get orderType => OrderType.delivery;
}

class _TabSessionMode extends SellMode {
  @override
  final String tabSessionId;
  final String sessionLabel;
  @override
  final String? tableElementId;
  @override
  final String? tableId;
  @override
  final String? tableName;

  /// Tipo elegido para ESTE ticket. Si es null, default = en mesa
  /// (la cuenta implica consumo en el local bajo ese cliente). El
  /// operario puede cambiarlo a para llevar / domicilio.
  final OrderType? _orderTypeOverride;

  const _TabSessionMode({
    required String sessionId,
    required this.sessionLabel,
    this.tableElementId,
    this.tableId,
    this.tableName,
    OrderType? orderType,
  })  : tabSessionId = sessionId,
        _orderTypeOverride = orderType;

  @override
  String get pillLabel {
    final suffix = switch (orderType) {
      OrderType.takeaway => ' · Para llevar',
      OrderType.delivery => ' · Domicilio',
      _ => '',
    };
    return 'Cuenta: $sessionLabel$suffix';
  }

  @override
  String get pillSubtitle => 'El ticket se suma a esta cuenta';

  @override
  IconData get pillIcon => Icons.receipt_long;

  @override
  Color get pillColor => AppColors.success;

  @override
  bool get autoPayAfterSubmit => false;

  @override
  OrderType get orderType => _orderTypeOverride ?? OrderType.dineIn;

  @override
  SellMode withOrderType(OrderType type) => _TabSessionMode(
        sessionId: tabSessionId,
        sessionLabel: sessionLabel,
        tableElementId: tableElementId,
        tableId: tableId,
        tableName: tableName,
        orderType: type,
      );
}
