import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_filter_chip.dart';

/// Radio de cobertura para pedidos por QR: si se activa, el backend exige
/// que el celular del cliente confirme que está dentro del radio antes de
/// aceptar el pedido — evita que alguien pida desde otra ciudad con una
/// foto del QR. Se guarda en `settings.location` del tenant.
class LocationRadiusScreen extends StatefulWidget {
  const LocationRadiusScreen({super.key});

  @override
  State<LocationRadiusScreen> createState() => _LocationRadiusScreenState();
}

class _LocationRadiusScreenState extends State<LocationRadiusScreen> {
  late final Dio _dio;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _enabled = false;
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  int _radiusMeters = 1000;

  Map<String, dynamic> _existingSettings = {};

  static const List<int> _radiusOptions = [300, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/tenants/me');
      final tenant = ApiResponseUtils.object(res);
      final settings =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      _existingSettings = Map<String, dynamic>.from(settings);

      final loc =
          (settings['location'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      _enabled = loc['enabled'] == true;
      final lat = loc['latitude'];
      final lng = loc['longitude'];
      _latCtrl.text = lat != null ? '$lat' : '';
      _lngCtrl.text = lng != null ? '$lng' : '';
      final rawRadius = loc['radius_meters'];
      _radiusMeters = rawRadius is int
          ? rawRadius
          : (rawRadius is double ? rawRadius.toInt() : 1000);
      if (!_radiusOptions.contains(_radiusMeters)) _radiusMeters = 1000;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    double? lat;
    double? lng;
    if (_enabled) {
      lat = double.tryParse(_latCtrl.text.trim().replaceAll(',', '.'));
      lng = double.tryParse(_lngCtrl.text.trim().replaceAll(',', '.'));
      if (lat == null || lng == null) {
        AppSnackbar.show(
          'Faltan las coordenadas',
          'Cargá latitud y longitud para activar la restricción.',
        );
        return;
      }
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        AppSnackbar.show(
          'Coordenadas inválidas',
          'Revisá los valores — parecen estar fuera de rango.',
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final newSettings = Map<String, dynamic>.from(_existingSettings);
      newSettings['location'] = {
        'enabled': _enabled,
        'latitude': lat,
        'longitude': lng,
        'radius_meters': _radiusMeters,
      };

      await _dio.patch('/tenants/me', data: {'settings': newSettings});
      _existingSettings = newSettings;

      AppSnackbar.show(
        'Ubicación guardada',
        _enabled
            ? 'Los pedidos por QR ahora solo se aceptan dentro del radio configurado.'
            : 'La restricción de ubicación está desactivada.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ubicación y radio de pedidos'),
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
              'Restringir pedidos por distancia',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              _enabled
                  ? 'Activo — se bloquean pedidos fuera del radio'
                  : 'Inactivo — cualquiera con el QR puede pedir',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 20),

        // ── Coordenadas ────────────────────────────────────────────
        _sectionTitle('Ubicación de tu local'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Abrí Google Maps, mantené presionado tu local en el mapa '
                'y copiá las coordenadas que aparecen arriba (ej. '
                '"4.6097, -74.0817").',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _numField(
                controller: _latCtrl,
                label: 'Latitud',
                hint: 'Ej: 4.6097',
                icon: Icons.explore_outlined,
              ),
              const SizedBox(height: 10),
              _numField(
                controller: _lngCtrl,
                label: 'Longitud',
                hint: 'Ej: -74.0817',
                icon: Icons.explore_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Radio ──────────────────────────────────────────────────
        _sectionTitle('Radio permitido'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distancia máxima desde tu local para poder enviar un pedido:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 0,
                runSpacing: 8,
                children: _radiusOptions.map((r) {
                  return AppFilterChip(
                    label: r >= 1000 ? '${r / 1000} km' : '$r m',
                    selected: _radiusMeters == r,
                    onTap: () => setState(() => _radiusMeters = r),
                  );
                }).toList(),
              ),
            ],
          ),
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
          Icon(Icons.gpp_good_outlined, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Cuando esto está activo, el celular del cliente debe '
              'confirmar su ubicación para enviar un pedido por QR. Si no '
              'la confirma o está fuera del radio, el pedido se bloquea. '
              'No afecta pedidos tomados por el mesero desde el POS.',
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

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*')),
      ],
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
