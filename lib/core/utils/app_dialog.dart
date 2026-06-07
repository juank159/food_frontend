// lib/core/utils/app_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// AppDialog — wrappers safe para reemplazar `Get.dialog` y
/// `Get.bottomSheet`.
///
/// **Por qué existe:**
///
/// `Get.dialog` y `Get.bottomSheet` usan internamente `Get.overlayContext`
/// para resolver el navigator. Si el route que invoca el dialog se está
/// desmontando (ej. snackbar previo + back encolado + dialog), el
/// `overlayContext` puede ser `null` o estar muerto → `No Overlay widget
/// found`. Mismo bug subyacente que arreglamos con `AppSnackbar`.
///
/// **Qué hace este helper:**
///
///   - Usa `showDialog` / `showModalBottomSheet` nativos de Material
///     con el `BuildContext` que el caller pasa (preferido) o `Get.context`
///     (fallback). Antes de invocar verifica `context.mounted`.
///   - Si NO hay contexto válido, log silencioso y retorna `null` —
///     **nunca crashea**.
///   - Mismo API que `Get.dialog`/`Get.bottomSheet` (positional widget,
///     barrierDismissible, etc.) para que el reemplazo sea drop-in.
class AppDialog {
  AppDialog._();

  /// Drop-in replacement de `Get.dialog`.
  ///
  /// Devuelve `null` si no había contexto válido en vez de crashear.
  /// Si el caller tiene un `BuildContext` propio (widget), pasarlo
  /// como parámetro `context` es más confiable que dejar que use
  /// `Get.context`.
  static Future<T?> show<T>(
    Widget child, {
    BuildContext? context,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
  }) async {
    final ctx = context ?? Get.context;
    if (ctx == null || !ctx.mounted) {
      debugPrint('[AppDialog.show suppressed — no context]');
      return null;
    }
    return showDialog<T>(
      context: ctx,
      builder: (_) => child,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
    );
  }

  /// Drop-in replacement de `Get.bottomSheet`.
  static Future<T?> bottomSheet<T>(
    Widget child, {
    BuildContext? context,
    Color? backgroundColor,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    ShapeBorder? shape,
    Clip? clipBehavior,
  }) async {
    final ctx = context ?? Get.context;
    if (ctx == null || !ctx.mounted) {
      debugPrint('[AppDialog.bottomSheet suppressed — no context]');
      return null;
    }
    return showModalBottomSheet<T>(
      context: ctx,
      builder: (_) => child,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: shape,
      clipBehavior: clipBehavior,
    );
  }
}
