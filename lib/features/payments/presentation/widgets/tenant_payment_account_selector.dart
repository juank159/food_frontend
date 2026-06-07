import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../tenant_payment_accounts/domain/entities/tenant_payment_account.dart';
import '../../../tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import '../controllers/payment_controller.dart';

/// Selector de cuenta concreta del tenant (Nequi, Bancolombia, etc.)
/// que aparece dentro del flujo de procesar pago, debajo del selector
/// de categoría general.
///
/// Si el tenant **no tiene cuentas activas** para la categoría elegida,
/// el widget se colapsa a un mensaje suave — no bloquea el flujo, el
/// pago se procesa solo con la categoría.
///
/// Tenant accounts se cargan una vez por instancia (la lista típica es
/// de 3-10 cuentas; cabe en memoria sin paginación).
class TenantPaymentAccountSelector extends StatefulWidget {
  /// La categoría actualmente seleccionada en el `PaymentMethodSelector`.
  final PaymentMethod category;

  final PaymentController controller;

  const TenantPaymentAccountSelector({
    super.key,
    required this.category,
    required this.controller,
  });

  @override
  State<TenantPaymentAccountSelector> createState() =>
      _TenantPaymentAccountSelectorState();
}

class _TenantPaymentAccountSelectorState
    extends State<TenantPaymentAccountSelector> {
  late Future<List<TenantPaymentAccount>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAccounts();
  }

  Future<List<TenantPaymentAccount>> _loadAccounts() async {
    final useCases = sl<TenantPaymentAccountUseCases>();
    final result = await useCases.getAll(onlyActive: true);
    return result.fold((_) => <TenantPaymentAccount>[], (list) => list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<TenantPaymentAccount>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final all = snapshot.data ?? [];
        final accounts = all
            .where((a) => a.category == widget.category && a.isActive)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        if (accounts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                '¿En qué cuenta?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accounts.map((acc) {
                  final isSelected =
                      widget.controller.selectedTenantAccountId.value ==
                          acc.id;
                  return _AccountChip(
                    account: acc,
                    isSelected: isSelected,
                    onTap: () {
                      widget.controller.selectedTenantAccountId.value =
                          isSelected ? null : acc.id;
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountChip extends StatelessWidget {
  final TenantPaymentAccount account;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountChip({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (account.accountNumber != null ||
                  account.accountHolder != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (account.accountHolder != null)
                        account.accountHolder!,
                      if (account.accountNumber != null)
                        account.accountNumber!,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.85)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
