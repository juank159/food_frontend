import 'package:flutter/material.dart';
import '../../../../core/config/constants/order_enums.dart';

/// Payment Method Selector
/// Widget moderno para seleccionar el método de pago
class PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selectedMethod;
  final Function(PaymentMethod) onMethodSelected;
  final bool enabled;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de Pago',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...PaymentMethod.values.map((method) {
          final isSelected = selectedMethod == method;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildMethodCard(
              context,
              method,
              isSelected,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMethodCard(
    BuildContext context,
    PaymentMethod method,
    bool isSelected,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? () => onMethodSelected(method) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getMethodIcon(method),
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getMethodName(method),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMethodDescription(method),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Radio indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 24,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: theme.colorScheme.outline,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
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

  String _getMethodDescription(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Pago en efectivo con cambio';
      case PaymentMethod.card:
        return 'Tarjeta de crédito o débito';
      case PaymentMethod.transfer:
        return 'Transferencia bancaria';
      case PaymentMethod.digitalWallet:
        return 'Nequi, Daviplata, etc.';
    }
  }
}
