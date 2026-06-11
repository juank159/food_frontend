import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../tab_sessions/domain/entities/tab_session.dart';
import '../../../tab_sessions/domain/usecases/tab_session_usecases.dart';
import '../models/sell_mode.dart';
import 'table_selector_widget.dart';

/// Bottom sheet que aparece al tocar el pill superior de `SellPage`.
///
/// Le pregunta al operario A QUIÉN le está vendiendo. Cada opción
/// devuelve un `SellMode` que el caller aplica al controller para que
/// el siguiente submit cree la orden con el destino correcto, sin
/// cambiar de pantalla.
///
/// Opciones:
///   - Mostrador (modo default, sin nada).
///   - Para llevar.
///   - Domicilio.
///   - Tomar una mesa libre.
///   - Abrir cuenta libre con etiqueta (Césped #3, etc.).
///   - Agregar a una cuenta existente.
class SellModeSheet extends StatefulWidget {
  /// Modo actual — para mostrar el destino seleccionado y permitir
  /// volver a mostrador sin "Cancelar".
  final SellMode currentMode;

  const SellModeSheet({super.key, required this.currentMode});

  @override
  State<SellModeSheet> createState() => _SellModeSheetState();
}

class _SellModeSheetState extends State<SellModeSheet> {
  late Future<List<TabSession>> _openTabsFuture;

  @override
  void initState() {
    super.initState();
    _openTabsFuture = _loadOpenTabs();
  }

  Future<List<TabSession>> _loadOpenTabs() async {
    try {
      final useCases = sl<TabSessionUseCases>();
      final result = await useCases.findOpen();
      return result.fold((_) => <TabSession>[], (list) => list);
    } catch (_) {
      return <TabSession>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildHandle(),
            const SizedBox(height: 8),
            const Text(
              '¿A quién le vendés?',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elegí el destino del ticket. Podés cambiarlo en cualquier momento.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            _sectionTitle('Venta rápida'),
            _modeTile(
              icon: Icons.point_of_sale,
              color: AppColors.accent,
              title: 'Mostrador',
              subtitle: 'Cobro inmediato, sin cliente',
              mode: const SellMode.counter(),
            ),
            _modeTile(
              icon: Icons.shopping_bag_outlined,
              color: AppColors.warning,
              title: 'Para llevar',
              subtitle: 'Cliente retira en el local',
              mode: const SellMode.takeaway(),
            ),
            _modeTile(
              icon: Icons.delivery_dining,
              color: AppColors.info,
              title: 'Domicilio',
              subtitle: 'Reparto a domicilio',
              mode: const SellMode.delivery(),
            ),

            const SizedBox(height: 18),
            _sectionTitle('Mesa o cuenta abierta'),
            _modeTile(
              icon: Icons.table_restaurant,
              color: AppColors.primary,
              title: 'Mesa',
              subtitle: 'Elegir mesa del plano',
              onTap: _openTablePicker,
            ),
            _modeTile(
              icon: Icons.add_circle_outline,
              color: AppColors.accent,
              title: 'Nueva cuenta libre',
              subtitle: 'Cliente sin mesa (césped, sillas, etc.)',
              onTap: _openFreeAccountDialog,
            ),

            const SizedBox(height: 18),
            FutureBuilder<List<TabSession>>(
              future: _openTabsFuture,
              builder: (context, snapshot) {
                final tabs = snapshot.data ?? const <TabSession>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (tabs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Cuentas ya abiertas'),
                    for (final t in tabs)
                      _modeTile(
                        icon: t.tableElementId != null || t.tableId != null
                            ? Icons.table_restaurant
                            : Icons.chair_outlined,
                        color: AppColors.success,
                        title: t.displayLabel(),
                        subtitle:
                            '${t.totalOrders} ${t.totalOrders == 1 ? "ticket" : "tickets"} · abierta',
                        mode: SellMode.tabSession(
                          sessionId: t.id,
                          sessionLabel: t.displayLabel(),
                          tableElementId: t.tableElementId,
                          tableId: t.tableId,
                          tableName: t.tableName,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _modeTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    SellMode? mode,
    VoidCallback? onTap,
  }) {
    assert(mode != null || onTap != null,
        'Tile sin `mode` ni `onTap` — al menos uno debe estar definido.');
    final isCurrent =
        mode != null && widget.currentMode.pillLabel == mode.pillLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCurrent
            ? color.withValues(alpha: 0.10)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (onTap != null) {
              onTap();
            } else if (mode != null) {
              Navigator.of(context).pop<SellMode>(mode);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isCurrent ? color.withValues(alpha: 0.5) : AppColors.border,
                width: isCurrent ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 20),
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
                          fontWeight: FontWeight.w800,
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
                if (isCurrent)
                  Icon(Icons.check_circle, color: color, size: 22)
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textHint,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sub-dialogs ──────────────────────────────────────────────────

  /// Abre el dialog para crear cuenta libre con etiqueta. Si el operario
  /// confirma, llamamos al backend, creamos la sesión y devolvemos el
  /// `SellMode.tabSession` correspondiente.
  Future<void> _openFreeAccountDialog() async {
    final labelCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Abrir cuenta libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para clientes en zonas no registradas (césped, sillas, terraza).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: labelCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Etiqueta',
                hintText: 'Ej. Césped #3, Silla árbol',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => Navigator.of(dialogCtx).pop(true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: partyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Personas (opcional)',
                prefixIcon: const Icon(Icons.group_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Abrir cuenta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final label = labelCtrl.text.trim();
    if (label.isEmpty) return;

    final useCases = sl<TabSessionUseCases>();
    final result = await useCases.open(
      notes: label,
      partySize: int.tryParse(partyCtrl.text.trim()),
    );
    if (!mounted) return;
    result.fold(
      (_) {},
      (session) {
        Navigator.of(context).pop<SellMode>(SellMode.tabSession(
          sessionId: session.id,
          sessionLabel: session.displayLabel(),
          tableElementId: session.tableElementId,
          tableId: session.tableId,
          tableName: session.tableName,
        ));
      },
    );
  }

  /// Muestra un selector de mesa (reusa `TableSelectorWidget`) sobre
  /// el mismo sheet. Al elegir, devolvemos el `SellMode.dineIn` —
  /// el operario nunca abandona el flujo de venta.
  Future<void> _openTablePicker() async {
    final selected = await showModalBottomSheet<SellMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Elegí mesa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TableSelectorWidget(
                  onTableSelected: (tableElementId, tableId, tableName) {
                    Navigator.of(sheetCtx).pop<SellMode>(SellMode.dineIn(
                      tableElementId: tableElementId,
                      tableId: tableId,
                      tableName: tableName,
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      Navigator.of(context).pop<SellMode>(selected);
    } else {
      // Si canceló, mostramos un hint discreto y dejamos el sheet
      // abierto para que elija otra cosa.
      AppSnackbar.show(
        'Sin mesa elegida',
        'Podés seguir con mostrador o elegir otro destino.',
        duration: const Duration(seconds: 2),
      );
    }
  }
}
