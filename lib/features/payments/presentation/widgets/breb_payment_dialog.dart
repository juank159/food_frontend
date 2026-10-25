import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/formatters/datetime_formatter.dart';
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
  /// `false` en el pago por ítems: ahí quien llama asume que el monto se
  /// cubrió completo, así que no se permite asignar a mano un pago menor.
  final bool allowPartialAssign;

  const BrebPaymentDialog({
    super.key,
    required this.controller,
    this.orderId,
    this.tabSessionId,
    required this.amount,
    this.allowPartialAssign = true,
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
                        // El monto a transferir puede venir ajustado (hasta
                        // $9 menos) para que sea único entre los cobros
                        // pendientes — es el que el cliente DEBE enviar.
                        Obx(() {
                          final adj = widget.controller.adjustment;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                CurrencyFormatter.format(_amount),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (adj > 0 &&
                                  widget.controller.state.value == BrebPaymentState.waiting)
                                Text(
                                  'Ajustado −${CurrencyFormatter.format(adj)} para identificar '
                                  'el pago al instante. Pedile al cliente este valor exacto.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                            ],
                          );
                        }),
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
                _LlaveCard(llave: llaves[i], amount: _amount),
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
        const SizedBox(height: 8),
        _findReceivedButton(),
        const SizedBox(height: 8),

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

  /// Red de seguridad: el cliente ya transfirió pero el pago no se
  /// asignó solo (mandó otro valor, llegó tarde…). El cajero lo busca
  /// entre los pagos recibidos y lo asigna a esta venta.
  Widget _findReceivedButton() {
    return TextButton.icon(
      icon: const Icon(Icons.manage_search, size: 18),
      label: const Text('¿Ya pagó y no se confirma? Buscar pago'),
      onPressed: _openReceivedPayments,
    );
  }

  Future<void> _openReceivedPayments() async {
    final picked = await showDialog<BrebReceivedPayment>(
      context: context,
      builder: (_) => _ReceivedPaymentsDialog(
        controller: widget.controller,
        expected: _amount,
        allowPartial: widget.allowPartialAssign,
      ),
    );
    if (picked == null || !mounted) return;
    final err = await widget.controller.assignReceived(picked);
    if (err != null) AppSnackbar.show('No se pudo asignar', err);
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
            CurrencyFormatter.format(_amount),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (_isPartial) ...[
            const SizedBox(height: 4),
            Text(
              'Abono — queda saldo pendiente por cobrar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
          const SizedBox(height: 8),
          _findReceivedButton(),
          const SizedBox(height: 12),
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

  /// Monto del cobro en curso (el ajustado si el backend lo ajustó).
  double get _amount {
    final v = widget.controller.chargeAmount.value;
    return v > 0 ? v : widget.amount;
  }

  /// Se asignó a mano un pago menor que lo que se debía (más allá del
  /// redondeo de hasta $9): quedó como abono.
  bool get _isPartial =>
      widget.controller.requestedAmount.value - widget.controller.chargeAmount.value > 9.009;

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

/// Lista de pagos Bre-B recibidos sin asignar (últimas 24 h). El cajero
/// toca el que corresponde a esta venta.
class _ReceivedPaymentsDialog extends StatefulWidget {
  final BrebPaymentController controller;
  final double expected;
  final bool allowPartial;
  const _ReceivedPaymentsDialog({
    required this.controller,
    required this.expected,
    required this.allowPartial,
  });

  @override
  State<_ReceivedPaymentsDialog> createState() => _ReceivedPaymentsDialogState();
}

class _ReceivedPaymentsDialogState extends State<_ReceivedPaymentsDialog> {
  late Future<List<BrebReceivedPayment>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadUnassigned();
  }

  void _reload() => setState(() => _future = widget.controller.loadUnassigned());

  Future<void> _pick(BrebReceivedPayment p) async {
    final diff = widget.expected - p.amount;
    String? warning;
    if (diff > 9.009 && !widget.allowPartial) {
      AppSnackbar.show(
        'Pago menor al cobro',
        'En el pago por ítems no se puede asignar un pago menor. '
            'Cerrá y cobrá ese valor desde "Cobrar" (abono).',
      );
      return;
    }
    if (diff > 9.009) {
      warning = 'Este pago es MENOR que el cobro: se registra como abono de '
          '${CurrencyFormatter.format(p.amount)} y quedan '
          '${CurrencyFormatter.format(diff)} pendientes.';
    } else if (diff < -0.009) {
      warning = 'Este pago es MAYOR que el cobro: se registra '
          '${CurrencyFormatter.format(widget.expected)} (lo que se debía).';
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Asignar este pago a la venta?'),
        content: Text(
          '${CurrencyFormatter.format(p.amount)}'
          '${p.payerName != null && p.payerName!.isNotEmpty ? ' de ${p.payerName}' : ''}'
          '${warning != null ? '\n\n$warning' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Asignar')),
        ],
      ),
    );
    if ((ok ?? false) && mounted) Navigator.pop(context, p);
  }

  String _time(DateTime? d) => d == null ? '' : DateTimeFormatter.timeOnly(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Pagos recibidos sin asignar'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 360,
        child: FutureBuilder<List<BrebReceivedPayment>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se pudo cargar (¿hay internet?).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Todavía no llegó ningún pago sin asignar. Si el cliente '
                  'acaba de transferir, esperá unos segundos y actualizá.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = items[i];
                final exact = (widget.expected - p.amount).abs() < 0.01;
                return ListTile(
                  leading: Icon(
                    exact ? Icons.check_circle : Icons.payments_outlined,
                    color: exact ? Colors.green : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    CurrencyFormatter.format(p.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text([
                    if (p.payerName != null && p.payerName!.isNotEmpty) p.payerName!,
                    if (p.bankLabel != null && p.bankLabel!.isNotEmpty) p.bankLabel!,
                    _time(p.receivedAt),
                  ].where((x) => x.isNotEmpty).join(' · ')),
                  onTap: () => _pick(p),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Actualizar'),
          onPressed: _reload,
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
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
