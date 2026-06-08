import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Información del negocio (tenant): nombre, dirección, teléfono, email.
///
/// Esta info se imprime en cada recibo térmico (header) — sin esto el
/// recibo sale solo con el nombre por default. Es el primer settings
/// que debe configurar un restaurante nuevo.
///
/// **Por qué no usar BusinessSettingsScreen existente:** ese pantalla
/// es impuestos + propinas (cálculo de orden). Mezclar identidad
/// del negocio con cálculos confunde — mejor separado.
class BusinessInfoScreen extends StatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  State<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends State<BusinessInfoScreen> {
  late final Dio _dio;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _businessNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  // El backend no tiene tax_id como columna — vive en settings, pero
  // por costumbre LATAM lo llamamos NIT. Va al campo settings.contact
  // como `tax_id`.
  final _nitCtrl = TextEditingController();

  // Settings completos cargados — los preservamos al guardar para no
  // pisar otros campos (impuestos, propinas, etc.).
  Map<String, dynamic> _existingSettings = {};

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    _load();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _nitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio.get('/tenants/me');
      final tenant = ApiResponseUtils.object(response);
      final settings = (tenant['settings'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      _existingSettings = Map<String, dynamic>.from(settings);
      final contact =
          (settings['contact'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      _businessNameCtrl.text =
          (tenant['business_name'] as String?) ?? '';
      _phoneCtrl.text = (contact['phone'] as String?) ?? '';
      _emailCtrl.text = (contact['email'] as String?) ?? '';
      _addressCtrl.text = (contact['address'] as String?) ?? '';
      _nitCtrl.text = (contact['tax_id'] as String?) ?? '';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _businessNameCtrl.text.trim();
    if (name.length < 2) {
      AppSnackbar.show('Nombre inválido',
          'El nombre del negocio debe tener al menos 2 caracteres.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Mergeamos sobre settings existentes para no pisar otros bloques
      // (tax_settings, tip_settings, etc.).
      final newSettings = Map<String, dynamic>.from(_existingSettings);
      final existingContact =
          (newSettings['contact'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      newSettings['contact'] = {
        ...existingContact,
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)
          'email': _emailCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_nitCtrl.text.trim().isNotEmpty) 'tax_id': _nitCtrl.text.trim(),
      };

      await _dio.patch('/tenants/me', data: {
        'business_name': name,
        'settings': newSettings,
      });

      AppSnackbar.show(
        'Información actualizada',
        'Los datos del negocio se guardaron correctamente.',
      );
      _existingSettings = newSettings;
    } catch (e) {
      AppSnackbar.show('Error al guardar', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Información del negocio'),
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
        const SizedBox(height: 16),
        _sectionTitle('Identidad'),
        _field(
          controller: _businessNameCtrl,
          label: 'Nombre del negocio *',
          icon: Icons.storefront_outlined,
          hint: 'Ej: Restaurante La Plaza',
        ),
        const SizedBox(height: 24),
        _sectionTitle('Contacto'),
        _field(
          controller: _phoneCtrl,
          label: 'Teléfono',
          icon: Icons.phone,
          hint: 'Ej: +57 300 123 4567',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          hint: 'info@tu-restaurante.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _addressCtrl,
          label: 'Dirección',
          icon: Icons.location_on_outlined,
          hint: 'Ej: Calle 10 #20-30, Bogotá',
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        _sectionTitle('Facturación'),
        _field(
          controller: _nitCtrl,
          label: 'NIT / Tax ID',
          icon: Icons.badge_outlined,
          hint: 'Ej: 900.123.456-7',
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
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta información aparece en el encabezado de cada recibo '
              'térmico que se imprime al cliente.',
              style: TextStyle(
                color: AppColors.info,
                fontSize: 12,
              ),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
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
