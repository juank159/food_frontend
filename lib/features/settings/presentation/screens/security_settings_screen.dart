import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Seguridad de la cuenta. Por ahora todo es placeholder visual:
/// switches/botones que muestran un Snackbar al accionarlos. La
/// integración real (2FA, gestión de sesiones) llega más adelante.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;

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
                    title: 'Autenticación',
                    subtitle: 'Capas extra para proteger tu cuenta.',
                    icon: Icons.shield_outlined,
                    accent: AppColors.info,
                    children: [
                      _SecuritySwitch(
                        title: 'Autenticación en dos pasos',
                        subtitle:
                            'Pedí un código adicional al iniciar sesión',
                        icon: Icons.verified_user_outlined,
                        value: _twoFactorEnabled,
                        onChanged: (v) {
                          setState(() => _twoFactorEnabled = v);
                          _showComingSoon('Próximamente disponible',
                              'La autenticación en dos pasos llega pronto.');
                        },
                      ),
                      _SecuritySwitch(
                        title: 'Inicio biométrico',
                        subtitle: 'Usá Face ID o huella para entrar',
                        icon: Icons.fingerprint,
                        value: _biometricEnabled,
                        onChanged: (v) {
                          setState(() => _biometricEnabled = v);
                          _showComingSoon('Próximamente disponible',
                              'El inicio biométrico llega pronto.');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppFormSection(
                    title: 'Sesiones',
                    subtitle:
                        'Cerrá sesiones abiertas en otros dispositivos.',
                    icon: Icons.devices_outlined,
                    accent: AppColors.warning,
                    children: [
                      _SecurityActionTile(
                        title: 'Cerrar todas las otras sesiones',
                        subtitle:
                            'Vas a permanecer logueado solo en este dispositivo',
                        icon: Icons.logout,
                        accent: AppColors.error,
                        onTap: () => _showComingSoon(
                          'Próximamente disponible',
                          'La gestión de sesiones llega pronto.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SecurityActionTile(
                        title: 'Ver dispositivos conectados',
                        subtitle: 'Lista de equipos con sesión activa',
                        icon: Icons.list_alt,
                        accent: AppColors.info,
                        onTap: () => _showComingSoon(
                          'Próximamente disponible',
                          'La lista de dispositivos llega pronto.',
                        ),
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
      title: 'Seguridad',
      subtitle: 'Protección de tu cuenta',
      leading: GestureDetector(
        onTap: () => Get.back(),
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

  void _showComingSoon(String title, String message) {
    AppSnackbar.show(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.info.withValues(alpha: 0.1),
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}

class _SecuritySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SecuritySwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      activeColor: AppColors.primary,
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

class _SecurityActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _SecurityActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
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
