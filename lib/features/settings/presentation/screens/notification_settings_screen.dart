import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';

/// Configuración de notificaciones. Por ahora los switches son locales
/// (no persisten) — la persistencia es trabajo futuro.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _newOrders = true;
  bool _tablesReady = true;
  bool _lowStock = true;
  bool _pushEnabled = true;
  bool _emailEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppFormSection(
                    title: 'Notificaciones',
                    subtitle:
                        'Elegí qué eventos disparan alertas en este dispositivo.',
                    icon: Icons.notifications_outlined,
                    accent: AppColors.success,
                    children: [
                      _SwitchTile(
                        title: 'Nuevas órdenes',
                        subtitle: 'Sonido y banner al recibir un pedido',
                        icon: Icons.receipt_long_outlined,
                        value: _newOrders,
                        onChanged: (v) => setState(() => _newOrders = v),
                      ),
                      _SwitchTile(
                        title: 'Mesas listas',
                        subtitle: 'Avisar cuando una mesa quedó libre',
                        icon: Icons.chair_outlined,
                        value: _tablesReady,
                        onChanged: (v) => setState(() => _tablesReady = v),
                      ),
                      _SwitchTile(
                        title: 'Stock bajo',
                        subtitle: 'Alerta cuando un producto cae al mínimo',
                        icon: Icons.inventory_2_outlined,
                        value: _lowStock,
                        onChanged: (v) => setState(() => _lowStock = v),
                      ),
                      _SwitchTile(
                        title: 'Push notifications',
                        subtitle: 'Notificaciones del sistema operativo',
                        icon: Icons.notifications_active_outlined,
                        value: _pushEnabled,
                        onChanged: (v) => setState(() => _pushEnabled = v),
                      ),
                      _SwitchTile(
                        title: 'Email notifications',
                        subtitle: 'Resumen diario por correo electrónico',
                        icon: Icons.mail_outline,
                        value: _emailEnabled,
                        onChanged: (v) => setState(() => _emailEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppGradientHeader(
      title: 'Notificaciones',
      subtitle: 'Configurá cuándo querés que te avisemos',
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
}

/// Switch tile con icono tintado a la izquierda. Misma jerarquía
/// visual que el resto de los formularios.
class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      activeThumbColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (value ? AppColors.primary : AppColors.textSecondary)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: value ? AppColors.primary : AppColors.textSecondary,
          size: 18,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
