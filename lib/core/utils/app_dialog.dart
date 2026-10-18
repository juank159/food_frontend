// lib/core/utils/app_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/responsive_config.dart';

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

  /// Bug real reportado: formularios abiertos con `showModalBottomSheet`
  /// (pensados para el gesto táctil "deslizar desde abajo" en celular)
  /// se ven mal en pantallas de laptop/escritorio (ej. Windows a
  /// 1920x1080) — ocupan todo el ancho de la ventana, estirando los
  /// campos de forma poco natural, y los botones de acción quedan
  /// pegados al borde inferior de la ventana en vez de centrados como
  /// un diálogo. En Mac con pantalla Retina esto se disimula porque la
  /// escala de DPI da más píxeles lógicos de alto; en una laptop con
  /// escalado de Windows típico (125%-150%) el canvas lógico es más
  /// bajo y la misma hoja se siente desproporcionada.
  ///
  /// `showFormSheet` elige automáticamente, según
  /// `ResponsiveConfig.isDesktop` (ancho >= 900 — ver
  /// `responsive_config.dart`):
  ///   - Móvil/tablet angosto: `bottomSheet` de siempre (gesto nativo).
  ///   - Desktop/laptop: diálogo centrado con ancho acotado
  ///     (`desktopWidth`), igual que cualquier diálogo de escritorio.
  ///
  /// El `child` debe construirse igual en ambos casos — ver
  /// `_ExpenseForm` en `expenses_screen.dart` para el patrón de uso
  /// (oculta su manija de "arrastrar" cuando `isDesktopDialog` es
  /// `true`, ya que ese afordance no aplica dentro de un diálogo).
  static Future<T?> showFormSheet<T>(
    Widget child, {
    BuildContext? context,
    double desktopWidth = 480,
    Color? backgroundColor,
    bool isDismissible = true,
  }) async {
    final ctx = context ?? Get.context;
    if (ctx == null || !ctx.mounted) {
      debugPrint('[AppDialog.showFormSheet suppressed — no context]');
      return null;
    }
    if (ResponsiveConfig(ctx).isDesktop) {
      return showDialog<T>(
        context: ctx,
        barrierDismissible: isDismissible,
        builder: (_) => Dialog(
          backgroundColor: backgroundColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: desktopWidth),
            child: child,
          ),
        ),
      );
    }
    return showModalBottomSheet<T>(
      context: ctx,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor ?? Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => child,
    );
  }
}
