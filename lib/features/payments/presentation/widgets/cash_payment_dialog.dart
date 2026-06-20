import 'package:flutter/material.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Cash Payment Dialog
/// Dialog para procesar pagos en efectivo con calculadora de cambio
class CashPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Function(double receivedAmount) onConfirm;

  const CashPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  State<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<CashPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  double _receivedAmount = 0.0;
  double _change = 0.0;

  // Denominaciones colombianas (billetes/monedas comunes en COP).
  // `10/20/50` que había antes NO tenían sentido — los billetes en
  // Colombia arrancan en $1.000. El operario en el día a día recibe
  // estos valores: $1k, $2k, $5k, $10k, $20k, $50k, $100k.
  final List<double> _quickAmounts = [
    1000, 2000, 5000, 10000, 20000, 50000, 100000,
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final amount = (NumberFormatHelper.parseFormattedInt(_amountController.text) ?? 0).toDouble();
    setState(() {
      _receivedAmount = amount;
      _change = amount - widget.totalAmount;
    });
  }

  void _addQuickAmount(double amount) {
    final currentAmount = (NumberFormatHelper.parseFormattedInt(_amountController.text) ?? 0).toDouble();
    final newAmount = (currentAmount + amount).toInt();
    _amountController.text = NumberFormatHelper.formatNumber(newAmount);
  }

  void _setExactAmount() {
    _amountController.text = NumberFormatHelper.formatNumber(widget.totalAmount.toInt());
  }

  bool get _canConfirm => _receivedAmount >= widget.totalAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    // Acotamos ancho Y alto + scroll: en pantallas chicas el contenido
    // (input + denominaciones + cambio + botones) superaba el alto del
    // dialog y desbordaba 126px. Ahora scrollea y nunca desborda.
    final maxW = screen.width < 600 ? screen.width * 0.92 : 500.0;
    final maxH = screen.height * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 600 ? 16 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payments,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pago en Efectivo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total: ${CurrencyFormatter.format(widget.totalAmount)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Monto Recibido',
                  prefixText: '\$',
                  hintText: '10.000',
                  helperText: 'Formato automático con separadores de miles',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _amountController.clear(),
                    tooltip: 'Limpiar',
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  ThousandsSeparatorInputFormatter(),
                ],
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Quick Amount Button
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.speed),
                  label: const Text('Monto Exacto'),
                  onPressed: _setExactAmount,
                ),
              ),
              const SizedBox(height: 16),

              // Quick Amounts
              Text(
                'Denominaciones Rápidas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amount) {
                  // Formatear con CurrencyFormatter para consistencia
                  // (`+$1.000` en vez de `+$1000`).
                  return FilledButton.tonal(
                    onPressed: () => _addQuickAmount(amount),
                    child: Text('+${CurrencyFormatter.format(amount)}'),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Change Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _change >= 0
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recibido:',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          CurrencyFormatter.format(_receivedAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          CurrencyFormatter.format(widget.totalAmount),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cambio:',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _change >= 0
                              ? CurrencyFormatter.format(_change)
                              : 'Falta: ${CurrencyFormatter.format((-_change))}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _change >= 0
                                ? Colors.green.shade700
                                : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons — Expanded para que SIEMPRE quepan (antes
              // "Cancelar" + "Confirmar Pago" desbordaban 45px a la derecha
              // en pantallas angostas).
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Cancelar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _canConfirm
                        ? () {
                            // IMPORTANTE: cerrar el dialog ANTES de
                            // disparar el callback async. Si invertís
                            // el orden (callback primero, pop después),
                            // el callback async dispara `_executePayment`
                            // que necesita un context vivo; al cerrarse
                            // este dialog, ese context muere y el pop
                            // final del ProcessPaymentDialog no llega
                            // a ejecutarse (`context.mounted == false`).
                            //
                            // Cerrando primero: el callback usa el
                            // context del padre (ProcessPaymentDialog)
                            // que SÍ sigue vivo, y el pop final
                            // funciona como se espera.
                            final amount = _receivedAmount;
                            Navigator.pop(context);
                            widget.onConfirm(amount);
                          }
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'Confirmar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
