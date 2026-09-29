import 'package:flutter/material.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import 'payment_method_selector.dart';

/// Color de acento por método — usado acá y en cualquier otro lugar que
/// necesite distinguir visualmente el método antes de confirmar un cobro.
Color paymentMethodColor(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return const Color(0xFF2E7D32); // verde efectivo
    case PaymentMethod.card:
      return const Color(0xFF1565C0); // azul tarjeta
    case PaymentMethod.transfer:
      return const Color(0xFF6A1B9A); // violeta transferencia
    case PaymentMethod.digitalWallet:
      return const Color(0xFF00838F); // teal billetera
    case PaymentMethod.nequi:
    case PaymentMethod.brebB:
      return const Color(0xFF32AF60); // verde Nequi/Bre-B
  }
}

/// Último paso antes de procesar CUALQUIER cobro — en los 3 lugares
/// donde se puede confirmar un pago (orden individual, cuenta abierta,
/// cobro por ítems). Muestra bien grande el monto y el método elegido
/// para que un cajero que dejó el método por defecto sin fijarse lo
/// note ACÁ, antes de que el pago se procese — no después.
///
/// Devuelve `true` solo si el usuario tocó "Confirmar cobro".
class PaymentConfirmationDialog extends StatelessWidget {
  final double amount;
  final PaymentMethod method;
  /// Cuenta puntual elegida (ej. "Bancolombia negocio"), si aplica.
  final String? accountName;
  /// Contexto adicional — ej. "Mesa 5", "2 ítems seleccionados".
  final String? subtitle;

  const PaymentConfirmationDialog({
    super.key,
    required this.amount,
    required this.method,
    this.accountName,
    this.subtitle,
  });

  /// Atajo — abre el diálogo y devuelve `true` solo si se confirmó.
  static Future<bool> show(
    BuildContext context, {
    required double amount,
    required PaymentMethod method,
    String? accountName,
    String? subtitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentConfirmationDialog(
        amount: amount,
        method: method,
        accountName: accountName,
        subtitle: subtitle,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = paymentMethodColor(method);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(paymentMethodIcon(method), color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Vas a cobrar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                accountName != null
                    ? '${paymentMethodName(method)} · $accountName'
                    : paymentMethodName(method),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    child: const Text('Revisar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size(0, 46),
                    ),
                    child: const Text('Confirmar cobro'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
