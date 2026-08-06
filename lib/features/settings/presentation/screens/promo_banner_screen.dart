import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/image_upload_service.dart';
import '../../../../core/widgets/app_filter_chip.dart';

/// Configuración del banner de promoción que aparece al abrir el menú QR.
///
/// Se guarda en `settings.promo_banner` del tenant. El menú público lo
/// lee en `GET /public/menu/:code` y lo muestra al cargar la carta.
/// Si se vincula un producto, el banner muestra un botón CTA que navega
/// directo a ese producto para que el cliente lo agregue al carrito.
class PromoBannerScreen extends StatefulWidget {
  const PromoBannerScreen({super.key});

  @override
  State<PromoBannerScreen> createState() => _PromoBannerScreenState();
}

class _PromoBannerScreenState extends State<PromoBannerScreen> {
  late final Dio _dio;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  // ── Campos del banner ────────────────────────────────────────────
  bool _enabled = false;
  String _imageUrl = '';
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  int _displaySeconds = 5; // 0 = solo cierre manual

  // ── Producto vinculado ───────────────────────────────────────────
  String? _linkedProductId;
  String? _linkedProductName;
  // Lista cargada del catálogo para el picker: [{id, name, category_name}]
  List<Map<String, dynamic>> _allProducts = [];
  bool _loadingProducts = false;

  Map<String, dynamic> _existingSettings = {};

  static const List<int> _secOptions = [0, 3, 5, 8, 10, 15];

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  // ── Carga ────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Cargar settings del tenant y lista de productos en paralelo.
      final results = await Future.wait([
        _dio.get('/tenants/me'),
        _dio.get('/products', queryParameters: {'limit': 500}),
      ]);

      final tenant = ApiResponseUtils.object(results[0]);
      final settings =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      _existingSettings = Map<String, dynamic>.from(settings);

      final pb =
          (settings['promo_banner'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      _enabled = pb['enabled'] == true;
      _imageUrl = (pb['image_url'] as String?) ?? '';
      _titleCtrl.text = (pb['title'] as String?) ?? '';
      _subtitleCtrl.text = (pb['subtitle'] as String?) ?? '';
      final rawSec = pb['display_seconds'];
      _displaySeconds = rawSec is int
          ? rawSec
          : (rawSec is double ? rawSec.toInt() : 5);
      if (!_secOptions.contains(_displaySeconds)) _displaySeconds = 5;
      _linkedProductId = pb['linked_product_id'] as String?;

      // Construir lista de productos para el picker.
      final rawProducts = ApiResponseUtils.list(results[1]);
      _allProducts = rawProducts
          .map((p) => <String, dynamic>{
                'id': (p['id'] as String?) ?? '',
                'name': (p['name'] as String?) ?? '',
                'category_name':
                    ((p['category'] as Map?)?['name'] as String?) ?? '',
              })
          .where((p) => (p['id'] as String).isNotEmpty)
          .toList()
        ..sort((a, b) =>
            (a['category_name'] as String).compareTo(b['category_name'] as String));

      // Resolver nombre del producto actualmente vinculado.
      if (_linkedProductId != null) {
        final match = _allProducts.firstWhere(
          (p) => p['id'] == _linkedProductId,
          orElse: () => <String, dynamic>{},
        );
        _linkedProductName = match.isNotEmpty ? match['name'] as String : null;
        if (_linkedProductName == null) _linkedProductId = null; // producto eliminado
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Imagen ───────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    try {
      final url = await ImageUploadService.pickAndUpload(context);
      if (url != null && mounted) {
        setState(() => _imageUrl = url);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Selector de producto ──────────────────────────────────────────

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(products: _allProducts),
    );
    if (picked != null && mounted) {
      setState(() {
        _linkedProductId = picked['id'] as String;
        _linkedProductName = picked['name'] as String;
      });
    }
  }

  void _clearLinkedProduct() => setState(() {
        _linkedProductId = null;
        _linkedProductName = null;
      });

  // ── Guardar ──────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_enabled && _imageUrl.isEmpty) {
      AppSnackbar.show(
        'Falta la imagen',
        'Subí una imagen para activar el banner.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final newSettings = Map<String, dynamic>.from(_existingSettings);
      newSettings['promo_banner'] = {
        'enabled': _enabled,
        'image_url': _imageUrl.isNotEmpty ? _imageUrl : null,
        'title': _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
        'subtitle':
            _subtitleCtrl.text.trim().isNotEmpty ? _subtitleCtrl.text.trim() : null,
        'display_seconds': _displaySeconds,
        'linked_product_id': _linkedProductId,
      };

      await _dio.patch('/tenants/me', data: {'settings': newSettings});
      _existingSettings = newSettings;

      AppSnackbar.show(
        'Banner guardado',
        _enabled
            ? 'El banner aparecerá al abrir el menú QR.'
            : 'El banner está desactivado.',
      );
    } catch (e) {
      AppSnackbar.show(
        'Error al guardar',
        ApiResponseUtils.errorMessage(e) ?? e.toString(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Banner de promoción'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _buildForm(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _infoBanner(),
        const SizedBox(height: 20),

        // ── Activar / Desactivar ──────────────────────────────────
        _sectionTitle('Estado'),
        _card(
          child: SwitchListTile(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            activeThumbColor: AppColors.primary,
            title: const Text(
              'Mostrar banner al abrir el menú',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              _enabled
                  ? 'Activo — se muestra al escanear el QR'
                  : 'Inactivo — el menú abre directo',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 20),

        // ── Imagen ───────────────────────────────────────────────
        _sectionTitle('Imagen de la promoción'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: _imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: AppColors.border,
                      child:
                          const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 80,
                      color: AppColors.error.withValues(alpha: 0.08),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: AppColors.error, size: 22),
                            const SizedBox(width: 8),
                            const Text('No se pudo cargar',
                                style:
                                    TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _imageUrl.isEmpty
                            ? Icons.add_photo_alternate_outlined
                            : Icons.swap_horiz,
                        size: 18,
                      ),
                label: Text(
                  _uploading
                      ? 'Subiendo…'
                      : (_imageUrl.isEmpty
                          ? 'Subir imagen'
                          : 'Cambiar imagen'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Se mostrará pantalla completa. Usá una imagen horizontal '
                '(1080×720 o similar) para mejor resultado.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Producto vinculado ────────────────────────────────────
        _sectionTitle('Producto destacado (opcional)'),
        _card(child: _buildProductPicker()),
        const SizedBox(height: 20),

        // ── Texto opcional ────────────────────────────────────────
        _sectionTitle('Texto (opcional)'),
        _card(
          child: Column(
            children: [
              _field(
                controller: _titleCtrl,
                label: 'Título',
                hint: 'Ej: ¡Oferta especial de temporada!',
                icon: Icons.title,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _subtitleCtrl,
                label: 'Subtítulo',
                hint: 'Ej: 2×1 en todos los helados hoy',
                icon: Icons.short_text,
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Tiempo de cierre automático ───────────────────────────
        _sectionTitle('Cierre automático'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _linkedProductId != null
                    ? 'Con producto vinculado el cliente cierra el banner tocando el botón CTA.'
                    : 'El banner se cierra solo después de:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_linkedProductId == null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 0,
                  runSpacing: 8,
                  children: _secOptions.map((s) {
                    return AppFilterChip(
                      label: s == 0 ? 'Manual' : '$s seg',
                      selected: _displaySeconds == s,
                      onTap: () => setState(() => _displaySeconds = s),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _displaySeconds == 0
                      ? 'El cliente debe cerrar el banner manualmente.'
                      : 'El banner se cerrará solo después de $_displaySeconds segundos.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductPicker() {
    if (_linkedProductId != null && _linkedProductName != null) {
      // Producto seleccionado
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shopping_bag_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _linkedProductName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'El banner mostrará un botón para agregar este producto',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              TextButton(
                onPressed: _pickProduct,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Cambiar'),
              ),
              TextButton(
                onPressed: _clearLinkedProduct,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Quitar'),
              ),
            ],
          ),
        ],
      );
    }

    // Sin producto seleccionado
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Vinculá un producto y el banner mostrará un botón "Agregar al carrito" '
          'que lleva al cliente directo a ese producto.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _allProducts.isEmpty ? null : _pickProduct,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(42),
            side: BorderSide(color: AppColors.primary),
            foregroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.link, size: 18),
          label: Text(_allProducts.isEmpty
              ? 'Cargando productos…'
              : 'Elegir producto'),
        ),
      ],
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Este banner aparece en pantalla completa cada vez que alguien '
              'abre el menú QR. Ideal para promocionar ofertas, platos especiales o eventos.',
              style: TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Bottom sheet picker de producto ─────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  const _ProductPickerSheet({required this.products});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.products;
    final q = _query.toLowerCase();
    return widget.products
        .where((p) =>
            (p['name'] as String).toLowerCase().contains(q) ||
            (p['category_name'] as String).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Elegir producto',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto o categoría…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados para "$_query"',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          return ListTile(
                            title: Text(
                              p['name'] as String,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            subtitle: (p['category_name'] as String).isNotEmpty
                                ? Text(
                                    p['category_name'] as String,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  )
                                : null,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.shopping_bag_outlined,
                                  size: 18, color: AppColors.primary),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.textSecondary, size: 20),
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
