import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Configuración del negocio (tenant).
///
/// Cubre dos módulos relacionados con el cálculo de cada orden:
///
///   1) Impuestos (IVA, ITBIS, GST…): si se cobra, qué porcentaje aplica y
///      si los precios del catálogo ya lo incluyen o se suma encima.
///   2) Propinas: si se cobran, en qué modo (sugerido/obligatorio/desactivado),
///      qué porcentajes ofrece la UI, sobre qué base se calculan y a qué
///      tipos de orden aplican.
///
/// El backend lee ambos bloques en cada creación de orden y calcula los
/// totales en consecuencia. Los pedidos ya emitidos no cambian.
class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  late final Dio _dio;
  late final AuthLocalDataSource _local;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _tenantId;

  // Tax settings (estado del formulario)
  bool _taxEnabled = true;
  double _taxRate = 0.19; // 19% por defecto (LATAM)
  bool _taxIncludedInPrice = true;
  final TextEditingController _taxNameCtrl = TextEditingController(text: 'IVA');
  final TextEditingController _taxRatePctCtrl =
      TextEditingController(text: '19');

  // Tip settings (estado del formulario). Defaults: propinas activadas en
  // modo "sugerido", con los 3 porcentajes clásicos (10/15/20) sobre el
  // subtotal con descuento aplicado, monto manual permitido, sin tope.
  bool _tipEnabled = true;
  String _tipMode = 'suggested'; // disabled | suggested | mandatory
  String _tipCalculationBase = 'subtotal_after_discount';
  bool _tipAllowCustom = true;
  // Porcentajes guardados como decimales (0.10) para ser consistentes con
  // tax_rate; en la UI los manejamos como enteros (10).
  final List<double> _tipSuggestedPercentages = [0.10, 0.15, 0.20];
  double _tipDefaultPercentage = 0.10;
  // Tipos de orden a los que aplica la propina. Vacío = todos.
  final Set<String> _tipAppliesTo = <String>{};
  final TextEditingController _tipDefaultPctCtrl =
      TextEditingController(text: '10');
  final TextEditingController _tipMaxPctCtrl =
      TextEditingController(text: '');
  final TextEditingController _tipNewPctCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    _local = GetIt.I<AuthLocalDataSource>();
    // Diferimos al próximo frame por seguridad. Si `_load` setea
    // `setState` mientras el build inicial está en curso, Flutter
    // crashea con `setState() called during build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _taxNameCtrl.dispose();
    _taxRatePctCtrl.dispose();
    _tipDefaultPctCtrl.dispose();
    _tipMaxPctCtrl.dispose();
    _tipNewPctCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tenantId = await _local.getTenantId();
      if (tenantId == null) {
        throw Exception('No hay tenant cacheado');
      }
      _tenantId = tenantId;
      final res = await _dio.get('/tenants/$tenantId');
      final settings = (res.data['settings'] as Map<String, dynamic>?) ?? {};
      final tax = (settings['tax_settings'] as Map<String, dynamic>?) ?? {};
      final tip = (settings['tip_settings'] as Map<String, dynamic>?) ?? {};
      setState(() {
        // Tax
        _taxEnabled = (tax['tax_enabled'] as bool?) ?? true;
        _taxIncludedInPrice =
            (tax['tax_included_in_price'] as bool?) ?? true;
        final rateAny = tax['tax_rate'];
        _taxRate = rateAny is num ? rateAny.toDouble() : 0.19;
        _taxRatePctCtrl.text = (_taxRate * 100).toStringAsFixed(
          (_taxRate * 100) % 1 == 0 ? 0 : 2,
        );
        _taxNameCtrl.text = (tax['tax_name'] as String?) ?? 'IVA';

        // Tip — conservamos los defaults si el tenant todavía no guardó nada.
        _tipEnabled = (tip['tip_enabled'] as bool?) ?? true;
        _tipMode = (tip['mode'] as String?) ?? 'suggested';
        _tipCalculationBase =
            (tip['calculation_base'] as String?) ?? 'subtotal_after_discount';
        _tipAllowCustom = (tip['allow_custom_amount'] as bool?) ?? true;

        final defPct = tip['default_percentage'];
        _tipDefaultPercentage = defPct is num ? defPct.toDouble() : 0.10;
        _tipDefaultPctCtrl.text =
            (_tipDefaultPercentage * 100).toStringAsFixed(
          (_tipDefaultPercentage * 100) % 1 == 0 ? 0 : 2,
        );

        final suggested = tip['suggested_percentages'];
        _tipSuggestedPercentages.clear();
        if (suggested is List) {
          for (final v in suggested) {
            if (v is num) _tipSuggestedPercentages.add(v.toDouble());
          }
        }
        if (_tipSuggestedPercentages.isEmpty) {
          _tipSuggestedPercentages.addAll([0.10, 0.15, 0.20]);
        }

        final maxPct = tip['max_percentage'];
        _tipMaxPctCtrl.text = maxPct is num
            ? (maxPct * 100).toStringAsFixed(
                (maxPct * 100) % 1 == 0 ? 0 : 2,
              )
            : '';

        _tipAppliesTo.clear();
        final applies = tip['applies_to_order_types'];
        if (applies is List) {
          for (final v in applies) {
            if (v is String) _tipAppliesTo.add(v);
          }
        }

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_tenantId == null) return;
    setState(() => _saving = true);

    // Tax
    final taxPct =
        double.tryParse(_taxRatePctCtrl.text.trim().replaceAll(',', '.'));
    if (taxPct == null || taxPct < 0 || taxPct > 100) {
      AppSnackbar.show(
        'IVA inválido',
        'Ingresa un porcentaje entre 0 y 100.',
        snackPosition: SnackPosition.BOTTOM,
      );
      setState(() => _saving = false);
      return;
    }
    final taxRate = taxPct / 100;

    // Tip — default
    final defaultPct =
        double.tryParse(_tipDefaultPctCtrl.text.trim().replaceAll(',', '.'));
    if (defaultPct == null || defaultPct < 0 || defaultPct > 100) {
      AppSnackbar.show(
        'Porcentaje de propina inválido',
        'El porcentaje por defecto debe estar entre 0 y 100.',
        snackPosition: SnackPosition.BOTTOM,
      );
      setState(() => _saving = false);
      return;
    }

    // Tip — max (opcional)
    double? maxPct;
    final maxRaw = _tipMaxPctCtrl.text.trim().replaceAll(',', '.');
    if (maxRaw.isNotEmpty) {
      final parsed = double.tryParse(maxRaw);
      if (parsed == null || parsed < 0 || parsed > 100) {
        AppSnackbar.show(
          'Tope de propina inválido',
          'El tope debe estar entre 0 y 100, o vacío para no aplicar.',
          snackPosition: SnackPosition.BOTTOM,
        );
        setState(() => _saving = false);
        return;
      }
      maxPct = parsed / 100;
    }

    try {
      // Solo mandamos los dos sub-bloques que esta pantalla controla. El
      // backend mergea profundo, así que delivery_settings/business_hours/
      // contact se mantienen intactos.
      await _dio.patch(
        '/tenants/$_tenantId',
        data: {
          'settings': {
            'tax_settings': {
              'tax_enabled': _taxEnabled,
              'tax_rate': taxRate,
              'tax_name': _taxNameCtrl.text.trim().isEmpty
                  ? 'IVA'
                  : _taxNameCtrl.text.trim(),
              'tax_included_in_price': _taxIncludedInPrice,
            },
            'tip_settings': {
              'tip_enabled': _tipEnabled,
              'mode': _tipMode,
              'default_percentage': defaultPct / 100,
              'suggested_percentages':
                  List<double>.from(_tipSuggestedPercentages),
              'allow_custom_amount': _tipAllowCustom,
              'calculation_base': _tipCalculationBase,
              'applies_to_order_types': _tipAppliesTo.toList(),
              if (maxPct != null) 'max_percentage': maxPct,
            },
          },
        },
      );
      setState(() {
        _taxRate = taxRate;
        _tipDefaultPercentage = defaultPct / 100;
        _saving = false;
      });
      AppSnackbar.show(
        'Configuración guardada',
        'Los nuevos pedidos usarán esta configuración.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      setState(() => _saving = false);
      AppSnackbar.show(
        'Error guardando',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del negocio'),
        actions: [
          if (!_loading)
            IconButton(
              tooltip: 'Recargar',
              icon: const Icon(Icons.refresh),
              onPressed: _saving ? null : _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildForm(context),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Error desconocido', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Centrado con maxWidth en desktop; full width en mobile.
        final maxW = constraints.maxWidth > 720 ? 680.0 : double.infinity;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Impuestos',
                    subtitle:
                        'Configura cómo se cobra el IVA en tus pedidos. '
                        'Los nuevos pedidos usarán esta configuración inmediatamente; '
                        'los pedidos ya emitidos no cambian.',
                    children: [
                      SwitchListTile(
                        title: const Text('Cobrar IVA en los pedidos'),
                        subtitle: Text(
                          _taxEnabled
                              ? 'Activo · se desglosa en cada ticket'
                              : 'Desactivado · ningún pedido lleva IVA',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: _taxEnabled,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _taxEnabled = v),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detalles del impuesto',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _taxNameCtrl,
                                    enabled: _taxEnabled && !_saving,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      hintText: 'IVA, ITBIS, GST…',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _taxRatePctCtrl,
                                    enabled: _taxEnabled && !_saving,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Porcentaje',
                                      suffixText: '%',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      RadioListTile<bool>(
                        title: const Text('Los precios YA incluyen IVA'),
                        subtitle: const Text(
                          'Recomendado para Colombia, México, Argentina y la mayoría de LATAM. '
                          'Si cargas un producto a \$10.000, el cliente paga \$10.000 — '
                          'el IVA se desglosa solo para la factura.',
                        ),
                        value: true,
                        groupValue: _taxIncludedInPrice,
                        onChanged: !_taxEnabled || _saving
                            ? null
                            : (v) =>
                                setState(() => _taxIncludedInPrice = v ?? true),
                      ),
                      RadioListTile<bool>(
                        title: const Text('El IVA se suma al precio'),
                        subtitle: const Text(
                          'Estilo USA / facturación B2B. Si cargas un producto a \$10.000, '
                          'el cliente paga \$10.000 + IVA = \$11.900 (con 19%).',
                        ),
                        value: false,
                        groupValue: _taxIncludedInPrice,
                        onChanged: !_taxEnabled || _saving
                            ? null
                            : (v) =>
                                setState(() => _taxIncludedInPrice = v ?? false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PreviewCard(
                    enabled: _taxEnabled,
                    rateText: _taxRatePctCtrl.text,
                    included: _taxIncludedInPrice,
                  ),
                  const SizedBox(height: 24),
                  _buildTipSection(theme),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Get.back(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── Sección "Propinas" ─────────────────────────

  Widget _buildTipSection(ThemeData theme) {
    final disabled = !_tipEnabled || _tipMode == 'disabled' || _saving;
    return _SectionCard(
      title: 'Propinas',
      subtitle:
          'Define la política de propinas del establecimiento. El backend la '
          'aplica al crear cada orden — la UI solo sugiere los porcentajes '
          'configurados acá.',
      children: [
        SwitchListTile(
          title: const Text('Cobrar propinas en los pedidos'),
          subtitle: Text(
            _tipEnabled
                ? 'Activo · la UI muestra opciones de propina al cobrar'
                : 'Desactivado · ningún pedido lleva propina',
            style: theme.textTheme.bodySmall,
          ),
          value: _tipEnabled,
          onChanged:
              _saving ? null : (v) => setState(() => _tipEnabled = v),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Determina cómo se aplica la propina al cobrar.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        RadioListTile<String>(
          title: const Text('Sugerida'),
          subtitle: const Text(
            'El operario elige uno de los porcentajes propuestos o ingresa otro.',
          ),
          value: 'suggested',
          groupValue: _tipMode,
          onChanged: !_tipEnabled || _saving
              ? null
              : (v) => setState(() => _tipMode = v ?? 'suggested'),
        ),
        RadioListTile<String>(
          title: const Text('Obligatoria'),
          subtitle: const Text(
            'Si el operario no elige, se aplica el porcentaje por defecto. '
            'Útil para servicios con propina incluida.',
          ),
          value: 'mandatory',
          groupValue: _tipMode,
          onChanged: !_tipEnabled || _saving
              ? null
              : (v) => setState(() => _tipMode = v ?? 'mandatory'),
        ),
        RadioListTile<String>(
          title: const Text('Desactivada'),
          subtitle: const Text(
            'Equivalente al switch de arriba. Mantenelo si querés desactivar '
            'sin perder los porcentajes ya configurados.',
          ),
          value: 'disabled',
          groupValue: _tipMode,
          onChanged: !_tipEnabled || _saving
              ? null
              : (v) => setState(() => _tipMode = v ?? 'disabled'),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Porcentajes sugeridos',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Botones rápidos que aparecen al cobrar (ej. 10%, 15%, 20%).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _tipSuggestedPercentages.length; i++)
                    InputChip(
                      label: Text(_formatPct(_tipSuggestedPercentages[i])),
                      onDeleted: disabled
                          ? null
                          : () => setState(
                                () => _tipSuggestedPercentages.removeAt(i),
                              ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tipNewPctCtrl,
                      enabled: !disabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Agregar porcentaje',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: disabled ? null : _addSuggestedPercentage,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _tipDefaultPctCtrl,
                  enabled: !disabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje por defecto',
                    helperText: 'Usado en modo "obligatoria" si no se elige otro',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _tipMaxPctCtrl,
                  enabled: !disabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tope (opcional)',
                    helperText: 'Rechaza propinas que excedan este %',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Permitir monto manual'),
          subtitle: const Text(
            'Si está activo, el operario puede ingresar un monto distinto a los '
            'porcentajes sugeridos.',
          ),
          value: _tipAllowCustom,
          onChanged:
              disabled ? null : (v) => setState(() => _tipAllowCustom = v),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Base de cálculo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Sobre qué monto se calculan los porcentajes sugeridos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        RadioListTile<String>(
          title: const Text('Subtotal con descuento aplicado'),
          subtitle: const Text(
            'Recomendado. La propina se calcula sobre lo que efectivamente paga el cliente, sin IVA.',
          ),
          value: 'subtotal_after_discount',
          groupValue: _tipCalculationBase,
          onChanged: disabled
              ? null
              : (v) => setState(
                    () => _tipCalculationBase = v ?? 'subtotal_after_discount',
                  ),
        ),
        RadioListTile<String>(
          title: const Text('Subtotal'),
          subtitle: const Text(
            'No descuenta promociones — la propina sale sobre el bruto.',
          ),
          value: 'subtotal',
          groupValue: _tipCalculationBase,
          onChanged: disabled
              ? null
              : (v) =>
                  setState(() => _tipCalculationBase = v ?? 'subtotal'),
        ),
        RadioListTile<String>(
          title: const Text('Subtotal + IVA'),
          subtitle: const Text(
            'La propina incluye el impuesto. Estilo USA.',
          ),
          value: 'subtotal_with_tax',
          groupValue: _tipCalculationBase,
          onChanged: disabled
              ? null
              : (v) => setState(
                    () => _tipCalculationBase = v ?? 'subtotal_with_tax',
                  ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplica a',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Si no marcás ninguno, la propina aplica a todos los tipos de orden.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _appliesToChip('dine_in', 'Salón'),
                  _appliesToChip('takeaway', 'Para llevar'),
                  _appliesToChip('delivery', 'Delivery'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appliesToChip(String value, String label) {
    final selected = _tipAppliesTo.contains(value);
    final disabled = !_tipEnabled || _tipMode == 'disabled' || _saving;
    // `AppFilterChip` — contraste garantizado al seleccionar
    // (FilterChip de Material dejaba el texto invisible sobre el
    // fondo de acento).
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: AppFilterChip(
        label: label,
        selected: selected,
        onTap: disabled
            ? () {}
            : () => setState(() {
                  if (!selected) {
                    _tipAppliesTo.add(value);
                  } else {
                    _tipAppliesTo.remove(value);
                  }
                }),
      ),
    );
  }

  void _addSuggestedPercentage() {
    final raw = _tipNewPctCtrl.text.trim().replaceAll(',', '.');
    final pct = double.tryParse(raw);
    if (pct == null || pct <= 0 || pct > 100) {
      AppSnackbar.show(
        'Porcentaje inválido',
        'Ingresá un valor entre 0 y 100.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final decimal = pct / 100;
    setState(() {
      if (!_tipSuggestedPercentages.any((p) => (p - decimal).abs() < 1e-9)) {
        _tipSuggestedPercentages.add(decimal);
        _tipSuggestedPercentages.sort();
      }
      _tipNewPctCtrl.clear();
    });
  }

  String _formatPct(double decimal) {
    final pct = decimal * 100;
    return pct % 1 == 0
        ? '${pct.toStringAsFixed(0)}%'
        : '${CurrencyFormatter.format(pct)}%';
  }
}

/// Tarjeta de sección con título, descripción y children.
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Vista previa: muestra cómo quedaría una orden de \$10.000 según los settings.
class _PreviewCard extends StatelessWidget {
  final bool enabled;
  final String rateText;
  final bool included;

  const _PreviewCard({
    required this.enabled,
    required this.rateText,
    required this.included,
  });

  @override
  Widget build(BuildContext context) {
    final pct = double.tryParse(rateText.replaceAll(',', '.')) ?? 0;
    final rate = pct / 100;
    const example = 10000.0;

    double subtotal;
    double tax;
    double total;
    String explanation;

    if (!enabled || rate <= 0) {
      subtotal = example;
      tax = 0;
      total = example;
      explanation = 'Sin IVA. El cliente paga lo que ve en el menú.';
    } else if (included) {
      subtotal = example;
      tax = example - example / (1 + rate);
      total = example;
      explanation =
          'El IVA está dentro de los \$$example. El cliente paga \$$example y la factura desglosa el IVA implícito.';
    } else {
      subtotal = example;
      tax = example * rate;
      total = example + tax;
      explanation =
          'El IVA se suma encima. El cliente paga \$${total.toStringAsFixed(0)}.';
    }

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Vista previa con un producto de \$10.000',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _previewRow('Subtotal', subtotal),
            _previewRow('IVA${pct > 0 ? " (${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 2)}%)" : ""}', tax),
            const Divider(),
            _previewRow('Total a pagar', total, bold: true),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            '${CurrencyFormatter.format(value)}',
            style: style,
          ),
        ],
      ),
    );
  }
}
