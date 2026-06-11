// lib/features/categories/presentation/pages/categories_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
import '../../domain/entities/category.dart';
import '../bindings/categories_binding.dart';
import '../controllers/categories_controller.dart';
import '../widgets/category_card.dart';

/// Categorías — pantalla principal.
///
/// Cuando se monta como tab dentro de `ProductsPage`, pasamos `embedded: true`
/// para omitir el header propio (el padre provee el gradient con TabBar).
/// En modo standalone usamos el `AppGradientHeader` con KPIs (total, raíz,
/// hijas) y los toggles de vista de árbol / solo activos.
///
/// **Auto-binding defensivo:** la página garantiza que `CategoriesController`
/// esté registrado en GetX antes del build, sin depender de quién la haya
/// montado. Esto evita el clásico crash *"CategoriesController not found"*
/// cuando GetX libera el controller por SmartManagement o cuando la
/// página se usa como widget anidado (ej. tab dentro de ProductsPage)
/// sin pasar por una `Route` con `binding`.
class CategoriesPage extends StatefulWidget {
  final bool embedded;

  const CategoriesPage({super.key, this.embedded = false});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late final CategoriesController controller;

  @override
  void initState() {
    super.initState();
    // Garantizar que el controller exista. Si ya está registrado
    // (por HomeBinding o CategoriesBinding al entrar por route),
    // lo reutilizamos. Si no, lo creamos con el mismo CategoriesBinding.
    if (!Get.isRegistered<CategoriesController>()) {
      CategoriesBinding().dependencies();
    }
    controller = Get.find<CategoriesController>();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      // Adentro de ProductsPage: solo el body, sin header propio.
      return _buildBody(context);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      bottomNavigationBar: AppPrimaryActionBar(
        label: 'Nueva categoría',
        icon: Icons.add,
        onPressed: () async {
          final result = await NavigationService.toCreateCategory();
          if (result != null) controller.refreshCategories();
        },
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      final total = controller.categories.length;
      final tree = controller.categoryTree.length;
      final children = total - tree;
      return AppGradientHeader(
        title: 'Categorías',
        subtitle: 'Organizá tu menú por agrupaciones',
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => _GradientToggleButton(
                  active: controller.isTreeView.value,
                  icon: Icons.account_tree_outlined,
                  activeIcon: Icons.account_tree,
                  tooltip: controller.isTreeView.value
                      ? 'Vista de árbol activa'
                      : 'Ver como árbol',
                  onTap: controller.toggleTreeView,
                )),
            const SizedBox(width: 6),
            Obx(() => _GradientToggleButton(
                  active: controller.showOnlyActive.value,
                  icon: Icons.filter_alt_outlined,
                  activeIcon: Icons.filter_alt,
                  tooltip: controller.showOnlyActive.value
                      ? 'Solo activas'
                      : 'Mostrar todas',
                  onTap: controller.toggleActiveFilter,
                )),
          ],
        ),
        chips: [
          AppKpiChip(
            icon: Icons.layers,
            label: 'Total',
            value: total.toString(),
          ),
          AppKpiChip(
            icon: Icons.folder_outlined,
            label: 'Raíz',
            value: tree.toString(),
          ),
          AppKpiChip(
            icon: Icons.subdirectory_arrow_right,
            label: 'Hijas',
            value: children >= 0 ? children.toString() : '0',
          ),
        ],
      );
    });
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && !controller.hasCategories) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorMessage.value.isNotEmpty &&
                !controller.hasCategories) {
              return AppErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.refreshCategories,
              );
            }
            if (!controller.hasCategories) {
              // Distingo tres estados:
              //   1) hay búsqueda activa  → "no se encontró".
              //   2) filtro "solo activas" + sin resultados  → invitar
              //      a desactivar el filtro.
              //   3) realmente no hay categorías cargadas todavía.
              final hasQuery = controller.searchQuery.value.isNotEmpty;
              final onlyActive = controller.showOnlyActive.value;
              if (hasQuery) {
                return AppEmptyState(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                  message:
                      'No encontramos categorías que coincidan con "${controller.searchQuery.value}". Probá con otra búsqueda.',
                  actionLabel: 'Limpiar búsqueda',
                  actionIcon: Icons.close,
                  onAction: () {
                    controller.searchQuery.value = '';
                    controller.refreshCategories();
                  },
                );
              }
              if (onlyActive) {
                return AppEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Sin categorías activas',
                  message:
                      'Tenés el filtro "solo activas" puesto. Quitalo para ver todas las categorías o creá una nueva.',
                  actionLabel: 'Mostrar todas',
                  actionIcon: Icons.filter_alt_off,
                  onAction: controller.toggleActiveFilter,
                );
              }
              return AppEmptyState(
                icon: Icons.category_outlined,
                title: 'Aún no hay categorías',
                message:
                    'Las categorías ayudan a organizar el menú. Empezá creando una para tus productos.',
                actionLabel: 'Nueva categoría',
                actionIcon: Icons.add,
                onAction: () async {
                  final result = await NavigationService.toCreateCategory();
                  if (result != null) controller.refreshCategories();
                },
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshCategories,
              child: controller.isTreeView.value
                  ? _buildTreeView()
                  : _buildListView(),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: _CategorySearchField(
        onSubmit: controller.searchCategories,
        onClear: () {
          controller.searchQuery.value = '';
          controller.refreshCategories();
        },
        hasQuery: () => controller.searchQuery.value.isNotEmpty,
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: controller.categories.length,
      itemBuilder: (context, index) {
        final category = controller.categories[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CategoryCard(
            category: category,
            onTap: () => _openCategory(category),
            showChildren: true,
          ),
        );
      },
    );
  }

  Widget _buildTreeView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: controller.categoryTree.length,
      itemBuilder: (context, index) {
        final category = controller.categoryTree[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTreeNode(category, 0),
        );
      },
    );
  }

  /// Renderiza una categoría y, recursivamente, sus hijas con indentación
  /// progresiva + un guide vertical sutil que ayuda a leer la jerarquía.
  Widget _buildTreeNode(Category category, int level) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (level > 0) ...[
                // Guía visual: línea + flecha sutil para indicar
                // "esta es subcategoría de la de arriba".
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: CategoryCard(
                  category: category,
                  onTap: () => _openCategory(category),
                  showChildren: false,
                ),
              ),
            ],
          ),
        ),
        if (category.hasChildren)
          ...category.children.map<Widget>((child) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildTreeNode(child, level + 1),
            );
          }),
      ],
    );
  }

  /// Tap en una categoría → pantalla de detalle dedicada.
  /// (Antes abríamos directo el form de edición; ahora hay una vista de
  /// detalle con KPIs, productos y subcategorías; el FAB lleva a editar.)
  Future<void> _openCategory(Category category) async {
    final result = await NavigationService.toCategoryDetail(category.id);
    if (result != null) controller.refreshCategories();
  }
}

/// Search field con clear button. Lo aislamos como `StatefulWidget` para
/// poder mantener un único `TextEditingController` durante toda la vida de
/// la página y evitar reconstruir el controller en cada `Obx` (lo que
/// causaría salto de cursor y leak).
class _CategorySearchField extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final bool Function() hasQuery;

  const _CategorySearchField({
    required this.onSubmit,
    required this.onClear,
    required this.hasQuery,
  });

  @override
  State<_CategorySearchField> createState() => _CategorySearchFieldState();
}

class _CategorySearchFieldState extends State<_CategorySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    // Solo gatilla rebuild local para mostrar/ocultar el clear.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showClear = _controller.text.isNotEmpty || widget.hasQuery();
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: widget.onSubmit,
      decoration: InputDecoration(
        hintText: 'Buscar categorías…',
        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: showClear
            ? IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  _controller.clear();
                  widget.onClear();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Botón circular sobre el gradient con estado activo/inactivo.
class _GradientToggleButton extends StatelessWidget {
  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final VoidCallback onTap;

  const _GradientToggleButton({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              active ? activeIcon : icon,
              color: active ? AppColors.primary : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
