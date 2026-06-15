import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../categories/presentation/bindings/categories_binding.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../data/datasources/flavor_remote_datasource.dart';
import '../../domain/entities/flavor.dart';
import '../controllers/flavors_controller.dart';

/// Gestión de cremas/sabores por categoría (ej. Heladería). El tenant
/// registra una sola vez los sabores de cada categoría; al vender un
/// producto cuya variante define "bolas", el operario (o el cliente por
/// QR) elige esa cantidad de sabores.
class FlavorsPage extends StatefulWidget {
  const FlavorsPage({super.key});

  @override
  State<FlavorsPage> createState() => _FlavorsPageState();
}

class _FlavorsPageState extends State<FlavorsPage> {
  late final CategoriesController categories;
  late final FlavorsController flavors;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<CategoriesController>()) {
      CategoriesBinding().dependencies();
    }
    categories = Get.find<CategoriesController>();
    flavors = Get.put(FlavorsController(sl<FlavorRemoteDataSource>()));
    // Autoseleccionar la primera categoría cuando carguen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelection());
    ever<List<dynamic>>(categories.categories, (_) => _ensureSelection());
  }

  void _ensureSelection() {
    if (flavors.categoryId.value == null && categories.categories.isNotEmpty) {
      flavors.selectCategory(categories.categories.first.id);
    }
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAdd() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    await flavors.add(text);
    _addCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cremas / Sabores'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Selector de categoría ──
          Obx(() {
            final cats = categories.categories
                .where((c) => c.isActive)
                .toList();
            if (cats.isEmpty) {
              return const SizedBox.shrink();
            }
            final selected = flavors.categoryId.value;
            return Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in cats)
                      AppFilterChip(
                        label: c.name,
                        selected: selected == c.id,
                        onTap: () => flavors.selectCategory(c.id),
                      ),
                  ],
                ),
              ),
            );
          }),

          // ── Agregar crema ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _submitAdd(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Nueva crema (ej. Vainilla chip)',
                      prefixIcon: const Icon(Icons.icecream, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => FilledButton(
                      onPressed: flavors.isSaving.value ? null : _submitAdd,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                      child: flavors.isSaving.value
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

          // ── Lista de cremas ──
          Expanded(
            child: Obx(() {
              if (flavors.categoryId.value == null) {
                return _hint('Elegí una categoría para ver sus cremas.');
              }
              if (flavors.isLoading.value && flavors.flavors.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (flavors.flavors.isEmpty) {
                return _hint(
                    'Sin cremas todavía. Agregá la primera arriba.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: flavors.flavors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _flavorTile(flavors.flavors[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );

  Widget _flavorTile(Flavor f) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        title: Text(
          f.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: f.isAvailable
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            decoration:
                f.isAvailable ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(f.isAvailable ? 'Disponible' : 'Oculta',
            style: const TextStyle(fontSize: 12)),
        leading: IconButton(
          tooltip: 'Renombrar',
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => _renameDialog(f),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: f.isAvailable,
              activeColor: AppColors.primary,
              onChanged: (_) => flavors.toggleAvailable(f),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.error),
              onPressed: () => _confirmDelete(f),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameDialog(Flavor f) async {
    final ctrl = TextEditingController(text: f.name);
    await AppDialog.show<void>(
      Builder(
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Renombrar crema'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                flavors.rename(f, ctrl.text);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
      context: context,
    );
  }

  Future<void> _confirmDelete(Flavor f) async {
    await AppDialog.show<void>(
      Builder(
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Eliminar crema'),
          content: Text('¿Eliminar "${f.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                flavors.remove(f);
              },
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
      context: context,
    );
  }
}
