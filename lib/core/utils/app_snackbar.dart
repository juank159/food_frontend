// lib/core/utils/app_snackbar.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// AppSnackbar — drop-in replacement de `Get.snackbar`.
///
/// **Por qué existe:**
///
/// `Get.snackbar` encola el snackbar en una cola async fire-and-forget
/// (`GetQueue._check`). Si el route donde se llamó se desmonta antes de
/// que la cola lo procese (caso típico: snackbar + navegación back-to-back,
/// dialog cerrado + snackbar, login exitoso + redirect), `SnackbarController`
/// busca el Overlay del route ya muerto → `No Overlay widget found` →
/// `Unhandled Exception` que NO se puede atrapar con try/catch porque
/// sucede fuera del scope que invocó `Get.snackbar`.
///
/// **Qué hace `AppSnackbar`:**
///
///   1. Busca el `BuildContext` activo (parámetro `context` si se pasó,
///      o `Get.context` como fallback).
///   2. Si NO hay context montado, hace silent log y retorna — NUNCA
///      crashea la app.
///   3. Si hay context, usa `ScaffoldMessenger.maybeOf(context)` —
///      Material estándar, NO usa el Overlay flotante de GetX que es
///      el que tiene el bug. El snackbar vive dentro del Scaffold del
///      route activo, así que cuando el route muere, el snackbar muere
///      con él (sin error).
///
/// **API:** mismas posicionales (`title`, `message`) y named params
/// principales que `Get.snackbar` (`backgroundColor`, `colorText`,
/// `duration`, `icon`). Drop-in: solo cambia `Get.snackbar(` →
/// `AppSnackbar.show(`.
class AppSnackbar {
  AppSnackbar._();

  /// Muestra un snackbar de forma segura.
  ///
  /// `context` es opcional — si se pasa, se prioriza. Si no, se usa
  /// `Get.context` (el del último route activo). Pasarlo es más seguro
  /// cuando se llama desde un widget que tiene su propio `BuildContext`.
  static void show(
    String title,
    String message, {
    BuildContext? context,
    Color? backgroundColor,
    Color? colorText,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    // Otros params de Get.snackbar que ignoramos a propósito porque no
    // tienen equivalente directo en SnackBar de Material (snackPosition,
    // margin, borderRadius, etc.). Se aceptan para ser drop-in pero no
    // afectan el resultado — el SnackBar nativo siempre va al bottom
    // con behavior floating, que es lo estándar de Material.
    Object? snackPosition,
    EdgeInsets? margin,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
    Duration? animationDuration,
    String? mainButton,
    VoidCallback? onTap,
  }) {
    final ctx = context ?? Get.context;
    if (ctx == null || !ctx.mounted) {
      debugPrint(
        '[AppSnackbar suppressed — no context] $title — $message',
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) {
      debugPrint(
        '[AppSnackbar suppressed — no ScaffoldMessenger] $title — $message',
      );
      return;
    }

    final hasTitle = title.trim().isNotEmpty;
    final hasMessage = message.trim().isNotEmpty;
    final effectiveColorText = colorText ?? Colors.white;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: behavior,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: effectiveColorText, size: 20),
                child: icon,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle)
                    Text(
                      title,
                      style: TextStyle(
                        color: effectiveColorText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  if (hasTitle && hasMessage) const SizedBox(height: 2),
                  if (hasMessage)
                    Text(
                      message,
                      style: TextStyle(
                        color: effectiveColorText,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        action: onTap != null
            ? SnackBarAction(
                label: mainButton ?? 'OK',
                textColor: effectiveColorText,
                onPressed: onTap,
              )
            : null,
      ),
    );
  }

  /// Atajo para snackbars de error (fondo rojo).
  static void error(String message, {String title = 'Error'}) {
    show(title, message, backgroundColor: Colors.red.shade400);
  }

  /// Atajo para snackbars de éxito (fondo verde).
  static void success(String message, {String title = '¡Listo!'}) {
    show(title, message, backgroundColor: Colors.green.shade400);
  }

  /// Atajo para snackbars informativos (fondo azul).
  static void info(String message, {String title = 'Info'}) {
    show(title, message, backgroundColor: Colors.blue.shade400);
  }
}
