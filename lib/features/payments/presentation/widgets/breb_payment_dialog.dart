import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../controllers/breb_payment_controller.dart';

/// Dialog completo para cobro Bre-B (transferencia directa con llave).
///
/// Se abre cuando el cajero elige "Bre-B / Nequi" y el [ProcessPaymentDialog]
/// llama a [showBrebPaymentDialog] (invocación análoga a Nequi QR). Retorna
/// `true` cuando el pago se confirma.
///
/// A diferencia del flujo QR de Nequi, acá no hay nada que escanear: el
/// cajero le lee/muestra la llave al cliente, que transfiere desde su banco.
/// La confirmación llega por el correo que reenvía el negocio — el backend
/// la concilia y avisa por push (con red de seguridad de polling cada 3 s).
class BrebPaymentDialog extends StatefulWidget {
  final BrebPaymentController controller;
  final String orderId;
  final double amount;

  const BrebPaymentDialog({
    super.key,
    required this.controller,
    required this.orderId,
    required this.amount,
  });

  @override
  State<BrebPaymentDialog> createState() => _BrebPaymentDialogState();
}

class _BrebPaymentDialogState extends State<BrebPaymentDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.createCharge(
        orderId: widget.orderId,
        amount: widget.amount,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final isSmall = mq.size.height < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12 : 24,
        vertical: isSmall ? 12 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: mq.size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(isSmall ? 14 : 20),
              decoration: BoxDecoration(
                color: const Color(0xFF32AF60), // Verde Nequi
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pago con Bre-B',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(widget.amount),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _cancel,
                  ),
                ],
              ),
            ),

            // ── Body reactivo ────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmall ? 14 : 20),
                child: Obx(() => _buildBody(context, theme, isSmall)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, bool isSmall) {
    switch (widget.controller.state.value) {
      case BrebPaymentState.creatingCharge:
        return _buildLoading(theme);
      case BrebPaymentState.waiting:
        return _buildWaiting(context, theme, isSmall);
      case BrebPaymentState.paid:
        return _buildSuccess(context, theme);
      case BrebPaymentState.expired:
        return _buildExpired(context, theme);
      case BrebPaymentState.error:
        return _buildError(context, theme);
      case BrebPaymentState.idle:
        return _buildLoading(theme);
    }
  }

  Widget _buildLoading(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Iniciando cobro…', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildWaiting(BuildContext context, ThemeData theme, bool isSmall) {
    final llave = widget.controller.llave.value;
    final seconds = widget.controller.secondsLeft.value;
    final expired = seconds <= 0 && widget.controller.expiresAt.value != null;

    return Column(
      children: [
        Text(
          'Dale esta llave al cliente para que transfiera desde su banco',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Llave — texto grande, copiable
        if (llave.isNotEmpty)
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Clipboard.setData(ClipboardData(text: llave));
                AppSnackbar.show('Copiado', 'Llave copiada al portapapeles');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF32AF60), width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      llave,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A1A2E),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Toca para copiar',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Configurá la llave Bre-B del negocio en Ajustes → Pagos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),

        const SizedBox(height: 16),

        // Countdown
        if (!expired) ...[
          _CountdownBar(secondsLeft: seconds, totalSeconds: _totalSeconds()),
          const SizedBox(height: 4),
          Text(
            'Expira en ${_formatSeconds(seconds)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: seconds <= 60 ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          const Icon(Icons.timer_off_outlined, color: Colors.orange, size: 28),
          const SizedBox(height: 4),
          Text('Cobro expirado', style: theme.textTheme.bodySmall),
        ],

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text('Esperando confirmación de pago…', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _cancel,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, ThemeData theme) {
    // Auto-cierre tras 1.5 s para no bloquear al cajero
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (context.mounted) Navigator.pop(context, true);
    });

    final payer = widget.controller.payerName.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Pago confirmado!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(widget.amount),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            payer.isNotEmpty ? 'Transferencia de $payer confirmada.' : 'Transferencia confirmada.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpired(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.timer_off, color: Colors.orange, size: 48),
          const SizedBox(height: 12),
          Text('El cobro expiró', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'El cliente no transfirió a tiempo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                  onPressed: () => widget.controller.createCharge(
                    orderId: widget.orderId,
                    amount: widget.amount,
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
          const SizedBox(height: 12),
          Text('Error al iniciar el cobro', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            widget.controller.errorMsg.value,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                  onPressed: () => widget.controller.createCharge(
                    orderId: widget.orderId,
                    amount: widget.amount,
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cancel() {
    widget.controller.cancel();
    Navigator.pop(context, false);
  }

  int _totalSeconds() {
    final exp = widget.controller.expiresAt.value;
    if (exp == null) return 600;
    return exp.difference(DateTime.now()).inSeconds.clamp(0, 600);
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

class _CountdownBar extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const _CountdownBar({required this.secondsLeft, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final ratio = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;
    final Color color = ratio > 0.4
        ? Colors.green
        : ratio > 0.15
            ? Colors.orange
            : Colors.red;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 6,
      ),
    );
  }
}
