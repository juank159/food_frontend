import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/order.dart' as order_entity;

/// Tarjeta de orden — diseño moderno tipo Linear / Notion / Toast POS:
///
///   - Stripe vertical con el color del estado (lectura periférica rápida).
///   - Header con el número de orden grande, tipo de orden y estado.
///   - Línea informativa con cliente / mesa / cantidad de items.
///   - Footer con total prominente, badge de pago y "hace X min".
///
/// El objetivo es que un mozo pueda escanear 20 tarjetas y entender el
/// estado de cada orden sin leer texto.
class OrderCard extends StatelessWidget {
  final order_entity.Order order;
  final VoidCallback? onTap;

  /// Callback opcional para "Cobrar" — abre el flujo de pago directo.
  /// Si la orden pertenece a una cuenta abierta, la card lo ignora y
  /// muestra "Ver cuenta" (que va al cobro consolidado vía
  /// `onOpenTabSession`).
  final VoidCallback? onCharge;

  /// Callback opcional para "Ver cuenta" — abre el detalle/cobro de la
  /// TabSession a la que pertenece esta orden. Si es null pero la orden
  /// pertenece a un tab, se cae al onTap normal.
  final VoidCallback? onOpenTabSession;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onCharge,
    this.onOpenTabSession,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          // Sombra muy sutil tipo Material 3 — más "flat" que el Card por
          // defecto. Profundidad la da la stripe lateral, no la sombra.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Stripe vertical de color por estado — el "indicador de
                // estado" más legible periféricamente.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(statusColor),
                        const SizedBox(height: 10),
                        _buildContextRow(),
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 1, color: AppColors.divider),
                        const SizedBox(height: 12),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Header ────────────────────────────

  Widget _buildHeader(Color statusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar redondo con el icono del tipo de orden — escanea más
        // rápido que un icono "pelado" al lado del número.
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _orderTypeIcon(order.orderType),
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _destinationText(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(status: order.status, color: statusColor),
      ],
    );
  }

  // ───────────────────────── Context row ─────────────────────────

  /// Línea con chips informativos: referencia de origen (mesa / para
  /// llevar / domicilio), cliente, items, ETA. Wrap para que si no hay
  /// suficiente ancho (mobile chico) se vayan a la siguiente fila.
  ///
  /// El primer chip siempre indica DÓNDE se entrega la orden — clave
  /// para el flujo "lista para entregar, ¿a quién?".
  Widget _buildContextRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _originChip(),
        // Badge de cuenta abierta: deja claro que esta orden está dentro
        // de una cuenta (se cobra consolidado desde "Cuentas abiertas").
        // Sin esto, el usuario no entendía por qué la orden vivía en dos
        // lugares.
        if (order.belongsToTabSession)
          _InfoChip(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Cuenta abierta',
            accent: AppColors.info,
            // Tap → salta directo a la cuenta (cobro consolidado). Si el
            // card se usa sin el callback, queda como badge no-tappable.
            onTap: onOpenTabSession,
          ),
        // Cliente — pero NO si su nombre ya es el destino (ej. venta de
        // mostrador: "Mostrador" ya sale como chip de origen, no lo
        // repetimos).
        if (order.hasCustomer &&
            (order.customerName?.trim() ?? '') != _destinationText())
          _InfoChip(
            icon: Icons.person_outline,
            label: order.customerName ?? 'Cliente',
          ),
        _InfoChip(
          icon: Icons.shopping_bag_outlined,
          label: '${order.totalItems} ${order.totalItems == 1 ? "item" : "items"}',
        ),
        if (order.estimatedTime != null && order.estimatedTime! > 0)
          _InfoChip(
            icon: Icons.schedule,
            label: '${order.estimatedTime} min',
          ),
      ],
    );
  }

  /// Chip de origen de la orden, prioritario y siempre visible:
  ///   - con etiqueta propia (mesa "Mesa 7" o cuenta libre "papa") → la etiqueta
  ///   - takeaway → "Para llevar"
  ///   - delivery → "Domicilio"
  ///   - dine-in sin mesa → "Sin mesa"
  _InfoChip _originChip() =>
      _InfoChip(icon: _originIcon(), label: _destinationText());

  /// `true` si la orden tiene una etiqueta propia: una mesa o una cuenta
  /// libre con nombre (`tableLabel`, ej. "papa"). Las cuentas libres NO
  /// tienen `tableElementId`, así que `hasTable` no las detecta — por eso
  /// miramos también `tableLabel`.
  bool get _hasOwnLabel {
    final label = order.tableLabel?.trim();
    return (label != null && label.isNotEmpty) || order.hasTable;
  }

  /// Texto de destino: etiqueta propia o, si no hay, el tipo coloquial.
  /// Evita mostrar "Para llevar" en cuentas libres que NUNCA fueron para
  /// llevar (el bug que reportó el usuario).
  String _destinationText() {
    if (_hasOwnLabel) return order.displayTableLabel;
    switch (order.orderType) {
      case OrderType.takeaway:
        return 'Para llevar';
      case OrderType.delivery:
        return 'Domicilio';
      case OrderType.dineIn:
        return 'Sin mesa';
    }
  }

  IconData _originIcon() {
    if (order.hasTable) return Icons.table_restaurant_outlined;
    if (_hasOwnLabel) return Icons.receipt_long_outlined; // cuenta libre
    switch (order.orderType) {
      case OrderType.takeaway:
        return Icons.takeout_dining_outlined;
      case OrderType.delivery:
        return Icons.delivery_dining_outlined;
      case OrderType.dineIn:
        return Icons.table_restaurant_outlined;
    }
  }

  // ─────────────────────────── Footer ────────────────────────────

  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.format(order.totalAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Si hay pago parcial, mostrar "Pagado X · Falta Y"
                  // antes del tiempo. Es la señal visual más fuerte que
                  // "ya cobré algo" — el badge "Parcial NN%" lo
                  // confirma a la derecha.
                  if (order.hasPartialPayment) ...[
                    Text(
                      'Pagado ${CurrencyFormatter.format(order.paidAmount)} · '
                      'Falta ${CurrencyFormatter.format(order.balance)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _relativeTime(order.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _PaymentBadge(order: order),
          ],
        ),
        // Acción de cobro contextual — solo cuando es relevante:
        //   - Pago pendiente Y la orden ya pasó la cocina (ready/delivered/
        //     completed). Pedir cobrar una orden en `preparing` confundiría
        //     al cajero.
        //   - Para órdenes de cuenta abierta, el botón lleva a la pantalla
        //     de la cuenta (cobro consolidado).
        //   - Para órdenes sueltas (sin tab), abre el dialog de cobro
        //     directo de esta orden.
        if (order.isReadyToCharge) ...[
          const SizedBox(height: 10),
          _ChargeAction(
            order: order,
            onCharge: onCharge,
            onOpenTabSession: onOpenTabSession,
          ),
        ],
      ],
    );
  }

  // ─────────────────────────── Helpers ───────────────────────────

  static Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingReview:
        // Self-order esperando aprobación — naranja vibrante distinto
        // del warning normal para que se vea como "necesita atención".
        return Colors.deepOrange;
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return const Color(0xFF8E44AD); // púrpura distintiva para "en cocina"
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivered:
        return const Color(0xFF14B8A6); // teal
      case OrderStatus.completed:
        return AppColors.textSecondary;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  static IconData _orderTypeIcon(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return Icons.restaurant;
      case OrderType.takeaway:
        return Icons.takeout_dining;
      case OrderType.delivery:
        return Icons.delivery_dining;
    }
  }

  /// Tiempo relativo estilo "hace 5 min" / "hace 2 h" / "ayer". Para
  /// rangos largos cae a la fecha completa para no decir "hace 18 días".
  static String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative) return DateFormat('dd/MM HH:mm').format(date);
    if (diff.inSeconds < 60) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}

/// Pill de estado — fondo tintado + texto en color sólido. Misma altura
/// que el avatar para que la fila quede alineada.
class _StatusPill extends StatelessWidget {
  final OrderStatus status;
  final Color color;
  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip informativo neutral — para cliente, mesa, items, ETA. Se usa en
/// `Wrap` para que se acomoden solos.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Si viene, el chip se vuelve tappable (InkWell + chevron) — lo usa
  /// el badge "Cuenta abierta" para saltar directo a la cuenta.
  final VoidCallback? onTap;

  /// Color de acento opcional (fondo tenue + texto/ícono) para destacar
  /// el chip por sobre los neutrales.
  final Color? accent;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? AppColors.textPrimary;
    final iconColor = accent ?? AppColors.textSecondary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent != null
            ? accent!.withValues(alpha: 0.10)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: iconColor),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: chip,
    );
  }
}

/// Badge de pago.
///
/// Tres estados visuales:
///   - **Pagado** (verde): pago efectivamente completado.
///   - **En cuenta** (azul): la orden vive dentro de una TabSession.
///     El cobro NO se hace por orden sino consolidado desde la cuenta.
///     Mostrar "Pendiente" en esta orden es engañoso — el cajero ve
///     "pendiente" en 4 órdenes de la misma mesa y piensa que tiene
///     que cobrar 4 veces.
///   - **Por cobrar** (ámbar): orden suelta con pago pendiente.
class _PaymentBadge extends StatelessWidget {
  final order_entity.Order order;
  const _PaymentBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;

    if (order.isPaymentCompleted) {
      color = AppColors.success;
      icon = Icons.check_circle;
      label = 'Pagado';
    } else if (order.hasPartialPayment) {
      // Pago parcial: el cajero ya cobró algo pero falta. Mostramos el
      // % cobrado para que sea claro al volver al listado que el pago
      // SÍ quedó registrado.
      color = AppColors.info;
      icon = Icons.pie_chart;
      final pct = order.totalAmount > 0
          ? ((order.paidAmount / order.totalAmount) * 100).round()
          : 0;
      label = 'Parcial $pct%';
    } else if (order.belongsToTabSession) {
      color = AppColors.info;
      icon = Icons.receipt_long;
      label = 'En cuenta';
    } else {
      color = AppColors.warning;
      icon = Icons.schedule;
      label = 'Por cobrar';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción de cobro inline en el footer de la card.
///
/// - Si la orden pertenece a una cuenta abierta → "Ver cuenta" (lleva
///   al cobro consolidado).
/// - Si es orden suelta → "Cobrar ahora" (abre el dialog de pago
///   directo de esta orden).
///
/// El callback puede ser null — en ese caso la action queda
/// disabled (informativa). Eso evita un caller a medio cablear que
/// rompa la card.
class _ChargeAction extends StatelessWidget {
  final order_entity.Order order;
  final VoidCallback? onCharge;
  final VoidCallback? onOpenTabSession;

  const _ChargeAction({
    required this.order,
    required this.onCharge,
    required this.onOpenTabSession,
  });

  @override
  Widget build(BuildContext context) {
    final isTab = order.belongsToTabSession;
    final cb = isTab ? onOpenTabSession : onCharge;
    final color = isTab ? AppColors.info : AppColors.warning;

    final partial = order.hasPartialPayment;
    final cobrarLabel = isTab
        ? 'Ver cuenta y cobrar'
        : (partial ? 'Cobrar resto' : 'Cobrar ahora');

    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: cb,
        icon: Icon(
          isTab ? Icons.receipt_long : Icons.payments_outlined,
          size: 16,
        ),
        label: Text(
          cobrarLabel,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
