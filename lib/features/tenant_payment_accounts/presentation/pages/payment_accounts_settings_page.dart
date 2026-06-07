import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/tenant_payment_account.dart';
import '../controllers/tenant_payment_account_controller.dart';
import '../widgets/payment_account_form_dialog.dart';

/// Pantalla de configuración de cuentas de pago del tenant.
///
/// Muestra todas las cuentas agrupadas por categoría (efectivo,
/// transferencia, billetera digital, tarjeta). Cada tarjeta permite
/// activar/desactivar, editar y eliminar la cuenta. Botón flotante
/// para agregar una nueva.
class PaymentAccountsSettingsPage extends StatelessWidget {
  const PaymentAccountsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TenantPaymentAccountController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppPrimaryActionBar(
        label: 'Nueva cuenta',
        icon: Icons.add,
        onPressed: () => _showFormDialog(controller),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppGradientHeader(
              title: 'Cuentas de pago',
              subtitle: 'Nequi, Daviplata, Bancolombia, cajas, etc.',
              leading: GestureDetector(
                onTap: () => Get.back(),
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
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.accounts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.accounts.isEmpty) {
                  return _EmptyState(
                    onCreate: () => _showFormDialog(controller),
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.loadAccounts,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: _buildCategorySections(controller),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections(
    TenantPaymentAccountController controller,
  ) {
    final grouped = controller.accountsByCategory;
    final sections = <Widget>[];

    // Orden fijo de categorías para que la pantalla no se reordene.
    const ordered = [
      PaymentMethod.cash,
      PaymentMethod.transfer,
      PaymentMethod.digitalWallet,
      PaymentMethod.card,
    ];

    for (final category in ordered) {
      final accounts = grouped[category];
      if (accounts == null || accounts.isEmpty) continue;
      sections.add(_CategoryHeader(category: category, count: accounts.length));
      sections.add(const SizedBox(height: 8));
      for (final account in accounts) {
        sections.add(
          _AccountCard(
            account: account,
            onToggleActive: () => controller.toggleActive(account),
            onEdit: () => _showFormDialog(controller, account: account),
            onDelete: () => _confirmDelete(controller, account),
          ),
        );
        sections.add(const SizedBox(height: 8));
      }
      sections.add(const SizedBox(height: 16));
    }

    return sections;
  }

  Future<void> _showFormDialog(
    TenantPaymentAccountController controller, {
    TenantPaymentAccount? account,
  }) async {
    await Get.dialog<bool>(
      PaymentAccountFormDialog(account: account),
      barrierDismissible: false,
    );
  }

  Future<void> _confirmDelete(
    TenantPaymentAccountController controller,
    TenantPaymentAccount account,
  ) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Eliminar cuenta'),
        content: Text(
          '¿Eliminar "${account.name}"? Los pagos ya registrados no se borrarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteAccount(account.id);
    }
  }
}

class _CategoryHeader extends StatelessWidget {
  final PaymentMethod category;
  final int count;

  const _CategoryHeader({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            _iconFor(category),
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            category.displayName.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.card:
        return Icons.credit_card_outlined;
      case PaymentMethod.transfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.digitalWallet:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _AccountCard extends StatelessWidget {
  final TenantPaymentAccount account;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = account.isActive
        ? AppColors.primary
        : AppColors.textSecondary.withValues(alpha: 0.5);

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: accent,
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
                            account.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: account.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!account.isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INACTIVA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (account.accountHolder != null ||
                        account.accountNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (account.accountHolder != null)
                            account.accountHolder!,
                          if (account.accountNumber != null)
                            account.accountNumber!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Switch.adaptive(
                value: account.isActive,
                onChanged: (_) => onToggleActive(),
                activeThumbColor: AppColors.primary,
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin cuentas configuradas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Agregá las cuentas donde recibís pagos\n(Nequi, Daviplata, Bancolombia, etc).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Agregar primera cuenta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
