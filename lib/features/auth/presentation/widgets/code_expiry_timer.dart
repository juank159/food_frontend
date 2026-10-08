import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';

/// Cuenta regresiva visible para los códigos de 6 dígitos (verificación
/// de email / recuperación de contraseña) — el backend los vence a los
/// 10 minutos (`PASSWORD_RESET_TTL_MS`/`EMAIL_VERIFICATION_TTL_MS`).
///
/// Expone `restart()` vía `GlobalKey<CodeExpiryTimerState>` para
/// reiniciar la cuenta cuando se pide un código nuevo (reenviar).
class CodeExpiryTimer extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onExpired;

  const CodeExpiryTimer({
    super.key,
    this.duration = const Duration(minutes: 10),
    this.onExpired,
  });

  @override
  State<CodeExpiryTimer> createState() => CodeExpiryTimerState();
}

class CodeExpiryTimerState extends State<CodeExpiryTimer> {
  late Duration _remaining;
  Timer? _timer;
  bool _expired = false;

  bool get isExpired => _expired;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _remaining = widget.duration;
    _expired = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds <= 1) {
          _remaining = Duration.zero;
          _expired = true;
          _timer?.cancel();
          widget.onExpired?.call();
        } else {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  /// Reinicia la cuenta regresiva — usarlo después de reenviar un
  /// código nuevo (el viejo timer visual ya no aplica).
  void restart() => setState(_start);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final urgent = _remaining.inSeconds <= 60 && !_expired;
    final color = _expired
        ? AppColors.error
        : (urgent ? AppColors.warning : AppColors.textSecondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _expired ? Icons.timer_off_outlined : Icons.timer_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          _expired ? 'El código expiró' : 'Expira en $minutes:$seconds',
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
