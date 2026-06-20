import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';
import '../config/theme/app_colors.dart';
import 'app_snackbar.dart';

/// Sube fotos de productos a Cloudinary (subida UNSIGNED directa).
///
/// Flujo: el usuario elige Galería o Cámara → se selecciona/comprime la
/// imagen → se sube a Cloudinary → devuelve la URL segura (`secure_url`)
/// que se guarda en `product.image_url`.
class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  /// Muestra el selector (galería/cámara), sube la imagen y devuelve la URL.
  /// Devuelve `null` si el usuario cancela o si falla (ya avisa por snackbar).
  static Future<String?> pickAndUpload(BuildContext context) async {
    if (!CloudinaryConfig.isConfigured) {
      AppSnackbar.show(
        'Fotos no configuradas',
        'Falta configurar Cloudinary (cloud name + upload preset).',
      );
      return null;
    }

    final source = await _chooseSource(context);
    if (source == null) return null;

    try {
      // Comprimimos al elegir (maxWidth/Quality) para subir liviano.
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 78,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'upload_preset': CloudinaryConfig.uploadPreset,
      });

      // Dio LIMPIO (sin interceptores de auth): no mandamos el JWT/tenant
      // a un servicio externo.
      final dio = Dio();
      final res = await dio.post(CloudinaryConfig.uploadUrl, data: form);
      final data = res.data;
      final url = data is Map ? data['secure_url'] as String? : null;
      if (url == null || url.isEmpty) {
        AppSnackbar.show('No se pudo subir', 'Respuesta inesperada de Cloudinary.');
        return null;
      }
      return url;
    } catch (e) {
      AppSnackbar.show(
        'No se pudo subir la foto',
        'Revisá tu conexión e intentá de nuevo.',
      );
      return null;
    }
  }

  static Future<ImageSource?> _chooseSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
