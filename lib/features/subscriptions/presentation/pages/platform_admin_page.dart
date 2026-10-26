import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../data/datasources/plan_billing_api.dart';
import '../../data/models/subscription_plan_model.dart';
import '../../domain/entities/subscription_plan.dart';

/// Panel del dueño de la PLATAFORMA (no de un negocio): solicitudes de
/// plan por aprobar y estado de cada negocio, con registro de pagos
/// manuales. El backend rechaza todo esto si el usuario no es admin de
/// la plataforma (`PLATFORM_ADMIN_EMAILS` o `global_role=super_admin`).
class PlatformAdminPage extends StatefulWidget {
  const PlatformAdminPage({super.key});

  @override
  State<PlatformAdminPage> createState() => _PlatformAdminPageState();
}

class _PlatformAdminPageState extends State<PlatformAdminPage> {
  final _api = PlanBillingApi(sl<Dio>());
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _tenants = [];
  List<SubscriptionPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.requests(status: 'pending'),
        _api.tenants(),
        sl<Dio>().get(ApiConstants.subscriptionPlans),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<Map<String, dynamic>>;
        _tenants = results[1] as List<Map<String, dynamic>>;
        _plans = ApiResponseUtils.list(results[2] as Response)
            .whereType<Map<String, dynamic>>()
            .map((j) => SubscriptionPlanModel.fromJson(j).toEntity())
            .where((p) => !p.isFree)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = PlanBillingApi.messageOf(e, 'No se pudo cargar');
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text(PlanBillingApi.messageOf(e)),
      ));
    }
  }

  String _planName(String? code) =>
      _plans.where((p) => p.code == code).map((p) => p.name).firstOrNull ??
      (code ?? '—');

  static String _date(dynamic iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '—' : '${d.day}/${d.month}/${d.year}';
  }

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppGradientHeader(
                title: 'Plataforma',
                subtitle: 'Planes y pagos de los negocios',
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Refrescar',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ),
              TabBar(
                labelColor: AppColors.primary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Solicitudes (${_requests.length})'),
                  Tab(text: 'Negocios (${_tenants.length})'),
                ],
              ),
              Expanded(
                child: _loading
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
                                  FilledButton(
                                    onPressed: _load,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : TabBarView(
                            children: [_buildRequests(), _buildTenants()],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── Solicitudes ─────────────────────────────

  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('No hay solicitudes pendientes')),
          ],
        ),
      );
    }
    final names = {
      for (final t in _tenants) '${t['tenant_id']}': '${t['business_name']}'
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final r = _requests[i];
          final cycle = '${r['billing_cycle']}';
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    names['${r['tenant_id']}'] ?? '${r['tenant_id']}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_planName(r['plan_code'] as String?)} · '
                    '${SubscriptionPlan.cycleLabel(cycle)} · '
                    '${CurrencyFormatter.format(_num(r['amount']))}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pedido por ${r['requested_by_email'] ?? '—'} el '
                    '${_date(r['created_at'])}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if ((r['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Nota: ${r['notes']}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _reject(r),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('Rechazar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _approve(r),
                        icon: const Icon(Icons.check),
                        label: const Text('Pago recibido'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(
        title: 'Confirmar pago',
        amount: _num(r['amount']),
      ),
    );
    if (result == null) return;
    await _run(
      () => _api.approve('${r['id']}',
          paidAmount: result.amount, reference: result.reference),
      'Plan activado',
    );
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _TextDialog(
        title: 'Rechazar solicitud',
        label: 'Motivo (opcional)',
        confirm: 'Rechazar',
      ),
    );
    if (reason == null) return;
    await _run(() => _api.reject('${r['id']}', reason: reason),
        'Solicitud rechazada');
  }

  // ───────────────────────────── Negocios ─────────────────────────────

  Widget _buildTenants() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tenants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final t = _tenants[i];
          final (label, color, detail) = _statusOf(t);
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t['business_name']}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t['plan_name'] ?? '—'} · $detail',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${t['users'] ?? 0} usuarios · ${t['branches'] ?? 0} sedes'
                    '${t['last_payment_date'] != null ? ' · último pago ${_date(t['last_payment_date'])} '
                        '(${CurrencyFormatter.format(_num(t['last_payment_amount']))})' : ''}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (t['pending_request'] != null) ...[
                    const SizedBox(height: 4),
                    const Text('Tiene una solicitud pendiente',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _plans.isEmpty ? null : () => _activate(t),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Registrar pago'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  (String, Color, String) _statusOf(Map<String, dynamic> t) {
    final status = '${t['status'] ?? ''}';
    if (t['is_trial'] == true) {
      return ('Prueba', AppColors.warning, 'prueba hasta ${_date(t['trial_ends_at'])}');
    }
    switch (status) {
      case 'active':
        if (t['plan_code'] == 'free') {
          return ('Sin plan', AppColors.error, 'prueba terminada');
        }
        return ('Activo', AppColors.success,
            'vigente hasta ${_date(t['current_period_end'])}');
      case 'past_due':
        return ('En mora', AppColors.warning,
            'gracia hasta ${_date(t['grace_period_ends_at'])}');
      case 'expired':
        return ('Vencido', AppColors.error,
            'venció el ${_date(t['current_period_end'])}');
      case '':
        return ('Sin suscripción', AppColors.error, '—');
      default:
        return (status, AppColors.textSecondary, '—');
    }
  }

  Future<void> _activate(Map<String, dynamic> t) async {
    final result = await showDialog<_ActivateInput>(
      context: context,
      builder: (_) => _ActivateDialog(
        businessName: '${t['business_name']}',
        plans: _plans,
        initialPlan: t['plan_code'] == 'free' ? null : t['plan_code'] as String?,
      ),
    );
    if (result == null) return;
    await _run(
      () => _api.activate(
        '${t['tenant_id']}',
        planCode: result.planCode,
        billingCycle: result.cycle,
        paidAmount: result.amount,
        reference: result.reference,
      ),
      'Pago registrado',
    );
  }
}

// ───────────────────────────── Diálogos ─────────────────────────────

class _PaymentInput {
  final double? amount;
  final String reference;
  const _PaymentInput(this.amount, this.reference);
}

class _ActivateInput extends _PaymentInput {
  final String planCode;
  final String cycle;
  const _ActivateInput(this.planCode, this.cycle, super.amount, super.reference);
}

/// Valor recibido (prellenado con el precio) + referencia del pago.
class _PaymentDialog extends StatefulWidget {
  final String title;
  final double amount;

  const _PaymentDialog({required this.title, required this.amount});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount =
      TextEditingController(text: widget.amount.toStringAsFixed(0));
  final _reference = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor recibido (COP)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            maxLength: 255,
            decoration: const InputDecoration(
              labelText: 'Referencia (opcional)',
              hintText: 'Comprobante Bre-B, transferencia…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _PaymentInput(
              double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')),
              _reference.text,
            ),
          ),
          child: const Text('Activar plan'),
        ),
      ],
    );
  }
}

/// Activar o renovar a mano: plan + ciclo + valor + referencia.
class _ActivateDialog extends StatefulWidget {
  final String businessName;
  final List<SubscriptionPlan> plans;
  final String? initialPlan;

  const _ActivateDialog({
    required this.businessName,
    required this.plans,
    this.initialPlan,
  });

  @override
  State<_ActivateDialog> createState() => _ActivateDialogState();
}

class _ActivateDialogState extends State<_ActivateDialog> {
  late String _plan = widget.plans.any((p) => p.code == widget.initialPlan)
      ? widget.initialPlan!
      : widget.plans.first.code;
  String _cycle = 'monthly';
  final _amount = TextEditingController();
  final _reference = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncAmount();
  }

  void _syncAmount() {
    final p = widget.plans.firstWhere((p) => p.code == _plan);
    _amount.text = p.priceFor(_cycle).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Registrar pago · ${widget.businessName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(
                labelText: 'Plan',
                border: OutlineInputBorder(),
              ),
              items: widget.plans
                  .map((p) =>
                      DropdownMenuItem(value: p.code, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _plan = v ?? _plan;
                _syncAmount();
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cycle,
              decoration: const InputDecoration(
                labelText: 'Período',
                border: OutlineInputBorder(),
              ),
              items: const ['monthly', 'semiannual', 'yearly']
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(SubscriptionPlan.cycleLabel(c))))
                  .toList(),
              onChanged: (v) => setState(() {
                _cycle = v ?? _cycle;
                _syncAmount();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor recibido (COP)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const Text(
              'Si renueva el mismo plan antes de vencer, el período se suma '
              'al final del actual.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ActivateInput(
              _plan,
              _cycle,
              double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')),
              _reference.text,
            ),
          ),
          child: const Text('Activar'),
        ),
      ],
    );
  }
}

/// Pide un texto opcional; devuelve '' si lo dejan vacío o null si cancelan.
class _TextDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirm;

  const _TextDialog({
    required this.title,
    required this.label,
    required this.confirm,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        maxLength: 500,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
