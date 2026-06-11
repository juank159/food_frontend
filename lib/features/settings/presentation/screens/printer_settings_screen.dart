import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../printer_configs/data/models/printer_config_model.dart';
import '../../../printer_configs/data/printer_dispatcher.dart';
import '../../../printer_configs/presentation/controllers/printer_configs_controller.dart';

/// Configuración de impresoras del tenant.
///
/// **Diseño:**
///   - Card "Cocina (Comanda)" — muestra la default actual + cambiar
///   - Card "Caja (Recibo)" — muestra la default actual + cambiar
///   - Lista completa de impresoras configuradas
///   - Dialog "Agregar impresora" soporta 2 tipos: sistema o red TCP
///
/// **Por qué no escanea automáticamente la red:** las apps en sandbox
/// (macOS, iOS) no tienen permiso de network discovery. Más confiable
/// que el admin ingrese la IP manualmente (la consigue en la pantalla
/// física de la impresora — típicamente 30s).
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late final PrinterConfigsController controller;

  @override
  void initState() {
    super.initState();
    // Auto-binding defensivo: la screen se navega directo desde Settings.
    if (!Get.isRegistered<PrinterConfigsController>()) {
      Get.lazyPut(() => PrinterConfigsController());
    }
    controller = Get.find<PrinterConfigsController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppGradientHeader(
              title: 'Impresoras',
              subtitle: 'Configurá las impresoras para comanda y recibo',
            ),
            Expanded(
              child: Obx(() {
                if (controller.loading.value && controller.printers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.error.value != null &&
                    controller.printers.isEmpty) {
                  return _errorView();
                }
                return RefreshIndicator(
                  onRefresh: controller.fetch,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [
                      _PurposeCard(
                        title: 'Cocina · Comanda de preparación',
                        subtitle:
                            'Imprime el ticket que va a cocina cuando se '
                            'aprueba/confirma una orden. Sin precios.',
                        icon: Icons.restaurant_menu,
                        accent: const Color(0xFF8E44AD),
                        printer: controller.defaultKitchen,
                        purpose: PrinterPurpose.kitchen,
                        onTest: _testPrint,
                      ),
                      const SizedBox(height: 12),
                      _PurposeCard(
                        title: 'Caja · Recibo del cliente',
                        subtitle:
                            'Imprime la factura/recibo al completar el cobro. '
                            'Con precios, totales y método de pago.',
                        icon: Icons.receipt_long,
                        accent: AppColors.primary,
                        printer: controller.defaultReceipt,
                        purpose: PrinterPurpose.receipt,
                        onTest: _testPrint,
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'IMPRESORAS CONFIGURADAS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (controller.printers.isEmpty)
                        _emptyPrintersHint()
                      else
                        ...controller.printers.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PrinterRow(
                              printer: p,
                              onAction: _handleRowAction,
                              onTap: () => _openEditDialog(p),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppPrimaryActionBar(
        label: 'Agregar impresora',
        icon: Icons.add,
        onPressed: _openAddDialog,
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(controller.error.value!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyPrintersHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aún no tenés impresoras configuradas. Tap "Agregar impresora" '
              'para conectar la primera. Si no estás seguro, elegí '
              '"Impresora del sistema" — usa el diálogo de impresión normal '
              'de tu computadora.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRowAction(String value, PrinterConfigModel p) {
    switch (value) {
      case 'default':
        controller.setAsDefault(p.id);
        break;
      case 'auto-on':
        controller.edit(p.id, autoPrint: true);
        break;
      case 'auto-off':
        controller.edit(p.id, autoPrint: false);
        break;
      case 'edit':
        _openEditDialog(p);
        break;
      case 'remove':
        _confirmRemove(p);
        break;
    }
  }

  Future<void> _confirmRemove(PrinterConfigModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar impresora'),
        content: Text(
          '¿Eliminar "${p.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.remove(p);
  }

  Future<void> _openAddDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _PrinterFormDialog(controller: controller),
    );
  }

  Future<void> _openEditDialog(PrinterConfigModel p) async {
    await showDialog(
      context: context,
      builder: (_) => _PrinterFormDialog(controller: controller, existing: p),
    );
  }

  Future<void> _testPrint(PrinterConfigModel p) async {
    if (p.connectionType == PrinterConnectionType.network) {
      AppSnackbar.show('Probando…', 'Conectando con ${p.host}:${p.port}');
      final result = await PrinterDispatcher.diagnoseNetworkConnection(
        host: p.host ?? '',
        port: p.port ?? 9100,
      );
      if (result.ok) {
        AppSnackbar.show(
          '✓ Conexión OK',
          '${p.host}:${p.port} responde. La impresora está lista para '
              'recibir tickets.',
        );
      } else {
        if (mounted) _showDiagnosisDialog(p, result);
      }
    } else {
      AppSnackbar.show(
        'OK',
        'La impresora del sistema se prueba al imprimir un ticket real '
            'desde un pedido.',
      );
    }
  }

  /// Dialog con diagnóstico accionable cuando la impresora de red no
  /// responde — muestra causa probable y botón para editar la config.
  /// Reemplaza al snackbar genérico "inalcanzable" que no ayudaba.
  void _showDiagnosisDialog(
    PrinterConfigModel p,
    ConnectionDiagnosis result,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.cable_outlined, color: AppColors.error, size: 36),
        title: Text(
          'No se puede alcanzar ${p.name}',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${result.host}:${result.port}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.hint ?? 'Verificá conectividad.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: AppColors.info, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tip: para confirmar la IP de tu impresora, '
                      'presioná el botón "Feed" mientras la prendés — '
                      'sale un ticket de prueba con su IP actual.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.info,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openEditDialog(p);
            },
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Editar impresora'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Card del propósito (Cocina o Caja)
// =====================================================================
class _PurposeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final PrinterConfigModel? printer;
  final PrinterPurpose purpose;
  final Future<void> Function(PrinterConfigModel) onTest;

  const _PurposeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.printer,
    required this.purpose,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrinter = printer != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1.5,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasPrinter
                    ? accent.withValues(alpha: 0.05)
                    : Colors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasPrinter
                      ? accent.withValues(alpha: 0.3)
                      : Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: hasPrinter
                  ? Row(
                      children: [
                        Icon(Icons.check_circle, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                printer!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                printer!.connectionSummary,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 11,
                                ),
                              ),
                              if (printer!.autoPrint)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.flash_on,
                                        size: 12,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Imprime automáticamente',
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => onTest(printer!),
                          child: const Text('Probar'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.amber.shade800,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin impresora configurada. Agregá una para que '
                            '${purpose == PrinterPurpose.kitchen ? "las comandas" : "los recibos"} '
                            'se impriman automáticamente.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Row de impresora en la lista
// =====================================================================
class _PrinterRow extends StatelessWidget {
  final PrinterConfigModel printer;
  final void Function(String value, PrinterConfigModel p) onAction;
  final VoidCallback onTap;

  const _PrinterRow({
    required this.printer,
    required this.onAction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                printer.connectionType == PrinterConnectionType.network
                    ? Icons.wifi
                    : Icons.print,
                color: printer.isActive ? AppColors.primary : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            printer.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: printer.isActive
                                  ? AppColors.textPrimary
                                  : Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (printer.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentDark,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${printer.purpose.displayName} · ${printer.connectionSummary}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                onSelected: (v) => onAction(v, printer),
                itemBuilder: (_) => [
                  if (!printer.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.star_outline),
                        title: Text('Marcar como default'),
                      ),
                    ),
                  PopupMenuItem(
                    value: printer.autoPrint ? 'auto-off' : 'auto-on',
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        printer.autoPrint ? Icons.flash_off : Icons.flash_on,
                      ),
                      title: Text(
                        printer.autoPrint
                            ? 'Desactivar auto-print'
                            : 'Activar auto-print',
                      ),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text(
                        'Eliminar',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Dialog crear / editar
// =====================================================================
class _PrinterFormDialog extends StatefulWidget {
  final PrinterConfigsController controller;
  final PrinterConfigModel? existing;

  const _PrinterFormDialog({required this.controller, this.existing});

  @override
  State<_PrinterFormDialog> createState() => _PrinterFormDialogState();
}

class _PrinterFormDialogState extends State<_PrinterFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _notesCtrl;
  late PrinterPurpose _purpose;
  late PrinterConnectionType _connType;
  late int _paperWidth;
  late bool _isDefault;
  late bool _autoPrint;
  bool _saving = false;
  bool _testing = false;
  bool? _testOk;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _hostCtrl = TextEditingController(text: e?.host ?? '');
    _portCtrl = TextEditingController(text: (e?.port ?? 9100).toString());
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _purpose = e?.purpose ?? PrinterPurpose.both;
    _connType = e?.connectionType ?? PrinterConnectionType.system;
    _paperWidth = e?.paperWidth ?? 80;
    _isDefault = e?.isDefault ?? true;
    _autoPrint = e?.autoPrint ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_connType == PrinterConnectionType.network &&
        _hostCtrl.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar impresora' : 'Agregar impresora',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Nombre'),
                      TextField(
                        controller: _nameCtrl,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          hintText: 'Ej: "Térmica cocina Epson"',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      _label('Propósito'),
                      _purposeSelector(),
                      const SizedBox(height: 14),
                      _label('Tipo de conexión'),
                      _connectionSelector(),
                      const SizedBox(height: 14),
                      if (_connType == PrinterConnectionType.network) ...[
                        _label('IP de la impresora'),
                        TextField(
                          controller: _hostCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Ej: 192.168.1.50',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() => _testOk = null),
                        ),
                        const SizedBox(height: 10),
                        _label('Puerto'),
                        TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '9100 (estándar térmicas POS)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _testOk == true
                                      ? Icons.check_circle
                                      : _testOk == false
                                          ? Icons.error_outline
                                          : Icons.wifi_tethering,
                                  color: _testOk == true
                                      ? AppColors.accent
                                      : _testOk == false
                                          ? AppColors.error
                                          : null,
                                  size: 18,
                                ),
                          label: Text(
                            _testing
                                ? 'Probando…'
                                : _testOk == true
                                    ? 'Conexión OK'
                                    : _testOk == false
                                        ? 'Sin conexión'
                                        : 'Probar conexión',
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _label('Ancho de papel'),
                      Row(
                        children: [
                          _paperChip(80),
                          const SizedBox(width: 8),
                          _paperChip(58),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Default para este propósito',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Se usa por default cuando se imprime una comanda '
                          'o un recibo',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Imprimir automáticamente',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _connType == PrinterConnectionType.network
                              ? 'Las comandas/recibos se imprimen solos sin '
                                  'diálogo del SO'
                              : 'Las impresoras del sistema siempre piden '
                                  'confirmación. Para auto-print real usá red.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: _autoPrint,
                        onChanged: (v) => setState(() => _autoPrint = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || !_canSave ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando…' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );

  Widget _purposeSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: PrinterPurpose.values.map((p) {
        final selected = _purpose == p;
        return InkWell(
          onTap: () => setState(() => _purpose = p),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: selected ? 1 : 0.3),
              ),
            ),
            child: Text(
              p.displayName,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _connectionSelector() {
    return Column(
      children: PrinterConnectionType.values.map((c) {
        final selected = _connType == c;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () => setState(() {
              _connType = c;
              _testOk = null;
            }),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    c == PrinterConnectionType.network
                        ? Icons.wifi
                        : Icons.print,
                    color: selected ? AppColors.primary : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c == PrinterConnectionType.network
                              ? 'Setup pro: ingresá la IP de la impresora '
                                  '(puerto 9100). Imprime sin diálogo. '
                                  'Ideal para auto-print.'
                              : 'Setup fácil: usa el diálogo de impresión '
                                  'estándar del SO. Pide confirmación cada vez.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.radio_button_checked,
                      color: AppColors.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _paperChip(int width) {
    final selected = _paperWidth == width;
    return InkWell(
      onTap: () => setState(() => _paperWidth = width),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: selected ? 1 : 0.3),
          ),
        ),
        child: Text(
          '${width}mm',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testOk = null;
    });
    try {
      final ok = await PrinterDispatcher.testNetworkConnection(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? 9100,
      );
      setState(() => _testOk = ok);
    } catch (_) {
      setState(() => _testOk = false);
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.controller.edit(
          widget.existing!.id,
          name: _nameCtrl.text.trim(),
          purpose: _purpose,
          connectionType: _connType,
          host: _connType == PrinterConnectionType.network
              ? _hostCtrl.text.trim()
              : null,
          port: _connType == PrinterConnectionType.network
              ? int.tryParse(_portCtrl.text.trim()) ?? 9100
              : null,
          paperWidth: _paperWidth,
          isDefault: _isDefault,
          autoPrint: _autoPrint,
          notes: _notesCtrl.text.trim(),
        );
      } else {
        await widget.controller.create(
          name: _nameCtrl.text.trim(),
          purpose: _purpose,
          connectionType: _connType,
          host: _connType == PrinterConnectionType.network
              ? _hostCtrl.text.trim()
              : null,
          port: _connType == PrinterConnectionType.network
              ? int.tryParse(_portCtrl.text.trim()) ?? 9100
              : null,
          paperWidth: _paperWidth,
          isDefault: _isDefault,
          autoPrint: _autoPrint,
          notes: _notesCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // snackbar viene del controller
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
