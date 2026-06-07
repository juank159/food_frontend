import 'package:flutter/material.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/payment.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Payment Summary Card
/// Card que muestra el resumen de pagos de una orden
class PaymentSummaryCard extends StatelessWidget {
  final List<Payment> payments;
  final double orderTotal;
  final VoidCallback? onViewDetails;
  final VoidCallback? onAddPayment;

  const PaymentSummaryCard({
    super.key,
    required this.payments,
    required this.orderTotal,
    this.onViewDetails,
    this.onAddPayment,
  });

  double get _totalPaid {
    return payments
        .where((p) => p.status == PaymentStatus.completed)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double get _remaining => orderTotal - _totalPaid;

  bool get _isFullyPaid => _remaining <= 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      gradient: _isFullyPaid
          ? LinearGradient(
              colors: [Colors.green.shade300, Colors.green.shade500],
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _isFullyPaid ? Icons.check_circle : Icons.payment,
                  color: _isFullyPaid
                      ? Colors.white
                      : theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de Pago',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isFullyPaid ? Colors.white : null,
                        ),
                      ),
                      Text(
                        _isFullyPaid ? 'Pagado Completo' : 'Pago Pendiente',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isFullyPaid
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: _isFullyPaid ? 'PAGADO' : 'PENDIENTE',
                  color: _isFullyPaid ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const Divider(height: 24),

            // Payment Details
            _buildAmountRow(
              theme,
              'Total de la Orden',
              orderTotal,
              isBold: false,
            ),
            const SizedBox(height: 8),
            _buildAmountRow(
              theme,
              'Total Pagado',
              _totalPaid,
              color: Colors.green,
              isBold: false,
            ),
            if (!_isFullyPaid) ...[
              const SizedBox(height: 8),
              _buildAmountRow(
                theme,
                'Restante',
                _remaining,
                color: Colors.orange,
                isBold: true,
              ),
            ],

            // Payment Methods Summary
            if (payments.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Métodos de Pago',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isFullyPaid ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 12),
              ..._buildPaymentMethodsSummary(theme),
            ],

            // Actions
            if (onViewDetails != null || onAddPayment != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onViewDetails != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Ver Detalles'),
                        onPressed: onViewDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              _isFullyPaid ? Colors.white : null,
                          side: BorderSide(
                            color: _isFullyPaid
                                ? Colors.white
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  if (onViewDetails != null && onAddPayment != null)
                    const SizedBox(width: 12),
                  if (onAddPayment != null && !_isFullyPaid)
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar Pago'),
                        onPressed: onAddPayment,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    ThemeData theme,
    String label,
    double amount, {
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: _isFullyPaid
                ? Colors.white
                : color ?? theme.colorScheme.onSurface,
          ),
        ),
        Text(
          '${CurrencyFormatter.format(amount)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: _isFullyPaid
                ? Colors.white
                : color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPaymentMethodsSummary(ThemeData theme) {
    // Agrupar pagos por método
    final methodTotals = <PaymentMethod, double>{};

    for (final payment in payments) {
      if (payment.status == PaymentStatus.completed) {
        methodTotals[payment.paymentMethod] =
            (methodTotals[payment.paymentMethod] ?? 0) + payment.amount;
      }
    }

    return methodTotals.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              _getMethodIcon(entry.key),
              size: 18,
              color: _isFullyPaid
                  ? Colors.white70
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getMethodName(entry.key),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isFullyPaid
                      ? Colors.white70
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${CurrencyFormatter.format(entry.value)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _isFullyPaid ? Colors.white : null,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

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
    }
  }
}
