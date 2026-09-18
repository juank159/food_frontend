import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';

/// Confirmación del número de turno asignado tras crear una orden con
/// `SellMode.counterTicket()`. El cajero le dice este número al
/// cliente ("tu turno es el 42") — mismo lenguaje visual que
/// `_LlaveCard`/`BrebPaymentDialog` (número grande centrado).
class TicketNumberDialog extends StatelessWidget {
  final int ticketNumber;

  const TicketNumberDialog({super.key, required this.ticketNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined,
                color: AppColors.accent, size: 32),
            const SizedBox(height: 12),
            Text(
              'Turno asignado',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
              child: Text(
                '$ticketNumber',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Decile al cliente su número — se lo llama cuando esté listo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(0, 46),
                ),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
