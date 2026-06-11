import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/widgets.dart';

/// Hub central de configuración. Reemplaza el placeholder de `/settings`.
///
/// Listado por secciones lógicas: cuenta, negocio, operaciones y
/// suscripción. Cada item es un tile con icono tintado, título,
/// subtítulo y chevron — mismo lenguaje visual que `_QuickActionTile`
/// del dashboard.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildSectionTitle('Cuenta'),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.account_circle_outlined,
                    title: 'Perfil',
                    subtitle: 'Tu nombre, email y teléfono',
                    accent: AppColors.primary,
                    onTap: () => Get.toNamed(AppRoutes.profile),
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Cambiar contraseña',
                    subtitle: 'Actualizá tu clave de acceso',
                    accent: AppColors.warning,
                    onTap: () => Get.toNamed(AppRoutes.changePassword),
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Seguridad',
                    subtitle: 'Dos factores y sesiones activas',
                    accent: AppColors.info,
                    onTap: () => Get.toNamed(AppRoutes.securitySettings),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Negocio'),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.business_center_outlined,
                    title: 'Información del negocio',
                    subtitle:
                        'Nombre, dirección, teléfono y NIT — aparecen en CADA '
                        'recibo y comanda. Configúralos antes de imprimir.',
                    accent: AppColors.primary,
                    onTap: () => Get.toNamed(AppRoutes.businessInfo),
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.storefront_outlined,
                    title: 'Configuración del negocio',
                    subtitle: 'Impuestos, propinas y horarios',
                    accent: AppColors.secondary,
                    onTap: NavigationService.toBusinessSettings,
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Cuentas de pago',
                    subtitle: 'Nequi, Daviplata, bancos, cajas, datáfonos',
                    accent: AppColors.success,
                    onTap: () =>
                        Get.toNamed(AppRoutes.paymentAccountsSettings),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Operaciones'),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.print_outlined,
                    title: 'Impresoras',
                    subtitle: 'Configurá tickets y dispositivos',
                    accent: const Color(0xFF8E44AD),
                    onTap: NavigationService.toPrinterSettings,
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notificaciones',
                    subtitle: 'Alertas de órdenes, mesas y stock',
                    accent: AppColors.success,
                    onTap: () => Get.toNamed(AppRoutes.notificationSettings),
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Roles del equipo',
                    subtitle: 'Permisos finos por rol (admin/manager)',
                    accent: AppColors.primary,
                    onTap: () => Get.toNamed(AppRoutes.roles),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Suscripción'),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Mi plan',
                    subtitle: 'Detalles del plan y facturación',
                    accent: AppColors.primary,
                    onTap: NavigationService.toSubscription,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: 'Configuración',
      subtitle: 'Ajustes generales de la app',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Tile de configuración. Reusa el lenguaje visual del `_QuickActionTile`
/// del dashboard (avatar tintado + título + subtítulo + chevron).
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
