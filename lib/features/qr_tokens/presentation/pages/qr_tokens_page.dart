import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../thermal_print/data/thermal_print_service.dart';
import '../../data/models/available_table.dart';
import '../../data/models/qr_token_model.dart';
import '../controllers/qr_tokens_controller.dart';
import 'qr_preview_page.dart';

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() => controller.selectionMode.value
            ? _selectionAppBar(context)
            : _normalAppBar(context)),
      ),
      floatingActionButton: Obx(() => controller.selectionMode.value
          ? const SizedBox.shrink()
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _openCreateDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            )),
      bottomNavigationBar: Obx(() => controller.selectionMode.value
          ? _printSelectedBar(context)
          : const SizedBox.shrink()),
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

  // ─────────────────────────── AppBars ───────────────────────────

  AppBar _normalAppBar(BuildContext context) {
    return AppBar(
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
              onPressed: () => controller.showInactive.toggle(),
            )),
        PopupMenuButton<String>(
          tooltip: 'Más acciones',
          onSelected: (v) => _handleAction(context, v),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'from-tables',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.table_restaurant),
                title: Text('Generar QRs desde planos'),
                subtitle: Text('Selecciona mesas reales del tenant'),
              ),
            ),
            PopupMenuItem(
              value: 'bulk',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.dynamic_feed),
                title: Text('Crear QRs por rango'),
                subtitle: Text('Ej: "Mesa 1 a 30" (sin asociar a plano)'),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'select',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.checklist),
                title: Text('Elegir cuáles imprimir'),
                subtitle: Text('Seleccionás los QR que quieras'),
              ),
            ),
            PopupMenuItem(
              value: 'sheet-6',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.grid_view),
                title: Text('Imprimir todos los QRs'),
                subtitle: Text('Hoja carta · 6 por hoja (para laminar)'),
              ),
            ),
            PopupMenuItem(
              value: 'sheet-4',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.crop_square),
                title: Text('Imprimir todos los QRs'),
                subtitle: Text('Hoja carta · 4 por hoja (grandes)'),
              ),
            ),
            PopupMenuItem(
              value: 'sheet-8',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.grid_on),
                title: Text('Imprimir todos los QRs'),
                subtitle: Text('Hoja carta · 8 por hoja (compactos)'),
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
    );
  }

  AppBar _selectionAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancelar selección',
        onPressed: controller.exitSelection,
      ),
      title: Obx(() => Text('${controller.selectedCount} seleccionados')),
      actions: [
        Obx(() => TextButton.icon(
              onPressed: controller.toggleSelectAllVisible,
              icon: Icon(
                controller.allVisibleSelected
                    ? Icons.deselect
                    : Icons.select_all,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                controller.allVisibleSelected ? 'Ninguno' : 'Todos',
                style: const TextStyle(color: Colors.white),
              ),
            )),
      ],
    );
  }

  /// Barra inferior en modo selección: imprimir los QR elegidos.
  Widget _printSelectedBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Obx(() {
          final n = controller.selectedCount;
          return FilledButton.icon(
            onPressed: n == 0 ? null : () => _printSelected(context),
            icon: const Icon(Icons.print),
            label: Text(n == 0 ? 'Elegí al menos un QR' : 'Imprimir $n QR(s)'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
            ),
          );
        }),
      ),
    );
  }

  /// Abre la vista previa con SOLO los QR seleccionados (6 por hoja carta;
  /// el layout se puede cambiar en la preview).
  Future<void> _printSelected(BuildContext context) async {
    final codes = controller.selectedCodes;
    if (codes.isEmpty) return;
    final count = codes.length;
    controller.exitSelection();
    await Get.toNamed(
      '/qr-tokens/preview',
      arguments: QrPreviewArgs(
        codes: codes,
        title: 'Imprimir $count QRs',
        subtitle: '6 por hoja carta',
        initialPerPage: 6,
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
      case 'from-tables':
        await AppDialog.show(
          context: context,
          const _BulkFromTablesDialog(),
        );
        break;
      case 'bulk':
        await AppDialog.show(
          context: context,
          const _BulkCreateQrDialog(),
        );
        break;
      case 'select':
        controller.enterSelection();
        break;
      case 'sheet-6':
      case 'sheet-4':
      case 'sheet-8':
        final perPage = value == 'sheet-6'
            ? 6
            : value == 'sheet-4'
                ? 4
                : 8;
        final codes = controller.visible
            .where((t) => t.isActive)
            .map((t) => t.code)
            .toList();
        if (codes.isEmpty) return;
        // Abrimos preview en vez de imprimir directo — el usuario
        // confirma desde la pantalla de vista previa.
        await Get.toNamed(
          '/qr-tokens/preview',
          arguments: QrPreviewArgs(
            codes: codes,
            title: 'Imprimir ${codes.length} QRs',
            subtitle: '$perPage por hoja carta',
            initialPerPage: perPage,
          ),
        );
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
      final selectionMode = controller.selectionMode.value;
      final selected = controller.isSelected(token.id);
      return GestureDetector(
        // Mantener presionado entra al modo selección; en modo selección,
        // un tap marca/desmarca el QR. Fuera de selección, los botones
        // internos del card funcionan normal.
        onLongPress: () => controller.enterSelection(token.id),
        onTap: selectionMode
            ? () => controller.toggleSelected(token.id)
            : null,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: selected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: IgnorePointer(
                // En modo selección, los botones internos no reciben taps
                // (el tap del card maneja la selección).
                ignoring: selectionMode,
                child: Material(
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
              // Acciones del card — alineadas a la izquierda con tamaño
              // proporcional (no se estiran a todo el ancho del card,
              // que en desktop quedaba enorme).
              if (token.isActive)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Botón primario: vista previa + impresión en hoja
                    // normal (A4). Este es el flujo principal.
                    FilledButton.icon(
                      onPressed: () =>
                          _openPreview(context, [token.code], token),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimir QR'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Menú secundario: editar / desactivar / térmica POS.
                    _QrCardMenu(
                      token: token,
                      isPrinting: isPrinting,
                      onEdit: () => _openEdit(context, token),
                      onDeactivate: () =>
                          _confirmDeactivate(context, token, controller),
                      onPrintThermal80: () => controller.printThermal(
                        token,
                        width: ThermalPaperWidth.mm80,
                      ),
                      onPrintThermal58: () => controller.printThermal(
                        token,
                        width: ThermalPaperWidth.mm58,
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: () => controller.reactivate(token),
                  icon: Icon(Icons.refresh,
                      size: 16, color: AppColors.accent),
                  label: Text('Reactivar',
                      style: TextStyle(color: AppColors.accent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
            ],
          ),
        ),
                ),
              ),
            ),
            if (selectionMode)
              Positioned(
                top: 10,
                right: 10,
                child: Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : Colors.grey,
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _openPreview(
    BuildContext context,
    List<String> codes,
    QrTokenModel token,
  ) async {
    await Get.toNamed(
      '/qr-tokens/preview',
      arguments: QrPreviewArgs(
        codes: codes,
        title: 'Vista previa',
        subtitle: token.displayLabel,
        initialPerPage: 1,
      ),
    );
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

/// Menú secundario en el card del QR: editar, desactivar, imprimir
/// en térmica POS (caso especial). El flujo primario "Imprimir QR"
/// (hoja normal con preview) es un botón separado fuera de este menú.
class _QrCardMenu extends StatelessWidget {
  final QrTokenModel token;
  final bool isPrinting;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onPrintThermal80;
  final VoidCallback onPrintThermal58;

  const _QrCardMenu({
    required this.token,
    required this.isPrinting,
    required this.onEdit,
    required this.onDeactivate,
    required this.onPrintThermal80,
    required this.onPrintThermal58,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: 36,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: PopupMenuButton<String>(
          tooltip: 'Más opciones',
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: isPrinting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.more_vert, color: AppColors.primary),
        onSelected: (v) {
          switch (v) {
            case 'edit':
              onEdit();
              break;
            case 'deactivate':
              onDeactivate();
              break;
            case 'thermal-80':
              onPrintThermal80();
              break;
            case 'thermal-58':
              onPrintThermal58();
              break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.edit),
              title: Text('Editar'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'IMPRESORA POS TÉRMICA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'thermal-80',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.receipt_long),
              title: Text('Imprimir en 80mm'),
              subtitle: Text('Solo si tenés POS térmica'),
            ),
          ),
          const PopupMenuItem(
            value: 'thermal-58',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.receipt),
              title: Text('Imprimir en 58mm'),
              subtitle: Text('Solo si tenés POS térmica'),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'deactivate',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.power_settings_new,
                  color: AppColors.error),
              title: Text(
                'Desactivar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
        ),
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
              const Text('Mesa del floor plan',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _TablePickerField(
                selectedId: _tableIdCtrl.text.isEmpty
                    ? null
                    : _tableIdCtrl.text,
                onChanged: (table) {
                  setState(() {
                    _tableIdCtrl.text = table?.tableElementId ?? '';
                    // Auto-completar el label si está vacío.
                    if (table != null && _labelCtrl.text.trim().isEmpty) {
                      _labelCtrl.text = table.displayLabel;
                    }
                  });
                },
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
      // Validación: el backend tira 400 si excede, pero cortamos antes.
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

// =====================================================================
// Picker de mesa real (dropdown con lista del backend)
// =====================================================================
class _TablePickerField extends StatefulWidget {
  final String? selectedId;
  final void Function(AvailableTable? table) onChanged;
  const _TablePickerField({
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_TablePickerField> createState() => _TablePickerFieldState();
}

class _TablePickerFieldState extends State<_TablePickerField> {
  @override
  void initState() {
    super.initState();
    // Si el controller aún no cargó mesas, dispararlas en background.
    final ctl = Get.find<QrTokensController>();
    if (ctl.availableTables.isEmpty && !ctl.loadingTables.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctl.loadAvailableTables();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = Get.find<QrTokensController>();

    return Obx(() {
      if (ctl.loadingTables.value && ctl.availableTables.isEmpty) {
        return const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }

      if (ctl.availableTables.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, size: 18, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No hay mesas en los planos. Andá a "Mesas" → editar plano '
                  '→ sincronizar mesas, y volvé acá.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }

      // Resolver la mesa seleccionada (si no matchea, dropdown vacío).
      AvailableTable? selected;
      for (final t in ctl.availableTables) {
        if (t.tableElementId == widget.selectedId) {
          selected = t;
          break;
        }
      }

      return DropdownButtonFormField<AvailableTable>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          hintText: 'Seleccioná una mesa',
        ),
        items: ctl.availableTables.map((t) {
          return DropdownMenuItem(
            value: t,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (t.hasQr && t.qrIsActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Con QR',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: (v) => widget.onChanged(v),
      );
    });
  }
}

// =====================================================================
// Dialog: bulk-create desde mesas reales (selección con checkboxes)
// =====================================================================
class _BulkFromTablesDialog extends StatefulWidget {
  const _BulkFromTablesDialog();

  @override
  State<_BulkFromTablesDialog> createState() =>
      _BulkFromTablesDialogState();
}

class _BulkFromTablesDialogState extends State<_BulkFromTablesDialog> {
  final Set<String> _selected = {};
  bool _saving = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<QrTokensController>().loadAvailableTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QrTokensController>();
    final media = MediaQuery.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: media.size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Generar QRs desde planos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
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
              const Text(
                'Mesas extraídas de tus floor plans. Las que ya tienen QR '
                'activo aparecen marcadas y no se duplican.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Buscar por mesa o plano',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (controller.loadingTables.value &&
                      controller.availableTables.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final filtered = controller.availableTables.where((t) {
                    if (_search.isEmpty) return true;
                    return t.tableLabel.toLowerCase().contains(_search) ||
                        t.floorPlanName.toLowerCase().contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          controller.availableTables.isEmpty
                              ? 'No hay mesas en los planos. Andá a "Mesas" '
                                  '→ tu plano → sincronizar mesas.'
                              : 'Sin resultados',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }

                  // Selectores rápidos.
                  final selectableIds = filtered
                      .where((t) => !(t.hasQr && t.qrIsActive))
                      .map((t) => t.tableElementId)
                      .toList();
                  final allSelected = selectableIds.isNotEmpty &&
                      selectableIds.every((id) => _selected.contains(id));

                  return Column(
                    children: [
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (allSelected) {
                                  _selected.removeAll(selectableIds);
                                } else {
                                  _selected.addAll(selectableIds);
                                }
                              });
                            },
                            icon: Icon(
                              allSelected
                                  ? Icons.deselect
                                  : Icons.select_all,
                              size: 18,
                            ),
                            label: Text(
                              allSelected
                                  ? 'Deseleccionar todo'
                                  : 'Seleccionar todo (${selectableIds.length})',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selected.length} seleccionadas',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final t = filtered[i];
                            final hasActiveQr = t.hasQr && t.qrIsActive;
                            return CheckboxListTile(
                              dense: true,
                              value: _selected.contains(t.tableElementId),
                              onChanged: hasActiveQr
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selected.add(t.tableElementId);
                                        } else {
                                          _selected.remove(t.tableElementId);
                                        }
                                      });
                                    },
                              title: Text(
                                t.tableLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: hasActiveQr
                                      ? Colors.grey.shade500
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                hasActiveQr
                                    ? '${t.floorPlanName} · Ya tiene QR activo (${t.qrCode})'
                                    : t.floorPlanName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasActiveQr
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade700,
                                ),
                              ),
                              secondary: hasActiveQr
                                  ? Icon(Icons.qr_code,
                                      color: Colors.grey.shade400, size: 20)
                                  : null,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _saving || _selected.isEmpty ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_2),
                  label: Text(
                    _saving
                        ? 'Generando…'
                        : 'Generar ${_selected.length} QR${_selected.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await Get.find<QrTokensController>().bulkCreateFromTables(
        tableElementIds: _selected.toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // snackbar lo lanzó el controller
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
