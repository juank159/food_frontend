import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/checklist_controller.dart';

/// Lista de compras / checklist — "lo que hace falta comprar".
///
/// El admin/gerente/cajero anota lo que falta y lo va tildando a medida
/// que lo compra. Persistente por negocio (compartida entre dispositivos).
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final ChecklistController controller = Get.put(ChecklistController());
  final TextEditingController _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    _addCtrl.clear();
    await controller.add(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(() => AppGradientHeader(
                  title: 'Lista de compras',
                  subtitle: controller.items.isEmpty
                      ? 'Anotá lo que hace falta comprar'
                      : '${controller.pendingCount} por comprar · '
                          '${controller.doneCount} comprados',
                  leading: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  trailing: controller.doneCount > 0
                      ? IconButton(
                          tooltip: 'Borrar comprados',
                          onPressed: _confirmClear,
                          icon: const Icon(Icons.delete_sweep_outlined,
                              color: Colors.white),
                        )
                      : null,
                )),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Sin items',
                    message:
                        'Agregá lo que falta comprar (ej. "Servilletas", '
                        '"Gaseosa 1.5L x12"). Se tilda cuando lo compres.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: controller.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _itemTile(controller.items[i]),
                  ),
                );
              }),
            ),
            _buildAddBar(),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(ChecklistItem item) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => controller.toggle(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                item.isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: item.isDone ? AppColors.success : AppColors.textHint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: item.isDone
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Borrar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18,
                    color: AppColors.textHint),
                onPressed: () => controller.remove(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Agregar item…',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => FilledButton(
                  onPressed: controller.isSaving.value ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(56, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: controller.isSaving.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Borrar comprados'),
        content: const Text(
          '¿Borrar todos los items ya marcados como comprados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.clearCompleted();
  }
}
