import 'package:get/get.dart';

/// Helpers para `Get.find` defensivos.
///
/// **Problema que resuelve:** `Get.find<T>()` lanza si el controller
/// no está registrado. Esto pasa naturalmente cuando GetX libera
/// controllers vía `SmartManagement`, o cuando se intenta refrescar
/// otro controller desde un callback (ej. tras crear una categoría,
/// refrescar la lista de categorías que ya no existe en memoria).
///
/// **Patrón:** en vez de `Get.find<CategoriesController>().refreshCategories()`
/// usar `SafeGet.find<CategoriesController>()?.refreshCategories()` —
/// si no existe, la operación queda como no-op silencioso (el controller
/// se va a recargar solo cuando el usuario vuelva a la pantalla).
class SafeGet {
  SafeGet._();

  /// Devuelve la instancia registrada o `null` si no está disponible.
  /// Nunca lanza excepción.
  static T? find<T>({String? tag}) {
    if (!Get.isRegistered<T>(tag: tag)) return null;
    try {
      return Get.find<T>(tag: tag);
    } catch (_) {
      return null;
    }
  }

  /// Ejecuta [callback] solo si el controller está registrado.
  /// Equivalente a `SafeGet.find<T>()?.let { callback(it) }` (estilo Kotlin).
  static void run<T>(void Function(T controller) callback, {String? tag}) {
    final c = find<T>(tag: tag);
    if (c != null) callback(c);
  }
}
