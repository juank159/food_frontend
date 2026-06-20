/// Configuración de Cloudinary para subir las fotos de los productos.
///
/// Usamos **subida UNSIGNED directa desde la app**: no expone claves
/// secretas (solo el cloud name + el nombre de un "upload preset" unsigned,
/// que son públicos y seguros de embeber).
///
/// ───────────────────── CÓMO CONFIGURARLO (una vez) ─────────────────────
/// 1. Crear cuenta gratis en https://cloudinary.com
/// 2. En el Dashboard, copiar el "Cloud name" (arriba a la izquierda).
/// 3. Settings (engranaje) → Upload → "Add upload preset":
///      - Signing Mode: **Unsigned**
///      - (opcional) Folder: "productos"
///      - Guardar y copiar el "Upload preset name".
/// 4. Pegar ambos valores abajo (reemplazar los placeholders) y hacer
///    rebuild de la app. ¡Listo, ya se pueden subir fotos!
class CloudinaryConfig {
  /// Tu "Cloud name" de Cloudinary.
  static const String cloudName = 'TU_CLOUD_NAME';

  /// Nombre del "Upload preset" en modo **Unsigned**.
  static const String uploadPreset = 'TU_UPLOAD_PRESET';

  /// True cuando ya se pegaron valores reales (no los placeholders).
  static bool get isConfigured =>
      cloudName.isNotEmpty &&
      uploadPreset.isNotEmpty &&
      cloudName != 'TU_CLOUD_NAME' &&
      uploadPreset != 'TU_UPLOAD_PRESET';

  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
