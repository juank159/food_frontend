import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/branch/branch_service.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Sedes del negocio (multi-sucursal, plan Professional). Solo el dueño.
///
/// Cuántas sedes ACTIVAS se pueden tener lo decide el plan (lo valida el
/// servidor). Una sede nunca se borra: se desactiva y su historial queda.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final Dio _dio = GetIt.I<Dio>();
  bool _loading = true;
  String? _error;
  List<BranchInfo> _branches = [];
  int? _limit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/branches');
      _branches = ApiResponseUtils.list(res)
          .whereType<Map>()
          .map((e) => BranchInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      try {
        final usage = ApiResponseUtils.object(await _dio.get('/subscriptions/usage'));
        final limits = (usage['limits'] as Map?)?.cast<String, dynamic>();
        final raw = limits?['max_branches'];
        _limit = raw is num ? raw.toInt() : null;
      } catch (_) {
        _limit = null;
      }
    } on DioException catch (e) {
      _error = ApiResponseUtils.errorMessage(e) ??
          'No se pudieron cargar las sedes. Revisá tu conexión.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Tras cualquier cambio: el resto de la app (selector de sede) se entera.
  Future<void> _afterChange() async {
    await _load();
    final user = Get.find<AuthController>().currentUser;
    await BranchService.maybe?.refresh(_dio, roleCode: user?.roleCode);
  }

  int get _activeCount => _branches.where((b) => b.isActive).length;

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      if (ok != null) AppSnackbar.show('Sedes', ok);
      await _afterChange();
    } on DioException catch (e) {
      final body = e.response?.data;
      final code = body is Map ? body['code']?.toString() : null;
      final msg = ApiResponseUtils.errorMessage(e) ?? 'No se pudo guardar';
      if (code == 'PLAN_LIMIT_REACHED') {
        _showUpgrade(msg);
      } else {
        AppSnackbar.show('Sedes', msg);
      }
    }
  }

  void _showUpgrade(String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.workspace_premium, color: Color(0xFF8B5CF6), size: 36),
        title: const Text('Más sedes con el plan Professional'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ahora no')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.toNamed(AppRoutes.subscriptionPlans);
            },
            child: const Text('Ver planes'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit([BranchInfo? branch]) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _BranchFormDialog(branch: branch),
    );
    if (result == null) return;
    if (branch == null) {
      await _run(() => _dio.post('/branches', data: result), ok: 'Sede "${result['name']}" creada');
    } else {
      await _run(() => _dio.patch('/branches/${branch.id}', data: result), ok: 'Sede actualizada');
    }
  }

  Future<void> _toggle(BranchInfo b) async {
    if (b.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('¿Desactivar "${b.name}"?'),
          content: const Text(
            'No se podrá elegir para vender. Su historial (ventas, caja, inventario) '
            'se conserva y podés reactivarla cuando quieras.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desactivar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(
      () => _dio.patch('/branches/${b.id}', data: {'is_active': !b.isActive}),
      ok: b.isActive ? 'Sede desactivada' : 'Sede activada',
    );
  }

  Future<void> _makeDefault(BranchInfo b) => _run(
        () => _dio.post('/branches/${b.id}/default'),
        ok: '"${b.name}" es ahora la sede principal',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sedes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : AppPrimaryActionBar(
              label: 'Nueva sede',
              icon: Icons.add_business,
              onPressed: () => _edit(),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _UsageCard(active: _activeCount, limit: _limit),
                      const SizedBox(height: 12),
                      for (final b in _branches) ...[
                        _BranchTile(
                          branch: b,
                          isThisDevice: BranchService.maybe?.current.value?.id == b.id,
                          onEdit: () => _edit(b),
                          onToggle: () => _toggle(b),
                          onMakeDefault: () => _makeDefault(b),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final int active;
  final int? limit;
  const _UsageCard({required this.active, required this.limit});

  @override
  Widget build(BuildContext context) {
    final unlimited = limit == null || limit! < 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              unlimited
                  ? '$active sede${active == 1 ? '' : 's'} activa${active == 1 ? '' : 's'}'
                  : '$active de $limit sedes activas en tu plan',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  final BranchInfo branch;
  final bool isThisDevice;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onMakeDefault;

  const _BranchTile({
    required this.branch,
    required this.isThisDevice,
    required this.onEdit,
    required this.onToggle,
    required this.onMakeDefault,
  });

  @override
  Widget build(BuildContext context) {
    final b = branch;
    return Container(
      decoration: BoxDecoration(
        color: b.isActive ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Icon(
          b.isDefault ? Icons.star : Icons.store_mall_directory_outlined,
          color: b.isActive ? AppColors.primary : Colors.grey,
        ),
        title: Text(
          b.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: b.isActive ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (b.isDefault) const _Pill('Principal', Color(0xFF8B5CF6)),
            if (!b.isActive) const _Pill('Inactiva', Colors.grey),
            if (isThisDevice) const _Pill('Este dispositivo', Color(0xFF2E7D32)),
            if (b.address != null && b.address!.isNotEmpty)
              Text(b.address!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'toggle') onToggle();
            if (v == 'default') onMakeDefault();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (!b.isDefault)
              PopupMenuItem(value: 'toggle', child: Text(b.isActive ? 'Desactivar' : 'Activar')),
            if (!b.isDefault && b.isActive)
              const PopupMenuItem(value: 'default', child: Text('Hacer principal')),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _BranchFormDialog extends StatefulWidget {
  final BranchInfo? branch;
  const _BranchFormDialog({this.branch});

  @override
  State<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<_BranchFormDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.branch?.name ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.branch?.address ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.branch?.phone ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.branch == null ? 'Nueva sede' : 'Editar sede'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej. Sede Centro'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Escribí un nombre' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'address': _address.text.trim(),
              'phone': _phone.text.trim(),
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
