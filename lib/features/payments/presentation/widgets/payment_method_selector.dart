import 'package:flutter/material.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/widgets/app_filter_chip.dart';

/// Selector compacto de método de pago — chips horizontales.
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PaymentMethod.values.map((m) {
        return AppFilterChip(
          label: _name(m),
          icon: _icon(m),
          selected: selectedMethod == m,
          onTap: enabled ? () => onMethodSelected(m) : () {},
        );
      }).toList(),
    );
  }

  IconData _icon(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.card:
        return Icons.credit_card_outlined;
      case PaymentMethod.transfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.digitalWallet:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethod.nequi:
        return Icons.qr_code_2;
    }
  }

  String _name(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.transfer:
        return 'Transferencia';
      case PaymentMethod.digitalWallet:
        return 'Digital';
      case PaymentMethod.nequi:
        return 'Nequi QR';
    }
  }
}
