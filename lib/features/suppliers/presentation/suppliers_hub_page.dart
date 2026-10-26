import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_sync_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_filter_chip.dart';
import '../../inventory/domain/entities/ingredient.dart';
import '../../inventory/presentation/widgets/inventory_format.dart';
import '../data/suppliers_models.dart';
import '../data/suppliers_repository.dart';
import 'supplier_detail_page.dart';
import 'supplier_sheets.dart';

/// Proveedores y compras: por pagar, compras/órdenes, proveedores,
/// compras sugeridas y gasto por proveedor. Se lee de la copia local (sin
/// internet también) y se refresca al abrir.
class SuppliersHubPage extends StatefulWidget {
  const SuppliersHubPage({super.key});

  @override
  State<SuppliersHubPage> createState() => _SuppliersHubPageState();
}

class _SuppliersHubPageState extends State<SuppliersHubPage> {
  final _repo = GetIt.instance<SuppliersRepository>();
  List<Supplier> _suppliers = [];
  List<Purchase> _purchases = [];
  String _purchaseFilter = 'all';
  bool _refreshing = false;
  Worker? _syncWorker;

  @override
  void initState() {
    super.initState();
    _readLocal();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Al terminar de sincronizar lo hecho sin internet, traer lo real
    // (si no, lo encolado seguía diciendo "sin sincronizar").
    if (Get.isRegistered<AppSyncService>()) {
      _syncWorker = ever<bool>(Get.find<AppSyncService>().isSyncing, (syncing) {
        if (!syncing && mounted) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _syncWorker?.dispose();
    super.dispose();
  }

  void _readLocal() {
    if (!mounted) return;
    setState(() {
      _suppliers = _repo.readSuppliers();
      _purchases = _repo.readPurchases();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _repo.refresh();
    if (!mounted) return;
    _refreshing = false;
    _readLocal();
  }

  Future<void> _newPurchase({bool asOrder = false}) async {
    final r = await Get.toNamed(AppRoutes.purchaseNew, arguments: {'asOrder': asOrder});
    if (r == true) _readLocal();
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = _purchases.where((p) => p.isReceived && p.balance > 0.004).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
    final owed = unpaid.fold(0.0, (s, p) => s + p.balance);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Proveedores y compras'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Por pagar'),
              Tab(text: 'Compras'),
              Tab(text: 'Proveedores'),
              Tab(text: 'Sugeridos'),
              Tab(text: 'Reporte'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _payables(unpaid, owed),
            _purchasesTab(),
            _suppliersTab(),
            const _SuggestionsTab(),
            const _SpendTab(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _newPurchase(asOrder: true),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Orden de compra'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _newPurchase,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Registrar compra'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      );

  Widget _payables(List<Purchase> unpaid, double owed) {
    final overdue = unpaid.where((p) => p.isOverdue).fold(0.0, (s, p) => s + p.balance);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: unpaid.isEmpty
          ? _empty('No le debés nada a ningún proveedor.')
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
                      Text('Total por pagar', style: TextStyle(color: Colors.grey.shade700)),
                      Text(CurrencyFormatter.format(owed),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      if (overdue > 0)
                        Text('Vencido: ${CurrencyFormatter.format(overdue)}',
                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final p in unpaid) PurchaseTile(purchase: p, onChanged: _readLocal, showSupplier: true),
              ],
            ),
    );
  }

  Widget _purchasesTab() {
    final list = _purchases.where((p) {
      return switch (_purchaseFilter) {
        'ordered' => p.isOrder,
        'received' => p.isReceived,
        _ => !p.isCancelled,
      };
    }).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final f in const [('all', 'Todas'), ('ordered', 'Órdenes por llegar'), ('received', 'Recibidas')])
                AppFilterChip(
                  label: f.$2,
                  selected: _purchaseFilter == f.$1,
                  onTap: () => setState(() => _purchaseFilter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No hay compras para mostrar.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            ),
          for (final p in list) PurchaseTile(purchase: p, onChanged: _readLocal, showSupplier: true),
        ],
      ),
    );
  }

  Widget _suppliersTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              if (await showSupplierForm(context)) _readLocal();
            },
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Nuevo proveedor'),
          ),
          const SizedBox(height: 12),
          if (_suppliers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Agregá tus proveedores para saber cuánto les comprás y cuánto les debés.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            ),
          for (final s in _suppliers)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                onTap: s.pendingSync
                    ? null
                    : () async {
                        await Get.toNamed(AppRoutes.supplierDetail.replaceFirst(':id', s.id));
                        _readLocal();
                      },
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(s.name.characters.first.toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                ),
                title: Text(s.name, style: TextStyle(fontWeight: FontWeight.w700, color: s.isActive ? null : Colors.grey)),
                subtitle: Text([
                  if (s.pendingSync) 'sin sincronizar',
                  if (!s.isActive) 'inactivo',
                  if (s.phone != null) s.phone!,
                  '${s.purchasesCount} compra${s.purchasesCount == 1 ? '' : 's'}',
                ].join(' · ')),
                trailing: s.balanceOwed > 0.004
                    ? Text(CurrencyFormatter.format(s.balanceOwed),
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w800))
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compras sugeridas para la sede según el consumo real; se eligen y se
/// crean órdenes de compra (una por proveedor).
class _SuggestionsTab extends StatefulWidget {
  const _SuggestionsTab();

  @override
  State<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<_SuggestionsTab> with AutomaticKeepAliveClientMixin {
  final _repo = GetIt.instance<SuppliersRepository>();
  List<PurchaseSuggestion> _items = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _offline = false;
  bool _creating = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _items = _repo.readSuggestions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final fresh = await _repo.fetchSuggestions();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = fresh == null;
      if (fresh != null) _items = fresh;
      _selected
        ..clear()
        ..addAll(_items.map((i) => i.ingredientId));
    });
  }

  Future<void> _createOrders() async {
    final chosen = _items.where((i) => _selected.contains(i.ingredientId)).toList();
    if (chosen.isEmpty) return;
    setState(() => _creating = true);
    final bySupplier = <String?, List<PurchaseSuggestion>>{};
    for (final i in chosen) {
      bySupplier.putIfAbsent(i.lastSupplierId, () => []).add(i);
    }
    var created = 0;
    var queued = false;
    String? error;
    for (final e in bySupplier.entries) {
      final r = await _repo.createPurchase({
        if (e.key != null) 'supplier_id': e.key,
        'status': 'ordered',
        'notes': 'Orden sugerida por consumo',
        'lines': [
          for (final i in e.value)
            {
              'ingredient_id': i.ingredientId,
              'quantity': i.suggestedQuantity,
              if (i.unitCost > 0) 'unit_cost': i.unitCost,
            },
        ],
      });
      if (r.failed) {
        error = r.error;
        break;
      }
      created++;
      queued = queued || !r.synced;
    }
    if (!mounted) return;
    setState(() => _creating = false);
    if (error != null) {
      AppSnackbar.show('Órdenes', error);
      return;
    }
    AppSnackbar.show(
      'Órdenes de compra',
      '$created orden${created == 1 ? '' : 'es'} creada${created == 1 ? '' : 's'}'
          '${queued ? ' (sin internet: se sincronizan solas)' : ''}. Mirá la pestaña Compras.',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final total = _items
        .where((i) => _selected.contains(i.ingredientId))
        .fold(0.0, (s, i) => s + i.estimatedCost);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Según lo que se vendió en esta sede los últimos 14 días: pide para cubrir 7 días más el mínimo.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (_offline)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Sin internet: mostrando la última sugerencia guardada.',
                  style: TextStyle(color: AppColors.warning)),
            ),
          const SizedBox(height: 12),
          if (_loading && _items.isEmpty) const Center(child: CircularProgressIndicator()),
          if (!_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hace falta comprar nada por ahora. 👍', textAlign: TextAlign.center),
            ),
          for (final i in _items)
            CheckboxListTile(
              value: _selected.contains(i.ingredientId),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(i.ingredientId);
                } else {
                  _selected.remove(i.ingredientId);
                }
              }),
              title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                'Comprar ${fmtQty(i.suggestedQuantity, IngredientUnit.fromCode(i.unit))}',
                'hay ${fmtQty(i.currentStock, IngredientUnit.fromCode(i.unit))}',
                if (i.currentStock <= 0)
                  'agotado'
                else if (i.daysLeft != null)
                  'alcanza ~${i.daysLeft!.toStringAsFixed(1)} días',
                if (i.lastSupplier != null) i.lastSupplier!,
              ].join(' · ')),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Text(CurrencyFormatter.format(i.estimatedCost),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _creating || _selected.isEmpty ? null : _createOrders,
              icon: const Icon(Icons.schedule_send),
              label: Text(_creating
                  ? 'Creando…'
                  : 'Crear órdenes de compra (${CurrencyFormatter.format(total)})'),
            ),
            const SizedBox(height: 4),
            Text('Se crea una orden por proveedor (el de la última compra de cada insumo).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Cuánto se le compró a cada proveedor en un período.
class _SpendTab extends StatefulWidget {
  const _SpendTab();

  @override
  State<_SpendTab> createState() => _SpendTabState();
}

class _SpendTabState extends State<_SpendTab> with AutomaticKeepAliveClientMixin {
  final _repo = GetIt.instance<SuppliersRepository>();
  String _period = 'month';
  List<SupplierSpend>? _rows;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    return switch (_period) {
      'last_month' => (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1))),
      'quarter' => (DateTime(now.year, now.month - 2, 1), now),
      _ => (DateTime(now.year, now.month, 1), now),
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _range();
    final rows = await _repo.fetchSpend(from, to);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = _rows ?? const <SupplierSpend>[];
    final max = rows.fold(0.0, (m, r) => r.total > m ? r.total : m);
    final total = rows.fold(0.0, (s, r) => s + r.total);
    final online = !Get.isRegistered<ConnectivityService>() || Get.find<ConnectivityService>().isOnline.value;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final p in const [('month', 'Este mes'), ('last_month', 'Mes pasado'), ('quarter', 'Últimos 3 meses')])
                AppFilterChip(
                  label: p.$2,
                  selected: _period == p.$1,
                  onTap: () {
                    setState(() => _period = p.$1);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _rows == null)
            Text(online ? 'No se pudo cargar el reporte.' : 'El reporte necesita internet.',
                style: TextStyle(color: Colors.grey.shade700)),
          if (!_loading && _rows != null && rows.isEmpty)
            Text('No hubo compras en este período.', style: TextStyle(color: Colors.grey.shade700)),
          if (rows.isNotEmpty) ...[
            Text('Total comprado: ${CurrencyFormatter.format(total)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text(CurrencyFormatter.format(r.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: max > 0 ? r.total / max : 0,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.purchasesCount} compra${r.purchasesCount == 1 ? '' : 's'}'
                      '${r.owed > 0.004 ? ' · se debe ${CurrencyFormatter.format(r.owed)}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
