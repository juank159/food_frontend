import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/utils/role_labels.dart';
import '../../../../core/utils/ui_access.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/employee.dart';
import '../controllers/employees_controller.dart';
import '../widgets/employee_card.dart';

/// Pantalla principal del módulo Empleados.
///
/// Layout calcado de Categorías / Órdenes:
///   - `AppGradientHeader` con KPIs (total, activos, suspendidos, roles).
///   - Buscador inline + filtros tipo `AppFilterChip` por estado y por rol.
///   - Lista de `EmployeeCard` con menú contextual de acciones.
///   - FAB extendido para crear nuevo.
class EmployeesPage extends GetView<EmployeesController> {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      // Alta de empleados: SOLO admin (el manager ve/edita pero no crea).
      // El backend también lo refuerza con @Roles(ROLE_ADMIN) en POST /users.
      bottomNavigationBar:
          UiAccess.from(Get.find<AuthController>().currentUser)
                  .canCreateEmployees
              ? AppPrimaryActionBar(
                  label: 'Nuevo empleado',
                  icon: Icons.person_add_alt_1,
                  onPressed: _goToCreate,
                )
              : null,
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Obx(() {
      return AppGradientHeader(
        title: 'Empleados',
        subtitle: 'Tu equipo y sus permisos',
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
        chips: [
          AppKpiChip(
            icon: Icons.groups_outlined,
            label: 'Total',
            value: controller.totalCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.check_circle_outline,
            label: 'Activos',
            value: controller.activeCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.pause_circle_outline,
            label: 'Suspendidos',
            value: controller.suspendedCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.workspace_premium_outlined,
            label: 'Roles',
            value: controller.distinctRoleCount.toString(),
          ),
        ],
      );
    });
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildStatusFilters(),
        _buildRoleFilters(),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && controller.employees.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorMessage.value.isNotEmpty &&
                controller.employees.isEmpty) {
              return AppErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.refreshEmployees,
              );
            }
            if (controller.employees.isEmpty) {
              return AppEmptyState(
                icon: Icons.badge_outlined,
                title: 'Aún no hay empleados',
                message:
                    'Sumá a tu equipo para asignarles roles, permisos y tareas '
                    'dentro del local.',
                actionLabel: 'Nuevo empleado',
                actionIcon: Icons.person_add_alt_1,
                onAction: _goToCreate,
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshEmployees,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: controller.employees.length,
                itemBuilder: (context, index) {
                  final emp = controller.employees[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EmployeeCard(
                      employee: emp,
                      onTap: () => _goToDetail(emp),
                      onAction: (action) => _handleAction(emp, action),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        textInputAction: TextInputAction.search,
        onSubmitted: controller.searchEmployees,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o email…',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 38,
        child: Obx(() {
          final current = controller.statusFilter.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              AppFilterChip(
                label: 'Todos',
                icon: Icons.groups_outlined,
                selected: current == EmployeeStatusFilter.all,
                onTap: () =>
                    controller.setStatusFilter(EmployeeStatusFilter.all),
              ),
              AppFilterChip(
                label: 'Activos',
                icon: Icons.check_circle_outline,
                selected: current == EmployeeStatusFilter.active,
                onTap: () =>
                    controller.setStatusFilter(EmployeeStatusFilter.active),
              ),
              AppFilterChip(
                label: 'Suspendidos',
                icon: Icons.pause_circle_outline,
                selected: current == EmployeeStatusFilter.suspended,
                onTap: () => controller
                    .setStatusFilter(EmployeeStatusFilter.suspended),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildRoleFilters() {
    return Obx(() {
      final roles = controller.availableRoles;
      if (roles.isEmpty) return const SizedBox(height: 8);
      final selected = controller.roleFilter.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              AppFilterChip(
                label: 'Todos los roles',
                icon: Icons.workspace_premium_outlined,
                selected: selected == null,
                onTap: () => controller.setRoleFilter(null),
              ),
              for (final role in roles)
                AppFilterChip(
                  label: roleLabelEs(role.code, fallback: role.name),
                  selected: selected == role.id,
                  onTap: () => controller.setRoleFilter(role.id),
                ),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────── Actions ───────────────────────────

  void _handleAction(Employee employee, EmployeeCardAction action) {
    switch (action) {
      case EmployeeCardAction.edit:
        _goToEdit(employee);
        break;
      case EmployeeCardAction.suspend:
        controller.suspendEmployee(employee);
        break;
      case EmployeeCardAction.activate:
        controller.activateEmployee(employee);
        break;
      case EmployeeCardAction.delete:
        controller.deleteEmployee(employee);
        break;
    }
  }

  Future<void> _goToCreate() async {
    final result = await Get.toNamed(AppRoutes.createEmployee);
    if (result != null) controller.refreshEmployees();
  }

  Future<void> _goToEdit(Employee employee) async {
    final result = await Get.toNamed(
      AppRoutes.buildEditEmployee(employee.id),
      arguments: employee,
    );
    if (result != null) controller.refreshEmployees();
  }

  /// Abre la pantalla de detalle. Si el detalle reportó un cambio
  /// (edición o eliminación) refrescamos la lista para reflejarlo.
  Future<void> _goToDetail(Employee employee) async {
    final result =
        await NavigationService.toEmployeeDetail<dynamic>(employee.id);
    if (result != null) controller.refreshEmployees();
  }
}
