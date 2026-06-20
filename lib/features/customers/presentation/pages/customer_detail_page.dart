import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../controllers/customer_detail_controller.dart';

/// Customer Detail Page — pantalla de detalle de cliente.
///
/// Estructura:
///   - `AppGradientHeader` con avatar, nombre, teléfono / email y back.
///   - Sección "Estadísticas del cliente" con KPI chips (órdenes, gastado…).
///   - Sección "Direcciones" con CTA "Agregar".
///   - Sección "Historial de órdenes" usando `OrderCard`.
///   - FAB "Editar cliente" → ruta `editCustomer` con el customer en args.
class CustomerDetailPage extends GetView<CustomerDetailController> {
  const CustomerDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading) {
            return Column(
              children: [
                _buildSkeletonHeader(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (controller.hasError) {
            return Column(
              children: [
                _buildSkeletonHeader(),
                Expanded(
                  child: AppErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.refreshAll,
                  ),
                ),
              ],
            );
          }
          final customer = controller.customer.value;
          if (customer == null) return const SizedBox.shrink();
          return _buildLoaded(context, customer);
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isLoaded) return const SizedBox.shrink();
        return AppPrimaryActionBar(
          label: 'Editar cliente',
          icon: Icons.edit_outlined,
          onPressed: () => _onEdit(controller.customer.value!),
        );
      }),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  /// Header simple para los estados loading/error — sin chips ni hero, así
  /// la transición a "loaded" no salta visualmente.
  Widget _buildSkeletonHeader() {
    return AppGradientHeader(
      title: 'Cliente',
      subtitle: 'Cargando detalle…',
      leading: _BackButton(),
    );
  }

  Widget _buildHeader(Customer customer) {
    return AppGradientHeader(
      title: customer.fullName,
      subtitle: _headerSubtitle(customer),
      leading: _BackButton(),
      trailing: _StatusBadge(active: customer.isActive),
      hero: _AvatarHero(customer: customer),
    );
  }

  String _headerSubtitle(Customer customer) {
    if (customer.email != null && customer.email!.isNotEmpty) {
      return customer.email!;
    }
    return customer.phone;
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildLoaded(BuildContext context, Customer customer) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshAll,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(customer),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsSection(customer),
                const SizedBox(height: 16),
                _buildContactSection(customer),
                const SizedBox(height: 16),
                _buildAddressesSection(context),
                const SizedBox(height: 16),
                _buildOrdersSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Stats ───────────────────────────

  Widget _buildStatsSection(Customer customer) {
    return _DetailSection(
      title: 'Estadísticas del cliente',
      icon: Icons.insights_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MiniStat(
            icon: Icons.shopping_bag_outlined,
            label: 'Total órdenes',
            value: customer.totalOrders.toString(),
            tint: AppColors.primary,
          ),
          _MiniStat(
            icon: Icons.payments_outlined,
            label: 'Total gastado',
            value: CurrencyFormatter.format(customer.totalSpent),
            tint: AppColors.success,
          ),
          _MiniStat(
            icon: Icons.event_outlined,
            label: 'Última orden',
            value: customer.lastOrderDate != null
                ? _relativeDate(customer.lastOrderDate!)
                : 'Nunca',
            tint: AppColors.info,
          ),
          _MiniStat(
            icon: Icons.repeat,
            label: 'Visitas',
            // El backend no expone "visits" como métrica separada — usamos
            // total de órdenes como proxy hasta que exista.
            value: customer.totalOrders.toString(),
            tint: AppColors.warning,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Contacto ───────────────────────────

  Widget _buildContactSection(Customer customer) {
    final rows = <Widget>[
      _InfoRow(
        icon: Icons.phone_outlined,
        label: 'Teléfono',
        value: customer.phone,
      ),
      if (customer.email != null && customer.email!.isNotEmpty)
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: customer.email!,
        ),
      if (customer.notes != null && customer.notes!.isNotEmpty)
        _InfoRow(
          icon: Icons.sticky_note_2_outlined,
          label: 'Notas',
          value: customer.notes!,
          multiline: true,
        ),
    ];

    return _DetailSection(
      title: 'Información de contacto',
      icon: Icons.contact_phone_outlined,
      accent: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.divider),
            rows[i],
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── Addresses ───────────────────────────

  Widget _buildAddressesSection(BuildContext context) {
    return Obx(() {
      final addresses = controller.addresses.toList();
      return _DetailSection(
        title: 'Direcciones',
        icon: Icons.place_outlined,
        accent: AppColors.warning,
        trailing: TextButton.icon(
          onPressed: () => _openAddAddressSheet(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        child: addresses.isEmpty
            ? _InlineEmpty(
                icon: Icons.place_outlined,
                message:
                    'Sin direcciones guardadas. Agregá una para asignar entregas a domicilio más rápido.',
              )
            : Column(
                children: [
                  for (final address in addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AddressTile(address: address),
                    ),
                ],
              ),
      );
    });
  }

  // ─────────────────────────── Orders ───────────────────────────

  Widget _buildOrdersSection() {
    return Obx(() {
      final orders = controller.recentOrders.toList();
      final loading = controller.isLoadingOrders.value;
      return _DetailSection(
        title: 'Historial de órdenes',
        icon: Icons.receipt_long_outlined,
        accent: AppColors.primary,
        child: loading && orders.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : orders.isEmpty
                ? _InlineEmpty(
                    icon: Icons.receipt_long_outlined,
                    message:
                        'Este cliente todavía no tiene órdenes registradas.',
                  )
                : Column(
                    children: [
                      for (final order in orders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OrderCard(
                            order: order,
                            onTap: () => Get.toNamed(
                              AppRoutes.buildOrderDetail(order.id),
                            ),
                          ),
                        ),
                    ],
                  ),
      );
    });
  }

  // ─────────────────────────── Acciones ───────────────────────────

  Future<void> _onEdit(Customer customer) async {
    final result = await Get.toNamed(
      AppRoutes.buildEditCustomer(customer.id),
      arguments: customer,
    );
    if (result != null) controller.refreshAll();
  }

  Future<void> _openAddAddressSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddAddressSheet(controller: controller),
    );
    if (saved == true) {
      // El controller ya hizo loadAddresses(); nada más por hacer acá.
    }
  }

  // ─────────────────────────── Helpers ───────────────────────────

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'hace $weeks sem';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ─────────────────────────── Sub-widgets ───────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final label = active ? 'Activo' : 'Inactivo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.accent : Colors.white70,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarHero extends StatelessWidget {
  final Customer customer;
  const _AvatarHero({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        customer.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (customer.email != null && customer.email!.isNotEmpty)
                            ? customer.email!
                            : 'Sin email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección genérica de la pantalla de detalle: título, icono y children.
/// Replica el "look" de `AppFormSection` pero más liviano (sin sombra
/// fuerte) para las pantallas de lectura.
class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accent;
  final Widget? trailing;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    this.accent,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
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
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: tint,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: multiline ? 5 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  final CustomerAddress address;

  const _AddressTile({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address.isDefault
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.place_outlined,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        address.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Predeterminada',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  address.fullAddress,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                if (address.deliveryInstructions != null &&
                    address.deliveryInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 12,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address.deliveryInstructions!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Add Address bottom sheet ───────────────────────────

class _AddAddressSheet extends StatefulWidget {
  final CustomerDetailController controller;

  const _AddAddressSheet({required this.controller});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();

  final _labelCtrl = TextEditingController(text: 'Casa');
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await widget.controller.createAddress(
      label: _labelCtrl.text.trim(),
      addressLine1: _line1Ctrl.text.trim(),
      addressLine2: _line2Ctrl.text.trim().isEmpty
          ? null
          : _line2Ctrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      postalCode:
          _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
      deliveryInstructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      isDefault: _isDefault,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      // Compensa el teclado para que el form no quede tapado.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nueva dirección',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sumá una dirección para entregas a domicilio.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _labelCtrl,
                      decoration: appInputDecoration(
                        label: 'Etiqueta *',
                        hint: 'Casa, Oficina, etc.',
                        prefixIcon: Icons.label_outline,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _line1Ctrl,
                      decoration: appInputDecoration(
                        label: 'Dirección *',
                        hint: 'Calle 123 #45-67',
                        prefixIcon: Icons.home_outlined,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _line2Ctrl,
                      decoration: appInputDecoration(
                        label: 'Apto / Detalle',
                        hint: 'Apto 302, Torre B',
                        prefixIcon: Icons.apartment_outlined,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: appInputDecoration(
                        label: 'Ciudad *',
                        hint: 'Bogotá',
                        prefixIcon: Icons.location_city_outlined,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stateCtrl,
                            decoration: appInputDecoration(
                              label: 'Estado / Depto',
                              prefixIcon: Icons.map_outlined,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _postalCtrl,
                            decoration: appInputDecoration(
                              label: 'Código postal',
                              prefixIcon: Icons.markunread_mailbox_outlined,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instructionsCtrl,
                      decoration: appInputDecoration(
                        label: 'Instrucciones de entrega',
                        hint: 'Ej: Llamar al portero, casa amarilla',
                        prefixIcon: Icons.info_outline,
                      ),
                      maxLines: 2,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      activeThumbColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      title: const Text(
                        'Predeterminada',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Se preselecciona en nuevas órdenes de delivery',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(
                              _saving ? 'Guardando…' : 'Guardar dirección',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
