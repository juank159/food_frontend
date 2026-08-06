import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/safe_nav.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/payment_listener_controller.dart';

class PaymentListenerScreen extends StatelessWidget {
  const PaymentListenerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PaymentListenerController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: ctrl.refreshPermissions,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    const SizedBox(height: 12),
                    _PermissionsCard(),
                    const SizedBox(height: 12),
                    _GlobalToggleCard(),
                    const SizedBox(height: 12),
                    _BanksCard(),
                    const SizedBox(height: 12),
                    _TemplateCard(),
                    const SizedBox(height: 12),
                    _HelpCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => SafeNav.back(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escucha de pagos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Habla cuando llega un pago bancario',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Permisos ─────────────────────────────────────────────────────────────────

class _PermissionsCard extends GetView<PaymentListenerController> {
  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      title: 'Permisos requeridos',
      subtitle: 'Sin estos permisos el módulo no puede funcionar.',
      icon: Icons.security_outlined,
      accent: AppColors.warning,
      children: [
        Obx(() => _PermRow(
              icon: Icons.notifications_active_outlined,
              title: 'Acceso a notificaciones',
              subtitle: 'Permite leer notificaciones de apps bancarias',
              ok: controller.hasListenerPermission.value,
              actionLabel: 'Habilitar',
              onAction: controller.openNotificationSettings,
            )),
        Obx(() => _PermRow(
              icon: Icons.battery_full_outlined,
              title: 'Sin restricción de batería',
              subtitle: 'Evita que el sistema mate el servicio (Xiaomi/Samsung)',
              ok: controller.hasBatteryOptimization.value,
              actionLabel: 'Excluir',
              onAction: controller.requestBatteryOptimization,
            )),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: ok ? AppColors.success : AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (ok)
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
          else
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── Toggle global ─────────────────────────────────────────────────────────────

class _GlobalToggleCard extends GetView<PaymentListenerController> {
  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      title: 'Activar escucha',
      subtitle: 'Habilita la detección de pagos en este dispositivo.',
      icon: Icons.hearing_outlined,
      accent: AppColors.primary,
      children: [
        Obx(() => SwitchListTile(
              title: const Text('Escucha de pagos activa',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'El servicio leerá las notificaciones bancarias en segundo plano',
                style: TextStyle(fontSize: 12),
              ),
              value: controller.isEnabled.value,
              onChanged: controller.setEnabled,
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            )),
      ],
    );
  }
}

// ── Bancos ────────────────────────────────────────────────────────────────────

class _BanksCard extends GetView<PaymentListenerController> {
  static const _bankIcons = <String, String>{
    'com.nequi.mobileapp': '💜',
    'com.bancolombia.bancolombia': '🟡',
    'co.com.davivienda.daviplataapp': '🔴',
    'com.movii.app': '🟢',
    'com.bbva.bbvanetcash': '💙',
    'co.com.bancobogota.pab': '🔵',
  };

  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      title: 'Apps bancarias',
      subtitle: 'Activá solo las cuentas que querés monitorear.',
      icon: Icons.account_balance_outlined,
      accent: AppColors.success,
      children: kSupportedBanks.entries.map((e) {
        final pkg = e.key;
        final name = e.value;
        final emoji = _bankIcons[pkg] ?? '🏦';
        return Obx(() => SwitchListTile(
              title: Text('$emoji  $name',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(pkg,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
              value: controller.enabledBanks.contains(pkg),
              onChanged: (v) => controller.toggleBank(pkg, v),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ));
      }).toList(),
    );
  }
}

// ── Template de mensaje ───────────────────────────────────────────────────────

class _TemplateCard extends GetView<PaymentListenerController> {
  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    return AppFormSection(
      title: 'Mensaje hablado',
      subtitle:
          'Usa {monto} para el valor y {banco} para el nombre de la app.',
      icon: Icons.record_voice_over_outlined,
      accent: const Color(0xFF9C27B0),
      children: [
        Obx(() => TextFormField(
              key: ValueKey(ctrl.template.value),
              initialValue: ctrl.template.value,
              onChanged: ctrl.setTemplate,
              decoration: InputDecoration(
                hintText: 'Llegó {monto} por {banco}',
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
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Restaurar',
                  onPressed: () =>
                      ctrl.setTemplate('Llegó {monto} por {banco}'),
                ),
              ),
            )),
        const SizedBox(height: 8),
        Obx(() => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volume_up_outlined, size: 18,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _preview(ctrl.template.value),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: ctrl.testTts,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
            label: const Text('Probar voz ahora',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  String _preview(String tpl) => tpl
      .replaceAll('{monto}', '\$50.000')
      .replaceAll('{banco}', 'Nequi')
      .replaceAll('{banco_nombre}', 'Nequi');
}

// ── Ayuda ─────────────────────────────────────────────────────────────────────

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      title: 'Cómo funciona',
      subtitle: 'Instrucciones para configurar este módulo correctamente.',
      icon: Icons.help_outline_rounded,
      accent: AppColors.textSecondary,
      children: const [
        _HelpItem(
          step: '1',
          text: 'Habilita el permiso de acceso a notificaciones (solo se pide una vez).',
        ),
        _HelpItem(
          step: '2',
          text: 'Excluye la app de la optimización de batería para que el servicio no se detenga.',
        ),
        _HelpItem(
          step: '3',
          text: 'Activa las apps bancarias que quieres monitorear.',
        ),
        _HelpItem(
          step: '4',
          text: 'Cuando llegue un pago, el celular hablará el monto incluso con la pantalla bloqueada.',
        ),
        _HelpItem(
          step: '5',
          text: 'Los demás dispositivos de admin recibirán una notificación del pago.',
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String step;
  final String text;
  const _HelpItem({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(step,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
