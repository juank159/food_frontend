// lib/core/utils/app_snackbar.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// AppSnackbar — notificación flotante ARRIBA de la pantalla.
///
/// **Por qué no usa el `SnackBar` de Material:**
///
/// `SnackBar`/`ScaffoldMessenger` está anclado al fondo del `Scaffold`
/// por diseño de Material — no tiene ninguna opción para mostrarlo
/// arriba (a diferencia de `Get.snackbar`, que sí soporta
/// `SnackPosition.TOP` pero tiene el bug de cola async descripto abajo).
/// Como el negocio quiere TODAS las notificaciones arriba, este archivo
/// inserta su propio overlay en vez de delegar en el `SnackBar` nativo.
///
/// **Por qué no usa `Get.snackbar` tampoco:**
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
///   3. Inserta una `OverlayEntry` propia en el Overlay RAÍZ de la app
///      (`rootOverlay: true`) — vive por encima de todo, incluidos
///      diálogos abiertos (mismo requisito que tenía el `SnackBar` de
///      antes: mostrar un error mientras `ProcessPaymentDialog` sigue
///      abierto, por ejemplo). Como es el overlay raíz, no depende de
///      que el route que llamó siga vivo — a diferencia de
///      `Get.snackbar`, nunca revienta si el caller ya se desmontó.
///   4. Solo UN toast a la vez: uno nuevo reemplaza (sin animar) al que
///      estuviera mostrándose, en vez de apilarlos.
///
/// **API:** mismas posicionales (`title`, `message`) y named params
/// principales que `Get.snackbar` (`backgroundColor`, `colorText`,
/// `duration`, `icon`). Drop-in: solo cambia `Get.snackbar(` →
/// `AppSnackbar.show(`.
class AppSnackbar {
  AppSnackbar._();

  static OverlayEntry? _currentEntry;
  static Timer? _currentTimer;

  /// Muestra un toast arriba, de forma segura.
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
    // Compat con la firma vieja (basada en SnackBar de Material) y con
    // Get.snackbar — se aceptan para no romper ningún call site, pero no
    // tienen efecto: la posición siempre es arriba y el look es fijo.
    SnackBarBehavior behavior = SnackBarBehavior.floating,
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

    final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
    if (overlay == null) {
      debugPrint(
        '[AppSnackbar suppressed — no Overlay] $title — $message',
      );
      return;
    }

    // Reemplazo instantáneo del toast anterior (si había uno) — nunca
    // apilamos dos a la vez.
    _currentTimer?.cancel();
    _currentTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;

    final effectiveColorText = colorText ?? Colors.white;
    final effectiveBg = backgroundColor ?? const Color(0xFF323232);
    final key = GlobalKey<_TopToastState>();

    late OverlayEntry entry;
    void removeEntry() {
      if (identical(_currentEntry, entry)) {
        _currentTimer?.cancel();
        _currentTimer = null;
        _currentEntry = null;
      }
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _TopToast(
        key: key,
        title: title,
        message: message,
        backgroundColor: effectiveBg,
        colorText: effectiveColorText,
        icon: icon,
        mainButton: mainButton,
        onTap: onTap == null
            ? null
            : () {
                onTap();
                key.currentState?.dismiss();
              },
        onFullyDismissed: removeEntry,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _currentTimer = Timer(duration, () {
      key.currentState?.dismiss();
    });
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

/// El toast en sí — entra deslizando desde arriba + fade in, sale igual
/// pero al revés. `onFullyDismissed` se llama recién cuando la
/// animación de salida terminó (así `AppSnackbar` puede sacar la
/// `OverlayEntry` sin cortar la animación a la mitad).
class _TopToast extends StatefulWidget {
  final String title;
  final String message;
  final Color backgroundColor;
  final Color colorText;
  final Widget? icon;
  final String? mainButton;
  final VoidCallback? onTap;
  final VoidCallback onFullyDismissed;

  const _TopToast({
    super.key,
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.colorText,
    required this.icon,
    required this.mainButton,
    required this.onTap,
    required this.onFullyDismissed,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> {
  bool _visible = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    // Arranca oculto y un frame después se hace visible — así
    // `AnimatedSlide`/`AnimatedOpacity` animan la ENTRADA en vez de
    // aparecer de golpe ya en su posición final.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  /// Inicia la animación de salida. Idempotente — un timer que expira
  /// después de que el usuario ya tocó el botón de acción no debe
  /// re-disparar la salida.
  void dismiss() {
    if (!mounted || _dismissing) return;
    setState(() {
      _visible = false;
      _dismissing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 8,
      left: 12,
      right: 12,
      child: IgnorePointer(
        ignoring: _dismissing,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -1.5),
          duration: const Duration(milliseconds: 220),
          curve: _visible ? Curves.easeOutCubic : Curves.easeInCubic,
          onEnd: () {
            if (!_visible) widget.onFullyDismissed();
          },
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.icon != null) ...[
                      IconTheme(
                        data: IconThemeData(color: widget.colorText, size: 20),
                        child: widget.icon!,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title.trim().isNotEmpty)
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: widget.colorText,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          if (widget.title.trim().isNotEmpty &&
                              widget.message.trim().isNotEmpty)
                            const SizedBox(height: 2),
                          if (widget.message.trim().isNotEmpty)
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: widget.colorText,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.onTap != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onTap,
                        style: TextButton.styleFrom(
                          foregroundColor: widget.colorText,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          widget.mainButton ?? 'OK',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
