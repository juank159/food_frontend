import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/subscription_plan.dart';
import '../controllers/subscription_controller.dart';

/// Planes disponibles con selector de ciclo (mensual / semestral / anual).
///
/// El cobro es manual: el negocio SOLICITA el plan y la plataforma lo
/// activa cuando recibe el pago. Mientras hay una solicitud pendiente se
/// muestra arriba con la opción de cancelarla.
class PlanComparisonCard extends GetView<SubscriptionController> {
  const PlanComparisonCard({super.key});

  static const _cycles = ['monthly', 'semiannual', 'yearly'];

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Obx(() {
      if (controller.plans.isEmpty) {
        return const SizedBox.shrink();
      }
      final cycle = controller.selectedCycle.value;
      final pending = controller.pendingRequest.value;
      final paid = controller.plans.where((p) => !p.isFree).toList();

      final cards = paid.map((p) => _buildPlanCard(p, cycle, context)).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pending != null) ...[
            _PendingRequestBanner(request: pending),
            const SizedBox(height: 16),
          ],
          _buildCycleSelector(cycle),
          const SizedBox(height: 16),
          if (responsive.isMobile)
            ...cards.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: c,
                ))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: c,
                        ),
                      ))
                  .toList(),
            ),
        ],
      );
    });
  }

  Widget _buildCycleSelector(String cycle) {
    return SegmentedButton<String>(
      segments: _cycles
          .map((c) => ButtonSegment<String>(
                value: c,
                label: Text(SubscriptionPlan.cycleLabel(c)),
              ))
          .toList(),
      selected: {cycle},
      showSelectedIcon: false,
      onSelectionChanged: (s) => controller.selectedCycle.value = s.first,
    );
  }

  Widget _buildPlanCard(
      SubscriptionPlan plan, String cycle, BuildContext context) {
    final isCurrent = controller.isCurrentPlan(plan) &&
        !(controller.usage.value?.isTrial ?? false);
    final total = plan.priceFor(cycle);
    final perMonth = plan.monthlyEquivalent(cycle);
    final savings = plan.savingsFor(cycle);
    final pending = controller.pendingRequest.value;
    final pendingThis = pending != null &&
        pending['plan_code'] == plan.code &&
        pending['billing_cycle'] == cycle;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCurrent) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PLAN ACTUAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            plan.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${CurrencyFormatter.format(perMonth)} / mes',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          if (cycle != 'monthly') ...[
            const SizedBox(height: 4),
            Text(
              'Pagás ${CurrencyFormatter.format(total)} '
              '${cycle == 'yearly' ? 'por el año' : 'por 6 meses'}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (savings > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Ahorrás ${CurrencyFormatter.format(savings)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            plan.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: controller.isChangingPlan.value || pendingThis
                  ? null
                  : () => _confirmRequest(plan, cycle, isCurrent, context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                pendingThis
                    ? 'Solicitud enviada'
                    : isCurrent
                        ? 'Renovar'
                        : 'Solicitar plan',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRequest(SubscriptionPlan plan, String cycle,
      bool renewal, BuildContext context) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => _RequestPlanDialog(
        plan: plan,
        cycle: cycle,
        renewal: renewal,
        replacesPending: controller.pendingRequest.value != null,
      ),
    );
    if (notes == null) return; // canceló
    final ok = await controller.requestPlan(plan.code, cycle, notes: notes);
    if (!ok || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined,
            color: AppColors.success, size: 40),
        title: const Text('Solicitud enviada'),
        content: Text(
          'Te vamos a contactar para el pago de '
          '${CurrencyFormatter.format(plan.priceFor(cycle))}. '
          'Apenas lo recibamos activamos tu plan ${plan.name} y lo vas a ver '
          'acá. Tu cuenta sigue funcionando igual mientras tanto.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

/// Confirma la solicitud y permite dejar una nota (ej. "pago por Bre-B").
/// Devuelve la nota (puede ser vacía) o `null` si se canceló. Es
/// Stateful para que el TextEditingController viva y muera con el
/// diálogo (no se libera mientras la animación de cierre lo usa).
class _RequestPlanDialog extends StatefulWidget {
  final SubscriptionPlan plan;
  final String cycle;
  final bool renewal;
  final bool replacesPending;

  const _RequestPlanDialog({
    required this.plan,
    required this.cycle,
    required this.renewal,
    required this.replacesPending,
  });

  @override
  State<_RequestPlanDialog> createState() => _RequestPlanDialogState();
}

class _RequestPlanDialogState extends State<_RequestPlanDialog> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final total = plan.priceFor(widget.cycle);
    return AlertDialog(
      title: Text(widget.renewal
          ? 'Renovar ${plan.name}'
          : 'Solicitar plan ${plan.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${SubscriptionPlan.cycleLabel(widget.cycle)} · '
              '${CurrencyFormatter.format(total)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Te contactamos para coordinar el pago. El plan se activa '
              'apenas lo confirmemos.',
            ),
            if (widget.replacesPending) ...[
              const SizedBox(height: 8),
              const Text(
                'Esto reemplaza tu solicitud anterior.',
                style: TextStyle(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej: pago por Bre-B, llamar en la tarde…',
                border: OutlineInputBorder(),
              ),
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
          onPressed: () => Navigator.pop(context, _notes.text),
          child: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}

class _PendingRequestBanner extends GetView<SubscriptionController> {
  final Map<String, dynamic> request;

  const _PendingRequestBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    final plan = controller.getPlanByCode('${request['plan_code']}');
    final amount = double.tryParse('${request['amount']}') ?? 0;
    final cycle = '${request['billing_cycle']}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: AppColors.info, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud pendiente: ${plan?.name ?? request['plan_code']} '
                  '${SubscriptionPlan.cycleLabel(cycle).toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${CurrencyFormatter.format(amount)} · la activamos '
                  'apenas confirmemos el pago.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Obx(() => TextButton(
                onPressed: controller.isChangingPlan.value
                    ? null
                    : controller.cancelPendingRequest,
                child: const Text('Cancelar'),
              )),
        ],
      ),
    );
  }
}
