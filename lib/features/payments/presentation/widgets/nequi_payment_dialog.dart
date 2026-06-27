import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../controllers/nequi_payment_controller.dart';

/// Dialog completo para pago QR Nequi.
///
/// Se abre cuando el cajero elige "Nequi QR" y el [ProcessPaymentDialog]
/// llama a [showNequiPaymentDialog]. Retorna `true` cuando el pago
/// se confirma (el padre puede cerrar el flujo de cobro).
///
/// Flujo:
///   - Genera QR → muestra QR + countdown.
///   - Polling cada 3 s (maneja el [NequiPaymentController]).
///   - Estado `paid` → mensaje de éxito → cierra con `true`.
///   - Estado `expired` → mensaje + botón "Generar nuevo QR".
///   - Botón "Cancelar" en cualquier momento.
class NequiPaymentDialog extends StatefulWidget {
  final NequiPaymentController controller;
  final String orderId;
  final double amount;

  const NequiPaymentDialog({
    super.key,
    required this.controller,
    required this.orderId,
    required this.amount,
  });

  @override
  State<NequiPaymentDialog> createState() => _NequiPaymentDialogState();
}

class _NequiPaymentDialogState extends State<NequiPaymentDialog> {
  @override
  void initState() {
    super.initState();
    // Iniciar generación en el siguiente frame para que el dialog
    // ya esté montado cuando llegue la respuesta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.generateQR(
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
                  const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pago con Nequi',
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
      case NequiPaymentState.generatingQR:
        return _buildLoading(theme);
      case NequiPaymentState.qrReady:
        return _buildQRReady(context, theme, isSmall);
      case NequiPaymentState.paid:
        return _buildSuccess(context, theme);
      case NequiPaymentState.expired:
        return _buildExpired(context, theme);
      case NequiPaymentState.error:
        return _buildError(context, theme);
      case NequiPaymentState.idle:
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
          Text(
            'Generando QR…',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildQRReady(BuildContext context, ThemeData theme, bool isSmall) {
    final payload = widget.controller.qrPayload.value;
    final type = widget.controller.qrType.value ?? 'text';
    final seconds = widget.controller.secondsLeft.value;
    final expired = seconds <= 0 && widget.controller.expiresAt.value != null;

    return Column(
      children: [
        // Instrucción
        Text(
          'Pide al cliente que abra Nequi y escanee el código',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // QR
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: type == 'base64'
                ? Image.memory(
                    base64Decode(payload),
                    width: isSmall ? 180 : 220,
                    height: isSmall ? 180 : 220,
                    fit: BoxFit.contain,
                  )
                : QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: isSmall ? 180 : 220,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1A1A2E),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
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
              color: seconds <= 60
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          const Icon(Icons.timer_off_outlined, color: Colors.orange, size: 28),
          const SizedBox(height: 4),
          Text('QR expirado', style: theme.textTheme.bodySmall),
        ],

        const SizedBox(height: 20),

        // Indicador de espera
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Esperando confirmación de pago…',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cancelar
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
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nequi procesó el pago correctamente.',
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
          Text(
            'El QR expiró',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'El cliente no escaneó el código a tiempo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
                  label: const Text('Nuevo QR'),
                  onPressed: () => widget.controller.generateQR(
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
          Text(
            'Error al generar QR',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.controller.errorMsg.value,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
                  onPressed: () => widget.controller.generateQR(
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
    if (exp == null) return 300;
    // En el primer render aproximamos desde la config del servidor
    return exp.difference(DateTime.now()).inSeconds.clamp(0, 600);
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

// ── Barra de progreso del countdown ──────────────────────────────────────

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
