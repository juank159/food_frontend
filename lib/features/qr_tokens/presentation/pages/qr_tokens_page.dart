import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../thermal_print/data/thermal_print_service.dart';
import '../../data/models/qr_token_model.dart';
import '../controllers/qr_tokens_controller.dart';

/// Pantalla admin para gestionar los QRs físicos del restaurante.
///
/// Layout: lista de cards (1 por QR) + FAB para crear + filter chip
/// "ver desactivados". Cada card tiene: type, label, code, contador
/// de escaneos, botones imprimir 80mm / 58mm / desactivar / editar.
class QrTokensPage extends GetView<QrTokensController> {
  const QrTokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Códigos QR'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Obx(() => IconButton(
                tooltip: controller.showInactive.value
                    ? 'Ocultar inactivos'
                    : 'Ver inactivos',
                icon: Icon(controller.showInactive.value
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    controller.showInactive.toggle(),
              )),
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
            onSelected: (v) => _handleAction(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'bulk',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.dynamic_feed),
                  title: Text('Crear varios QRs'),
                  subtitle: Text('Onboarding rápido'),
                ),
              ),
              PopupMenuItem(
                value: 'sheet-4',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.grid_view),
                  title: Text('Imprimir todos en A4'),
                  subtitle: Text('4 QRs por hoja'),
                ),
              ),
              PopupMenuItem(
                value: 'sheet-8',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.grid_on),
                  title: Text('Imprimir todos en A4'),
                  subtitle: Text('8 QRs por hoja (compactos)'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh),
                  title: Text('Refrescar'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openCreateDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.loading.value && controller.tokens.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error.value != null && controller.tokens.isEmpty) {
            return _ErrorState(
              message: controller.error.value!,
              onRetry: controller.fetch,
            );
          }
          final list = controller.visible;
          if (list.isEmpty) {
            return _EmptyState(onCreate: () => _openCreateDialog(context));
          }
          return RefreshIndicator(
            onRefresh: controller.fetch,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _QrCard(token: list[i]),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    await AppDialog.show(
      context: context,
      const _CreateOrEditQrDialog(),
    );
  }

  Future<void> _handleAction(BuildContext context, String value) async {
    switch (value) {
      case 'bulk':
        await AppDialog.show(
          context: context,
          const _BulkCreateQrDialog(),
        );
        break;
      case 'sheet-4':
      case 'sheet-8':
        final perPage = value == 'sheet-4' ? 4 : 8;
        final codes = controller.visible
            .where((t) => t.isActive)
            .map((t) => t.code)
            .toList();
        if (codes.isEmpty) return;
        await controller.printSheet(codes: codes, perPage: perPage);
        break;
      case 'refresh':
        await controller.fetch();
        break;
    }
  }
}

// =====================================================================
// Card de cada QR
// =====================================================================
class _QrCard extends StatelessWidget {
  final QrTokenModel token;
  const _QrCard({required this.token});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QrTokensController>();

    return Obx(() {
      final isPrinting = controller.printingIds.contains(token.id);
      return Material(
        color: AppColors.surface,
        elevation: 1.5,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _TypeChip(type: token.type),
                  const SizedBox(width: 8),
                  if (!token.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'DESACTIVADO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${token.scanCount} escaneos',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                token.displayLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    token.code,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (token.tableElementId != null ||
                  token.zoneLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  token.tableElementId != null
                      ? 'Mesa: ${token.tableElementId}'
                      : 'Zona: ${token.zoneLabel}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Botones de acción.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (token.isActive) ...[
                    _ActionButton(
                      icon: Icons.print,
                      label: '80mm',
                      onPressed: isPrinting
                          ? null
                          : () => controller.printThermal(
                                token,
                                width: ThermalPaperWidth.mm80,
                              ),
                    ),
                    _ActionButton(
                      icon: Icons.print_outlined,
                      label: '58mm',
                      onPressed: isPrinting
                          ? null
                          : () => controller.printThermal(
                                token,
                                width: ThermalPaperWidth.mm58,
                              ),
                    ),
                    _ActionButton(
                      icon: Icons.edit,
                      label: 'Editar',
                      onPressed: () => _openEdit(context, token),
                    ),
                    _ActionButton(
                      icon: Icons.power_settings_new,
                      label: 'Desactivar',
                      color: AppColors.error,
                      onPressed: () =>
                          _confirmDeactivate(context, token, controller),
                    ),
                  ] else
                    _ActionButton(
                      icon: Icons.refresh,
                      label: 'Reactivar',
                      color: AppColors.accent,
                      onPressed: () => controller.reactivate(token),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _openEdit(BuildContext context, QrTokenModel token) async {
    await AppDialog.show(
      context: context,
      _CreateOrEditQrDialog(existing: token),
    );
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    QrTokenModel token,
    QrTokensController controller,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar QR'),
        content: Text(
          'El sticker físico de "${token.displayLabel}" dejará de funcionar. '
          'Podés reactivarlo después sin reimprimir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await controller.deactivate(token);
    }
  }
}

class _TypeChip extends StatelessWidget {
  final QrTokenType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case QrTokenType.table:
        icon = Icons.table_restaurant;
        color = AppColors.primary;
        break;
      case QrTokenType.zone:
        icon = Icons.location_on;
        color = Colors.indigo;
        break;
      case QrTokenType.pickup:
        icon = Icons.shopping_bag_outlined;
        color = Colors.deepOrange;
        break;
      case QrTokenType.generic:
        icon = Icons.qr_code_2;
        color = Colors.blueGrey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            type.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: c),
      label: Text(label, style: TextStyle(color: c, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// =====================================================================
// Dialog crear/editar QR
// =====================================================================
class _CreateOrEditQrDialog extends StatefulWidget {
  final QrTokenModel? existing;
  const _CreateOrEditQrDialog({this.existing});

  @override
  State<_CreateOrEditQrDialog> createState() => _CreateOrEditQrDialogState();
}

class _CreateOrEditQrDialogState extends State<_CreateOrEditQrDialog> {
  late QrTokenType _type;
  late TextEditingController _labelCtrl;
  late TextEditingController _tableIdCtrl;
  late TextEditingController _zoneCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? QrTokenType.table;
    _labelCtrl = TextEditingController(text: e?.displayLabel ?? '');
    _tableIdCtrl = TextEditingController(text: e?.tableElementId ?? '');
    _zoneCtrl = TextEditingController(text: e?.zoneLabel ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _tableIdCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar QR' : 'Nuevo QR'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type (solo en creación — el type no se puede cambiar
            // después porque define qué campos extra son obligatorios).
            if (!_isEditing) ...[
              const Text('Tipo de QR',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<QrTokenType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: QrTokenType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Etiqueta visible al cliente',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _labelCtrl,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: 'Ej: Mesa 5, Terraza, Pickup en barra',
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            if (_type == QrTokenType.table) ...[
              const Text('ID de mesa (del floor plan)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _tableIdCtrl,
                decoration: const InputDecoration(
                  hintText: 'table_element_id de la mesa física',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            if (_type == QrTokenType.zone) ...[
              const Text('Nombre de zona',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _zoneCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej: terraza, salon_vip',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;

    setState(() => _saving = true);
    try {
      final controller = Get.find<QrTokensController>();
      if (_isEditing) {
        await controller.editToken(
          widget.existing!.id,
          displayLabel: label,
          tableElementId: _type == QrTokenType.table
              ? _tableIdCtrl.text.trim()
              : null,
          zoneLabel:
              _type == QrTokenType.zone ? _zoneCtrl.text.trim() : null,
        );
      } else {
        await controller.create(
          type: _type,
          displayLabel: label,
          tableElementId: _type == QrTokenType.table
              ? _tableIdCtrl.text.trim()
              : null,
          zoneLabel:
              _type == QrTokenType.zone ? _zoneCtrl.text.trim() : null,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // El snackbar ya lo lanzó el controller.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =====================================================================
// Estados vacíos
// =====================================================================
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code_2,
                size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin códigos QR',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Creá un QR por mesa o zona para empezar.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Crear primer QR'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Dialog Bulk-Create: "Mesa 1" ... "Mesa N" en una sola request.
// =====================================================================
class _BulkCreateQrDialog extends StatefulWidget {
  const _BulkCreateQrDialog();

  @override
  State<_BulkCreateQrDialog> createState() => _BulkCreateQrDialogState();
}

class _BulkCreateQrDialogState extends State<_BulkCreateQrDialog> {
  QrTokenType _type = QrTokenType.table;
  final _prefixCtrl = TextEditingController(text: 'Mesa');
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController(text: '10');
  final _zoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = int.tryParse(_fromCtrl.text) ?? 0;
    final to = int.tryParse(_toCtrl.text) ?? 0;
    final count = (to >= from && from >= 1) ? to - from + 1 : 0;

    return AlertDialog(
      title: const Text('Crear varios QRs'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Genera múltiples QRs en secuencia (ej: "Mesa 1" a "Mesa 20"). '
              'Ideal para configurar un restaurante por primera vez.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            const Text('Tipo',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<QrTokenType>(
              initialValue: _type,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: QrTokenType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            const Text('Prefijo del label',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _prefixCtrl,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: 'Ej: "Mesa", "Mesa Terraza"',
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Desde',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fromCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hasta',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _toCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_type == QrTokenType.zone) ...[
              const SizedBox(height: 12),
              const Text('Nombre de zona (común a todos)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _zoneCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej: terraza',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: count > 0
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    count > 0 ? Icons.check_circle : Icons.error_outline,
                    color: count > 0 ? AppColors.accent : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      count > 0
                          ? 'Se crearán $count QRs: "${_prefixCtrl.text} $from" → "${_prefixCtrl.text} $to"'
                          : 'Verificá los valores de "desde" y "hasta"',
                      style: TextStyle(
                        color: count > 0
                            ? AppColors.accentDark
                            : Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving || count == 0 || _prefixCtrl.text.trim().isEmpty
              ? null
              : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Crear $count QRs'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final from = int.tryParse(_fromCtrl.text);
    final to = int.tryParse(_toCtrl.text);
    if (from == null || to == null || to < from || from < 1) return;

    final count = to - from + 1;
    if (count > 200) {
      Get.find<QrTokensController>(); // ignore unused
      return;
    }

    setState(() => _saving = true);
    try {
      final controller = Get.find<QrTokensController>();
      await controller.bulkCreate(
        type: _type,
        labelPrefix: _prefixCtrl.text.trim(),
        from: from,
        to: to,
        zoneLabel: _type == QrTokenType.zone ? _zoneCtrl.text.trim() : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // snackbar viene del controller
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
