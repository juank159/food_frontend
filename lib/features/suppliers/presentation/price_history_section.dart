import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/config/formatters/datetime_formatter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../inventory/domain/entities/ingredient.dart';
import '../../inventory/presentation/widgets/inventory_format.dart';
import '../data/suppliers_models.dart';
import '../data/suppliers_repository.dart';

/// Evolución del precio de compra de un insumo (cada compra con su
/// proveedor) y la variación entre la última y la anterior.
class PriceHistorySection extends StatefulWidget {
  final String ingredientId;
  final IngredientUnit unit;
  const PriceHistorySection({super.key, required this.ingredientId, required this.unit});

  @override
  State<PriceHistorySection> createState() => _PriceHistorySectionState();
}

class _PriceHistorySectionState extends State<PriceHistorySection> {
  List<PricePoint>? _points;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pts = await GetIt.instance<SuppliersRepository>().fetchPriceHistory(widget.ingredientId);
      if (!mounted) return;
      setState(() {
        _points = pts;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pts = _points ?? const <PricePoint>[];
    if (_loaded && pts.isEmpty) return const SizedBox.shrink();
    if (!_loaded) return const SizedBox.shrink();
    final last = pts.first.unitCost;
    final prev = pts.length > 1 ? pts[1].unitCost : null;
    final change = prev != null && prev > 0 ? (last - prev) / prev * 100 : null;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Evolución del precio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (change != null && change.abs() >= 0.5)
                Text(
                  '${change > 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}% vs. anterior',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: change > 0 ? AppColors.error : AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in pts.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_shipping_outlined, size: 20),
              title: Text(unitCostLabel(CurrencyFormatter.format(p.unitCost), widget.unit)),
              subtitle: Text([
                if (p.at != null) DateTimeFormatter.dateOnly(p.at!),
                fmtQty(p.quantity, widget.unit),
                if (p.supplier != null && p.supplier!.isNotEmpty) p.supplier!,
              ].join(' · ')),
            ),
        ],
      ),
    );
  }
}
