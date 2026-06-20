import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme/app_colors.dart';
import 'api_response_utils.dart';
import 'app_snackbar.dart';

/// Sube fotos de productos a través del BACKEND (`POST /uploads/image`),
/// que a su vez las sube a Cloudinary con las credenciales del servidor
/// (variables CLOUDINARY_* en Dokploy). Las claves NUNCA viven en la app.
///
/// Flujo: el usuario elige Galería o Cámara → se comprime → se manda al
/// backend → devuelve la URL (`secure_url`) que se guarda en
/// `product.image_url`.
class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  /// Muestra el selector (galería/cámara), sube la imagen y devuelve la URL.
  /// `null` si el usuario cancela o si falla (ya avisa por snackbar).
  static Future<String?> pickAndUpload(BuildContext context) async {
    final source = await _chooseSource(context);
    if (source == null) return null;

    try {
      // Comprimimos al elegir para subir liviano.
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
      });

      // Dio de la app (autenticado: manda JWT + x-tenant-id). El backend
      // exige rol admin/manager en /uploads/image.
      final dio = GetIt.I<Dio>();
      final res = await dio.post('/uploads/image', data: form);
      final url = ApiResponseUtils.object(res)['url'] as String?;
      if (url == null || url.isEmpty) {
        AppSnackbar.show('No se pudo subir', 'Respuesta inesperada del servidor.');
        return null;
      }
      return url;
    } catch (e) {
      AppSnackbar.show(
        'No se pudo subir la foto',
        ApiResponseUtils.errorMessage(e) ?? 'Revisá tu conexión e intentá de nuevo.',
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
