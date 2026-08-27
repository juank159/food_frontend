import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Configuración de la conciliación automática de pagos Bre-B/Nequi.
///
/// Muestra la dirección de correo exclusiva del negocio (a la que hay que
/// reenviar los avisos de "Venta exitosa" de Nequi) y guarda la llave
/// Bre-B en `settings.breb.llave` — la misma que se le muestra al cliente
/// al cobrar.
class BrebSettingsScreen extends StatefulWidget {
  const BrebSettingsScreen({super.key});

  @override
  State<BrebSettingsScreen> createState() => _BrebSettingsScreenState();
}

class _BrebSettingsScreenState extends State<BrebSettingsScreen> {
  late final Dio _dio;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _inboundEmail = '';
  final _llaveCtrl = TextEditingController();
  Map<String, dynamic> _existingSettings = {};

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _llaveCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/tenants/me'),
        _dio.get('/payments/breb/inbound-address'),
      ]);

      final tenant = ApiResponseUtils.object(results[0]);
      final settings =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      _existingSettings = Map<String, dynamic>.from(settings);
      final breb = (settings['breb'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      _llaveCtrl.text = (breb['llave'] as String?) ?? '';

      final address = ApiResponseUtils.object(results[1]);
      _inboundEmail = (address['email'] as String?) ?? '';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newSettings = Map<String, dynamic>.from(_existingSettings);
      newSettings['breb'] = {
        'llave': _llaveCtrl.text.trim().isNotEmpty ? _llaveCtrl.text.trim() : null,
      };
      await _dio.patch('/tenants/me', data: {'settings': newSettings});
      _existingSettings = newSettings;
      AppSnackbar.show('Guardado', 'La llave Bre-B quedó actualizada.');
    } catch (e) {
      AppSnackbar.show('Error al guardar', ApiResponseUtils.errorMessage(e) ?? e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyEmail() {
    Clipboard.setData(ClipboardData(text: _inboundEmail));
    AppSnackbar.show('Copiado', 'Dirección copiada al portapapeles');
  }

  Future<void> _showRecentEmails() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecentEmailsSheet(dio: _dio),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bre-B / Nequi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _buildForm(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _infoBanner(),
        const SizedBox(height: 20),

        _sectionTitle('1. Reenviá los avisos de Nequi acá'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'En tu correo (Gmail/Outlook) creá una regla que reenvíe automáticamente '
                'los correos de nequinotificaciones@nequi.com.co a esta dirección:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _inboundEmail.isEmpty ? null : _copyEmail,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _inboundEmail.isEmpty ? 'Cargando…' : _inboundEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_inboundEmail.isNotEmpty)
                        Icon(Icons.copy, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cada correo aprobado se concilia solo con la cuenta que esté esperando ese monto.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showRecentEmails,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Ver correos recibidos'),
              ),
              const SizedBox(height: 6),
              Text(
                'Útil para confirmar reenvíos de Gmail/Outlook (te pide confirmar la dirección '
                'la primera vez) o para revisar por qué un pago no se concilió solo.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('2. Llave Bre-B del negocio'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Es la que se le muestra al cliente para que transfiera al cobrar.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _llaveCtrl,
                decoration: InputDecoration(
                  labelText: 'Llave Bre-B',
                  hintText: 'Ej: 3001234567 o tu@llave',
                  prefixIcon: const Icon(Icons.bolt, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
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
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Cuando cobrás con Bre-B, el sistema detecta la transferencia solo — '
              'sin comisiones y sin dar acceso a tu correo, solo el reenvío que vos configurás.',
              style: TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Lista los últimos correos que llegaron a la dirección Bre-B del tenant
/// y no se conciliaron solos — incluye correos de confirmación de reenvío
/// (Gmail/Outlook) y avisos de Nequi que fallaron el match. Le permite a
/// cada negocio auto-gestionar su onboarding sin pedir ayuda a soporte.
class _RecentEmailsSheet extends StatefulWidget {
  final Dio dio;
  const _RecentEmailsSheet({required this.dio});

  @override
  State<_RecentEmailsSheet> createState() => _RecentEmailsSheetState();
}

class _RecentEmailsSheetState extends State<_RecentEmailsSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _emails = [];

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
      final res = await widget.dio.get('/payments/breb/recent-emails');
      final list = ApiResponseUtils.list(res);
      _emails = list.cast<Map<String, dynamic>>();
    } catch (e) {
      _error = ApiResponseUtils.errorMessage(e) ?? e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static final _urlRegex = RegExp(r'https?://[^\s<>"\)]+');

  List<String> _extractUrls(String text) {
    return _urlRegex
        .allMatches(text)
        .map((m) => m.group(0)!.replaceAll(RegExp(r'[.,;]+$'), ''))
        .toSet()
        .toList();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      AppSnackbar.show('No se pudo abrir', 'Copiá el link manualmente.');
    }
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'unknown_slug':
        return 'Dirección desconocida';
      case 'not_approved':
        return 'No es de Nequi (ej. confirmación de reenvío)';
      case 'not_a_sale':
        return 'Es de Nequi, pero no es un aviso de venta (recarga, seguridad, etc.)';
      case 'parse_error':
        return 'No se pudo leer el formato';
      case 'status_rejected':
        return 'Venta con estado rechazado/no aprobado';
      case 'no_pending_match':
        return 'No había ningún cobro esperando ese monto';
      case 'multiple_matches':
        return 'Ambiguo — varios cobros con el mismo monto';
      default:
        return reason;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Correos recibidos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loading ? null : _load,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center),
                            ),
                          )
                        : _emails.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Todavía no llegó ningún correo a tu dirección Bre-B.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.all(16),
                                itemCount: _emails.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final e = _emails[i];
                                  final reason = (e['reason'] as String?) ?? '';
                                  final body = (e['raw_body'] as String?) ?? '';
                                  final createdAt = (e['created_at'] as String?) ?? '';
                                  final links = _extractUrls(body);
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _reasonLabel(reason),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (createdAt.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            createdAt,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (body.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          SelectableText(
                                            body.length > 500 ? '${body.substring(0, 500)}…' : body,
                                            style: const TextStyle(fontSize: 12, height: 1.4),
                                          ),
                                        ],
                                        if (links.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          ...links.map(
                                            (url) => Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: FilledButton.icon(
                                                  onPressed: () => _openLink(url),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    minimumSize: const Size(0, 40),
                                                  ),
                                                  icon: const Icon(Icons.open_in_new, size: 16),
                                                  label: const Text('Abrir enlace de confirmación'),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
              SizedBox(height: mq.padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
