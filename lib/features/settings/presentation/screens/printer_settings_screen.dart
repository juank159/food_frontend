import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Configuración de impresoras y tickets. Por ahora vacío de
/// contenido funcional — el descubrimiento real de impresoras y la
/// persistencia del header/footer del ticket son trabajo futuro.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  bool _autoPrint = false;

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

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
                  _buildPrintersCard(),
                  const SizedBox(height: 14),
                  _buildTicketSection(),
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
      title: 'Impresoras',
      subtitle: 'Configurá tickets y dispositivos',
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

  Widget _buildPrintersCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.print_outlined,
                    color: Color(0xFF8E44AD),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impresoras conectadas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Detectá impresoras en la red local.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AppEmptyState(
            icon: Icons.print_disabled_outlined,
            title: 'No hay impresoras configuradas',
            message:
                'Aún no agregaste ninguna impresora. Buscá una en tu red para empezar.',
            actionLabel: 'Buscar impresoras',
            actionIcon: Icons.search,
            accent: const Color(0xFF8E44AD),
            onAction: () => _showComingSoon(
              'Próximamente disponible',
              'La detección de impresoras llega en una próxima versión.',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTicketSection() {
    return AppFormSection(
      title: 'Configuración de tickets',
      subtitle: 'Texto que aparece en cada ticket impreso.',
      icon: Icons.receipt_long_outlined,
      accent: AppColors.primary,
      children: [
        TextFormField(
          controller: _headerController,
          decoration: appInputDecoration(
            label: 'Encabezado',
            hint: 'Ej: ¡Gracias por tu visita!',
            prefixIcon: Icons.title,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _footerController,
          decoration: appInputDecoration(
            label: 'Pie de página',
            hint: 'Ej: WiFi: invitados / Pass: 1234',
            prefixIcon: Icons.short_text,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Imprimir automáticamente',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Imprime el ticket apenas se cierra la orden',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (_autoPrint ? AppColors.primary : AppColors.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_mode,
              color:
                  _autoPrint ? AppColors.primary : AppColors.textSecondary,
              size: 18,
            ),
          ),
          value: _autoPrint,
          onChanged: (v) => setState(() => _autoPrint = v),
        ),
      ],
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
