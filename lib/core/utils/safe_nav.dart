import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Navegación segura que evita el bug de GetX:
///
/// `Get.back()` internamente llama `SnackbarController.closeCurrentSnackbar()`
/// como side-effect — y si GetX tiene un snackbar "fantasma" en su queue
/// (overlay ya desmontado pero el controller cree que sigue vivo), explota
/// con `LateInitializationError: Field '_controller@...' has not been
/// initialized.` Esto pasaba especialmente al volver de pantallas que
/// mostraron snackbars al cargar.
///
/// `SafeNav.back(context)`:
///   1. Cierra cualquier snackbar GetX pendiente de forma defensiva (try/catch).
///   2. Usa `Navigator.of(context).pop()` directo — sin tocar el queue de
///      snackbars de GetX, así no puede triggear el LateInitializationError.
///
/// **Uso obligatorio en `presentation/pages/*` y `presentation/screens/*`**.
/// Para cerrar dialogs/bottomsheets sí podés seguir usando `Get.back()`
/// porque ahí GetX maneja correctamente su propio overlay.
class SafeNav {
  SafeNav._();

  /// Vuelve a la pantalla anterior de forma segura.
  static void back<T extends Object?>(BuildContext context, [T? result]) {
    _safeCloseSnackbars();
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(result);
    }
  }

  /// Cierra el snackbar GetX si hay alguno colgado, sin propagar errores.
  static void _safeCloseSnackbars() {
    try {
      if (Get.isSnackbarOpen) {
        Get.closeAllSnackbars();
      }
    } catch (_) {
      // El controller puede estar en estado inconsistente; lo ignoramos.
    }
  }
}
