import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/services/branch/branch_service.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Precio y disponibilidad del producto en cada sede (catálogo único).
/// Solo se muestra con varias sedes. Vacío = igual que el catálogo.
class ProductBranchSettingsSection extends StatefulWidget {
  final String productId;
  final double basePrice;
  final bool catalogAvailable;

  const ProductBranchSettingsSection({
    super.key,
    required this.productId,
    required this.basePrice,
    required this.catalogAvailable,
  });

  @override
  State<ProductBranchSettingsSection> createState() => _ProductBranchSettingsSectionState();
}

class _BranchSetting {
  double? price;
  bool? isAvailable;
  _BranchSetting({this.price, this.isAvailable});
}

class _ProductBranchSettingsSectionState extends State<ProductBranchSettingsSection> {
  final Dio _dio = GetIt.I<Dio>();
  Map<String, _BranchSetting>? _settings;
  bool _error = false;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final rows = ApiResponseUtils.list(
        await _dio.get('/products/${widget.productId}/branch-settings'),
      );
      final map = <String, _BranchSetting>{};
      for (final r in rows.whereType<Map>()) {
        final price = r['price'];
        map[r['branch_id'] as String] = _BranchSetting(
          price: price is num ? price.toDouble() : (price is String ? double.tryParse(price) : null),
          isAvailable: r['is_available'] as bool?,
        );
      }
      if (mounted) setState(() => _settings = map);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _save(String branchId, {Object? price = _keep, Object? isAvailable = _keep}) async {
    setState(() => _saving.add(branchId));
    try {
      final res = await _dio.put(
        '/products/${widget.productId}/branch-settings/$branchId',
        data: {
          if (price != _keep) 'price': price,
          if (isAvailable != _keep) 'is_available': isAvailable,
        },
      );
      final r = ApiResponseUtils.object(res);
      final p = r['price'];
      _settings![branchId] = _BranchSetting(
        price: p is num ? p.toDouble() : null,
        isAvailable: r['is_available'] as bool?,
      );
    } on DioException catch (e) {
      AppSnackbar.show('Sedes', ApiResponseUtils.errorMessage(e) ?? 'No se pudo guardar');
    } finally {
      if (mounted) setState(() => _saving.remove(branchId));
    }
  }

  Future<void> _editPrice(BranchInfo b) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BranchPriceDialog(
        branchName: b.name,
        current: _settings?[b.id]?.price,
        catalogPrice: widget.basePrice,
      ),
    );
    if (result == null) return;
    await _save(b.id, price: result.isEmpty ? null : double.parse(result));
  }

  @override
  Widget build(BuildContext context) {
    final service = BranchService.maybe;
    if (service == null) return const SizedBox.shrink();
    return Obx(() {
      if (!service.isMulti) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Precio y disponibilidad por sede',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'El catálogo es uno solo. Acá podés cambiar el precio o pausar el producto en una sede.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            if (_error)
              const Text('No se pudo cargar (sin conexión).')
            else if (_settings == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final b in service.mine) _row(b),
          ],
        ),
      );
    });
  }

  Widget _row(BranchInfo b) {
    final s = _settings![b.id];
    final price = s?.price;
    final available = widget.catalogAvailable && s?.isAvailable != false;
    final busy = _saving.contains(b.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        price == null
            ? '${CurrencyFormatter.format(widget.basePrice)} (catálogo)'
            : '${CurrencyFormatter.format(price)} (propio de la sede)',
      ),
      onTap: busy ? null : () => _editPrice(b),
      trailing: busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                Switch(
                  value: available,
                  onChanged: widget.catalogAvailable
                      // false = apagado en esta sede; true = como el catálogo.
                      ? (v) => _save(b.id, isAvailable: v ? null : false)
                      : null,
                ),
              ],
            ),
    );
  }
}

const Object _keep = Object();

/// Diálogo con su propio controller: se libera cuando el diálogo termina
/// de cerrarse (liberarlo apenas vuelve `showDialog` rompe la animación
/// de salida — "TextEditingController used after being disposed").
class _BranchPriceDialog extends StatefulWidget {
  final String branchName;
  final double? current;
  final double catalogPrice;

  const _BranchPriceDialog({
    required this.branchName,
    required this.current,
    required this.catalogPrice,
  });

  @override
  State<_BranchPriceDialog> createState() => _BranchPriceDialogState();
}

class _BranchPriceDialogState extends State<_BranchPriceDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.current?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Precio en ${widget.branchName}'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          prefixText: '\$ ',
          helperMaxLines: 2,
          helperText:
              'Vacío = precio del catálogo (${CurrencyFormatter.format(widget.catalogPrice)})',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
