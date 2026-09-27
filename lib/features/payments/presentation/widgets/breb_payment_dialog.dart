import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../controllers/breb_payment_controller.dart';

/// Dialog completo para cobro Bre-B (transferencia directa con llave).
///
/// Se abre cuando el cajero elige "Bre-B" y el [ProcessPaymentDialog]
/// llama a [showBrebPaymentDialog] (invocación análoga a Nequi QR). Retorna
/// `true` cuando el pago se confirma.
///
/// El cajero le lee/muestra la llave al cliente, que transfiere desde su
/// banco — y si la llave tiene una plantilla de QR configurada (Ajustes →
/// Bre-B), también puede mostrarle un QR con el monto ya incrustado para
/// que lo escanee en vez de escribir la llave a mano. La confirmación
/// llega por el correo que reenvía el negocio — el backend la concilia y
/// avisa por push (con red de seguridad de polling cada 3 s).
class BrebPaymentDialog extends StatefulWidget {
  final BrebPaymentController controller;
  final String? orderId;
  final String? tabSessionId;
  final double amount;

  const BrebPaymentDialog({
    super.key,
    required this.controller,
    this.orderId,
    this.tabSessionId,
    required this.amount,
  }) : assert(
          (orderId == null) != (tabSessionId == null),
          'Se requiere exactamente uno: orderId o tabSessionId',
        );

  @override
  State<BrebPaymentDialog> createState() => _BrebPaymentDialogState();
}

class _BrebPaymentDialogState extends State<BrebPaymentDialog> {
  void _createCharge() {
    widget.controller.createCharge(
      orderId: widget.orderId,
      tabSessionId: widget.tabSessionId,
      amount: widget.amount,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createCharge());
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
    final llaves = widget.controller.llaves;
    final seconds = widget.controller.secondsLeft.value;
    final expired = seconds <= 0 && widget.controller.expiresAt.value != null;

    return Column(
      children: [
        Text(
          llaves.length > 1
              ? 'Dale al cliente cualquiera de estas llaves para que transfiera desde su banco'
              : 'Dale esta llave al cliente para que transfiera desde su banco',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Llave(s) — texto grande, copiable. El negocio puede tener varias
        // (una por banco): se muestran todas para que el cliente use la
        // que tenga a mano, sin que el cajero tenga que elegir por él.
        if (llaves.isNotEmpty)
          Column(
            children: [
              for (int i = 0; i < llaves.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _LlaveCard(llave: llaves[i], amount: widget.amount),
              ],
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Configurá al menos una llave Bre-B del negocio en Ajustes → Pagos.',
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
                  onPressed: _createCharge,
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
                  onPressed: _createCharge,
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

/// Una llave del negocio, mostrada como tarjeta copiable. Con solo una
/// llave configurada, el `label` es decorativo (se ve chico arriba del
/// número); con varias, es lo que le permite al cliente distinguir
/// "esta es la de Nequi" de "esta es la de Bancolombia".
class _LlaveCard extends StatelessWidget {
  final BrebLlave llave;
  final double amount;
  const _LlaveCard({required this.llave, required this.amount});

  void _showQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _QrPreviewDialog(llave: llave, amount: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF32AF60), width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: llave.llave));
              AppSnackbar.show('Copiado', '${llave.label} copiada al portapapeles');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    llave.label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    llave.llave,
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
          // Solo si el negocio configuró una plantilla de QR para ESTA
          // llave (Ajustes → Bre-B) — si no, el cliente igual puede
          // transferir con el texto de arriba, así que no bloqueamos nada.
          if (llave.qrPayload != null) ...[
            const Divider(height: 1),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: () => _showQr(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 18, color: Color(0xFF32AF60)),
                    SizedBox(width: 6),
                    Text(
                      'Mostrar QR',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF32AF60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pantalla completa del QR — el cliente lo escanea desde acá con la
/// app de su banco. El QR ya tiene el monto exacto de este cobro
/// incrustado (ver `BrebService.buildDynamicQrPayload`), así que no
/// hay que pedirle que lo tipee.
class _QrPreviewDialog extends StatelessWidget {
  final BrebLlave llave;
  final double amount;
  const _QrPreviewDialog({required this.llave, required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              llave.label,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: llave.qrPayload!,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'El cliente escanea con la app de su banco — el monto ya '
              'viene incluido, no hace falta que lo escriba.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
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
