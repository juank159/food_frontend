import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Payment History Widget
/// Widget para mostrar el historial completo de pagos de una orden
class PaymentHistoryWidget extends StatefulWidget {
  final String orderId;
  final PaymentController? controller;
  final VoidCallback? onRefund;

  const PaymentHistoryWidget({
    super.key,
    required this.orderId,
    this.controller,
    this.onRefund,
  });

  @override
  State<PaymentHistoryWidget> createState() => _PaymentHistoryWidgetState();
}

class _PaymentHistoryWidgetState extends State<PaymentHistoryWidget> {
  PaymentMethod? _filterMethod;
  PaymentStatus? _filterStatus;

  PaymentController get _controller =>
      widget.controller ?? Get.find<PaymentController>();

  @override
  void initState() {
    super.initState();
    // Diferimos al próximo frame para evitar el crash
    // `setState() or markNeedsBuild() called during build`. El método
    // `loadPaymentsByOrder` setea un `Rx` que ya tiene listeners
    // (los `Obx` del árbol) — si lo llamamos sincrónico desde
    // `initState`, Flutter está en medio del build y rebotar el
    // markNeedsBuild en ese momento crashea.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPayments();
    });
  }

  Future<void> _loadPayments() async {
    await _controller.loadPaymentsByOrder(widget.orderId);
  }

  List<Payment> get _filteredPayments {
    var payments = _controller.payments.where((p) => p.orderId == widget.orderId);

    if (_filterMethod != null) {
      payments = payments.where((p) => p.paymentMethod == _filterMethod);
    }

    if (_filterStatus != null) {
      payments = payments.where((p) => p.status == _filterStatus);
    }

    return payments.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Filters
        _buildHeader(theme),
        const SizedBox(height: 16),

        // Filters
        _buildFilters(theme),
        const SizedBox(height: 16),

        // Payments List
        Obx(() {
          if (_controller.isLoading.value) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final payments = _filteredPayments;

          if (payments.isEmpty) {
            return _buildEmptyState(theme);
          }

          return Column(
            children: payments.map((payment) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPaymentCard(theme, payment),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.history,
          color: theme.colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial de Pagos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Obx(() {
                final payments = _filteredPayments;
                final total = payments
                    .where((p) => p.status == PaymentStatus.completed)
                    .fold(0.0, (sum, p) => sum + p.amount);
                return Text(
                  '${payments.length} pagos • Total: ${CurrencyFormatter.format(total)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadPayments,
          tooltip: 'Recargar',
        ),
      ],
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filter by Method
          _buildFilterChip(
            theme,
            label: 'Todos los métodos',
            icon: Icons.payment,
            isSelected: _filterMethod == null,
            onSelected: () {
              setState(() => _filterMethod = null);
            },
          ),
          const SizedBox(width: 8),
          ...PaymentMethod.values.map((method) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                theme,
                label: _getMethodName(method),
                icon: _getMethodIcon(method),
                isSelected: _filterMethod == method,
                onSelected: () {
                  setState(() => _filterMethod = method);
                },
              ),
            );
          }),
          const SizedBox(width: 16),

          // Filter by Status
          ...PaymentStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                theme,
                label: _getStatusName(status),
                icon: _getStatusIcon(status),
                isSelected: _filterStatus == status,
                color: _getStatusColor(status),
                onSelected: () {
                  setState(() {
                    _filterStatus = _filterStatus == status ? null : status;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    // Usamos `AppFilterChip` (helper compartido del proyecto) en vez
    // del `FilterChip` de Material. El de Material no cambia el color
    // del texto cuando se selecciona, así que con `selectedColor`
    // naranja el label quedaba invisible. `AppFilterChip` garantiza
    // contraste blanco-sobre-acento al seleccionar.
    return AppFilterChip(
      label: label,
      icon: icon,
      selected: isSelected,
      onTap: onSelected,
      accentColor: color,
    );
  }

  Widget _buildPaymentCard(ThemeData theme, Payment payment) {
    return ModernCard(
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Method, Status, Amount
              Row(
                children: [
                  // Method Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getMethodIcon(payment.paymentMethod),
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Method Name & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.tenantPaymentAccountName ??
                              _getMethodName(payment.paymentMethod),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Si hay cuenta concreta, mostramos la categoría
                        // (método) como subtítulo además de la fecha
                        // para conservar el contexto general.
                        if (payment.tenantPaymentAccountName != null)
                          Text(
                            _getMethodName(payment.paymentMethod),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  StatusBadge(
                    label: _getStatusName(payment.status).toUpperCase(),
                    color: _getStatusColor(payment.status),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Amount Details
              _buildDetailRow(
                theme,
                'Monto',
                CurrencyFormatter.format(payment.amount),
                isBold: true,
              ),

              if (payment.isCash && payment.receivedAmount != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  theme,
                  'Recibido',
                  CurrencyFormatter.format(payment.receivedAmount!),
                ),
                if (payment.hasChange)
                  _buildDetailRow(
                    theme,
                    'Cambio',
                    CurrencyFormatter.format(payment.changeAmount!),
                    color: Colors.green,
                  ),
              ],

              if (payment.transactionReference != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  theme,
                  'Referencia',
                  payment.transactionReference!,
                  isMonospace: true,
                ),
              ],

              // Refund Info
              if (payment.isRefunded) ...[
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reembolsado',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      if (payment.refundReason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Razón: ${payment.refundReason}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (payment.refundedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.refundedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Actions
              if (payment.canBeRefunded) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.currency_exchange, size: 18),
                    label: const Text('Reembolsar'),
                    onPressed: () => _showRefundDialog(payment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    String label,
    String value, {
    bool isBold = false,
    bool isMonospace = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: isMonospace ? 'monospace' : null,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay pagos registrados',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filterMethod != null || _filterStatus != null
                  ? 'Intenta cambiar los filtros'
                  : 'Los pagos aparecerán aquí',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetails(Payment payment) {
    final theme = Theme.of(Get.context!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final safeBottom = MediaQuery.of(sheetCtx).viewPadding.bottom;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85 - safeBottom,
          ),
          child: SingleChildScrollView(
            child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, safeBottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Detalles del Pago',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // All payment details
            _buildDetailRow(theme, 'ID', payment.id, isMonospace: true),
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              'Método',
              _getMethodName(payment.paymentMethod),
            ),
            if (payment.tenantPaymentAccountName != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                theme,
                'Cuenta',
                payment.tenantPaymentAccountName!,
              ),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              'Estado',
              _getStatusName(payment.status),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              'Monto',
              CurrencyFormatter.format(payment.amount),
              isBold: true,
            ),

            if (payment.receivedAmount != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                theme,
                'Recibido',
                CurrencyFormatter.format(payment.receivedAmount!),
              ),
            ],

            if (payment.changeAmount != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                theme,
                'Cambio',
                CurrencyFormatter.format(payment.changeAmount!),
                color: Colors.green,
              ),
            ],

            if (payment.transactionReference != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                theme,
                'Referencia',
                payment.transactionReference!,
                isMonospace: true,
              ),
            ],

            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              'Fecha de creación',
              DateFormat('dd/MM/yyyy HH:mm:ss').format(payment.createdAt),
            ),

            if (payment.processedBy.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                theme,
                'Procesado por',
                payment.processedBy,
              ),
            ],

            if (payment.notes != null) ...[
              const Divider(height: 24),
              Text(
                'Notas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                payment.notes!,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
          ),
        );
      },
    );
  }

  void _showRefundDialog(Payment payment) {
    final reasonController = TextEditingController();
    final theme = Theme.of(Get.context!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reembolsar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de reembolsar ${CurrencyFormatter.format(payment.amount)}?',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Razón del reembolso',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.currency_exchange),
            label: const Text('Reembolsar'),
            onPressed: () async {
              Navigator.pop(context);
              await _controller.refundPayment(
                paymentId: payment.id,
                refundReason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : 'Sin razón especificada',
              );
              widget.onRefund?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for display
  IconData _getMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.transfer:
        return Icons.account_balance;
      case PaymentMethod.digitalWallet:
        return Icons.smartphone;
      case PaymentMethod.nequi:
        return Icons.qr_code_2;
    }
  }

  String _getMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.transfer:
        return 'Transferencia';
      case PaymentMethod.digitalWallet:
        return 'Billetera Digital';
      case PaymentMethod.nequi:
        return 'Nequi QR';
    }
  }

  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Icons.pending;
      case PaymentStatus.completed:
        return Icons.check_circle;
      case PaymentStatus.refunded:
        return Icons.currency_exchange;
      case PaymentStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusName(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pendiente';
      case PaymentStatus.completed:
        return 'Completado';
      case PaymentStatus.refunded:
        return 'Reembolsado';
      case PaymentStatus.failed:
        return 'Fallido';
    }
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.refunded:
        return Colors.blue;
      case PaymentStatus.failed:
        return Colors.red;
    }
  }
}
