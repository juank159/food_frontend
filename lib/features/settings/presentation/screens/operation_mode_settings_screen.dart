import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/services/operation_mode_preference.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Valores válidos de `settings.operation_mode.mode` — espejo del enum
/// `OperationMode` del backend (`common/constants/enums.ts`).
enum _OperationModeValue {
  tables('tables', 'Mesas', 'El negocio trabaja principalmente con mesas',
      Icons.table_restaurant),
  openTabs('open_tabs', 'Cuentas abiertas',
      'Cuentas libres, sin mesas fijas (barra, patio, eventos)',
      Icons.receipt_long),
  counterTickets('counter_tickets', 'Turnos de mostrador',
      'El cliente pide, recibe un número y se le avisa cuando está listo '
          '(heladería, panadería)',
      Icons.confirmation_number_outlined),
  mixed('mixed', 'Mixto', 'Un poco de todo — el más común',
      Icons.dashboard_customize_outlined);

  final String value;
  final String label;
  final String description;
  final IconData icon;
  const _OperationModeValue(this.value, this.label, this.description, this.icon);

  static _OperationModeValue? fromValue(String? value) {
    for (final v in values) {
      if (v.value == value) return v;
    }
    return null;
  }
}

/// Preferencia de "modo de operación" del negocio.
///
/// **Solo guía la pantalla de venta** (destaca la opción elegida) —
/// NUNCA restringe: el cajero siempre puede usar cualquier modo (mesa,
/// cuenta abierta, turno de mostrador) sin importar lo que se elija
/// acá. Se guarda en `settings.operation_mode.mode`, mismo patrón que
/// `settings.breb` (merge profundo en `PATCH /tenants/me`, sin
/// necesitar un endpoint dedicado).
class OperationModeSettingsScreen extends StatefulWidget {
  const OperationModeSettingsScreen({super.key});

  @override
  State<OperationModeSettingsScreen> createState() =>
      _OperationModeSettingsScreenState();
}

class _OperationModeSettingsScreenState
    extends State<OperationModeSettingsScreen> {
  late final Dio _dio;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  _OperationModeValue? _selected;
  bool _printTicketNumber = false;
  Map<String, dynamic> _existingSettings = {};

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      _existingSettings = Map<String, dynamic>.from(settings);
      final opMode =
          (settings['operation_mode'] as Map?)?.cast<String, dynamic>() ?? {};
      _selected = _OperationModeValue.fromValue(opMode['mode'] as String?);
      _printTicketNumber = opMode['print_ticket_number'] as bool? ?? false;
    } catch (e) {
      _error = ApiResponseUtils.errorMessage(e) ?? e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(_OperationModeValue mode) async {
    if (_saving) return;
    final previousMode = _selected;
    final previousPrint = _printTicketNumber;
    setState(() {
      _selected = mode;
      // Elegir "Turnos de mostrador" por primera vez prende la
      // impresión del número por default — es parte natural de ese
      // flujo (turno + comanda con el número van juntos). El negocio
      // lo puede apagar después con el switch de abajo si no quiere.
      if (mode == _OperationModeValue.counterTickets) {
        _printTicketNumber = true;
      }
    });
    final ok = await _saveOperationMode();
    if (!ok && mounted) {
      setState(() {
        _selected = previousMode;
        _printTicketNumber = previousPrint;
      });
    }
  }

  Future<void> _togglePrintTicketNumber(bool value) async {
    if (_saving) return;
    final previous = _printTicketNumber;
    setState(() => _printTicketNumber = value);
    final ok = await _saveOperationMode();
    if (!ok && mounted) setState(() => _printTicketNumber = previous);
  }

  /// Guarda el bloque `operation_mode` completo (modo + preferencia de
  /// impresión juntos) — evita que guardar uno pise al otro, ya que
  /// ambos viven en el mismo sub-objeto de `settings`.
  Future<bool> _saveOperationMode() async {
    setState(() => _saving = true);
    try {
      final newSettings = Map<String, dynamic>.from(_existingSettings);
      newSettings['operation_mode'] = {
        'mode': _selected?.value,
        'print_ticket_number': _printTicketNumber,
      };
      await _dio.patch('/tenants/me', data: {'settings': newSettings});
      _existingSettings = newSettings;
      OperationModePreference.invalidateCache();
      AppSnackbar.show('Guardado', 'Preferencias actualizadas.');
      return true;
    } catch (e) {
      AppSnackbar.show(
          'Error al guardar', ApiResponseUtils.errorMessage(e) ?? e.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modo de operación'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _infoBanner(),
        const SizedBox(height: 20),
        for (final mode in _OperationModeValue.values) ...[
          _modeCard(mode),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _printTicketNumberCard(),
      ],
    );
  }

  Widget _printTicketNumberCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.print_outlined, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imprimir número de turno',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sale grande en la comanda de cocina y en el recibo del '
                  'cliente. Si lo apagás, el cajero sigue diciéndolo de '
                  'viva voz.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _printTicketNumber,
            onChanged: _saving ? null : _togglePrintTicketNumber,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
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
          Icon(Icons.info_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Esto es solo una preferencia visual: destaca esa opción en la '
              'pantalla de venta. Tu equipo siempre puede seguir usando mesas, '
              'cuentas abiertas o turnos según lo necesite, sin importar lo '
              'que elijas acá.',
              style: TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(_OperationModeValue mode) {
    final isSelected = _selected == mode;
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _saving ? null : () => _select(mode),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(mode.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.primary, size: 22)
              else
                const Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 20),
            ],
          ),
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
