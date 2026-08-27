import 'package:flutter/material.dart';
import '../../../../core/config/constants/order_enums.dart';

/// Selector de método de pago como dropdown de una sola línea.
/// Ocupa el espacio de un campo de texto — al tocar abre la lista.
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
    return DropdownButtonFormField<PaymentMethod>(
      initialValue: selectedMethod,
      decoration: InputDecoration(
        labelText: 'Método de pago',
        prefixIcon: Icon(paymentMethodIcon(selectedMethod), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: PaymentMethod.values
          // Nequi QR (API oficial Nequi Conecta) nunca se activó — se saca de
          // las opciones seleccionables, pero el valor del enum se deja para
          // no romper el render de pagos históricos si alguno existiera.
          .where((m) => m != PaymentMethod.nequi)
          .map((m) => DropdownMenuItem(
                value: m,
                child: Row(
                  children: [
                    Icon(paymentMethodIcon(m), size: 18),
                    const SizedBox(width: 10),
                    Text(paymentMethodName(m)),
                  ],
                ),
              ))
          .toList(),
      onChanged: enabled ? (m) { if (m != null) onMethodSelected(m); } : null,
    );
  }
}

IconData paymentMethodIcon(PaymentMethod m) {
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
    case PaymentMethod.brebB:
      return Icons.bolt;
  }
}

String paymentMethodName(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Efectivo';
    case PaymentMethod.card:
      return 'Tarjeta';
    case PaymentMethod.transfer:
      return 'Transferencia';
    case PaymentMethod.digitalWallet:
      return 'Billetera digital';
    case PaymentMethod.nequi:
      return 'Nequi QR';
    case PaymentMethod.brebB:
      return 'Bre-B / Nequi';
  }
}
