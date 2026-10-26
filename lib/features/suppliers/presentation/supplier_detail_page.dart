import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/config/formatters/datetime_formatter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_snackbar.dart';
import '../data/suppliers_models.dart';
import '../data/suppliers_repository.dart';
import 'purchase_detail_page.dart';
import 'supplier_sheets.dart';

/// Ficha de un proveedor: contacto, lo que se le debe y sus compras.
class SupplierDetailPage extends StatefulWidget {
  const SupplierDetailPage({super.key});

  @override
  State<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends State<SupplierDetailPage> {
  final _repo = GetIt.instance<SuppliersRepository>();
  late final String _id = Get.parameters['id'] ?? '';
  Supplier? _s;
  List<Purchase> _purchases = [];

  @override
  void initState() {
    super.initState();
    _readLocal();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _repo.refresh();
      _readLocal();
    });
  }

  void _readLocal() {
    if (!mounted) return;
    setState(() {
      _s = _repo.readSuppliers().firstWhereOrNull((s) => s.id == _id);
      _purchases = _repo.readPurchases().where((p) => p.supplierId == _id).toList();
    });
  }

  double get _owed => _purchases
      .where((p) => p.isReceived)
      .fold(0.0, (sum, p) => sum + p.balance);

  Future<void> _pay() async {
    if (_s == null) return;
    if (await showPaySupplierSheet(context, supplier: _s!, owed: _owed)) _readLocal();
  }

  Future<void> _edit() async {
    if (_s == null || _s!.pendingSync) {
      AppSnackbar.show('Proveedor', 'Esperá a que se sincronice para editarlo.');
      return;
    }
    if (await showSupplierForm(context, supplier: _s)) _readLocal();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s?.name ?? 'Proveedor'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined))],
      ),
      body: s == null
          ? const Center(child: Text('Proveedor no encontrado.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Se le debe', style: TextStyle(color: Colors.grey.shade700)),
                      Text(
                        CurrencyFormatter.format(_owed),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _owed > 0 ? AppColors.error : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (s.phone != null) _chip(Icons.phone, s.phone!),
                          if (s.contactName != null) _chip(Icons.person_outline, s.contactName!),
                          if (s.taxId != null) _chip(Icons.badge_outlined, 'NIT ${s.taxId}'),
                          _chip(
                            Icons.event_outlined,
                            s.paymentTermsDays > 0 ? 'Crédito ${s.paymentTermsDays} días' : 'De contado',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final r = await Get.toNamed(
                            AppRoutes.purchaseNew,
                            arguments: {'supplierId': s.id},
                          );
                          if (r == true) _readLocal();
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Nueva compra'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _owed > 0.004 && !s.pendingSync ? _pay : null,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Pagar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Compras', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                if (_purchases.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Todavía no hay compras a este proveedor.'),
                  ),
                for (final p in _purchases) PurchaseTile(purchase: p, onChanged: _readLocal),
              ],
            ),
    );
  }

  Widget _chip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Colors.grey.shade800)),
        ],
      );
}

/// Fila de una compra en las listas.
class PurchaseTile extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onChanged;
  final bool showSupplier;
  const PurchaseTile({
    super.key,
    required this.purchase,
    required this.onChanged,
    this.showSupplier = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    final color = purchaseStatusColor(p);
    final date = p.receivedAt ?? p.orderedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        onTap: () async {
          final r = await Get.toNamed(AppRoutes.purchaseDetail.replaceFirst(':id', p.id));
          if (r == true) onChanged();
        },
        title: Text(
          showSupplier ? (p.supplierName ?? 'Sin proveedor') : (p.invoiceNumber != null ? 'Factura ${p.invoiceNumber}' : 'Compra'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          if (date != null) DateTimeFormatter.dateOnly(date),
          '${p.lines.length} insumo${p.lines.length == 1 ? '' : 's'}',
          if (p.isReceived && p.balance > 0.004 && p.dueDate != null)
            'vence ${DateTimeFormatter.dateOnly(p.dueDate!)}',
          if (p.pendingSync) 'sin sincronizar',
        ].join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(CurrencyFormatter.format(p.isReceived && p.balance > 0.004 ? p.balance : p.total),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(purchaseStatusLabel(p),
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
