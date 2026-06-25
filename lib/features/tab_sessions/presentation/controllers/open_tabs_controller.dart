import 'package:get/get.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/date_period.dart';
import '../../domain/entities/tab_session.dart';
import '../../domain/usecases/tab_session_usecases.dart';

enum TabTypeFilter {
  table('Mesa'),
  freeAccount('Cuenta libre');

  final String displayName;
  const TabTypeFilter(this.displayName);
}

enum BalanceFilter {
  withBalance('Con saldo'),
  paid('Pagado');

  final String displayName;
  const BalanceFilter(this.displayName);
}

/// Lista de cuentas abiertas (mesas + delivery activos).
class OpenTabsController extends GetxController {
  final TabSessionUseCases useCases;

  OpenTabsController({required this.useCases});

  final RxList<TabSession> sessions = <TabSession>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isOpening = false.obs;
  final RxString errorMessage = ''.obs;

  // ── Búsqueda ──
  final RxString searchQuery = ''.obs;
  void setSearchQuery(String q) => searchQuery.value = q;

  // ── Período ──
  final Rx<DatePeriod> datePeriod = DatePeriod.today.obs;
  final Rx<DateTime?> startDate = Rx(null);
  final Rx<DateTime?> endDate = Rx(null);

  void setDatePeriod(
    DatePeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final range = resolveDatePeriod(
      period,
      customStart: customStart,
      customEnd: customEnd,
    );
    startDate.value = range.start;
    endDate.value = range.end;
    datePeriod.value = period;
  }

  // ── Filtros avanzados ──
  final Rx<TabTypeFilter?> filterTabType = Rx(null);
  final Rx<BalanceFilter?> filterBalance = Rx(null);

  void filterByTabType(TabTypeFilter? t) => filterTabType.value = t;
  void filterByBalance(BalanceFilter? b) => filterBalance.value = b;

  int get advancedFilterCount =>
      (filterTabType.value != null ? 1 : 0) +
      (filterBalance.value != null ? 1 : 0);

  void clearAdvancedFilters() {
    filterTabType.value = null;
    filterBalance.value = null;
  }

  /// Cuentas filtradas por período + búsqueda + filtros avanzados.
  List<TabSession> get filteredSessions {
    var list = sessions.toList();

    // Filtro de período sobre openedAt (client-side).
    final start = startDate.value;
    final end = endDate.value;
    if (start != null) {
      list = list.where((s) => !s.openedAt.isBefore(start)).toList();
    }
    if (end != null) {
      list = list.where((s) => !s.openedAt.isAfter(end)).toList();
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) {
        return s.displayLabel().toLowerCase().contains(q) ||
            (s.notes?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    final type = filterTabType.value;
    if (type != null) {
      list = list
          .where((s) =>
              type == TabTypeFilter.table ? s.hasTable : !s.hasTable)
          .toList();
    }

    final bal = filterBalance.value;
    if (bal != null) {
      list = list
          .where((s) => bal == BalanceFilter.withBalance
              ? s.hasPendingBalance
              : !s.hasPendingBalance)
          .toList();
    }

    return list;
  }

  @override
  void onInit() {
    super.onInit();
    setDatePeriod(DatePeriod.today);
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.findOpen();
    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show('Error', failure.message);
      },
      (list) => sessions.assignAll(list),
    );
    isLoading.value = false;
  }

  /// Abre una cuenta "libre" — sin mesa del floor plan.
  Future<String?> openFreeAccount({
    required String label,
    int? partySize,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      AppSnackbar.show('Etiqueta requerida',
          'Poné algo como "Césped #3" para identificar la cuenta.');
      return null;
    }
    isOpening.value = true;
    final result = await useCases.open(
      notes: trimmed,
      partySize: partySize,
    );
    isOpening.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('No se pudo abrir', failure.message);
        return null;
      },
      (session) {
        sessions.insert(0, session);
        return session.id;
      },
    );
  }

  double get totalPendingBalance =>
      sessions.fold(0.0, (sum, s) => sum + s.balance);

  int get totalTickets =>
      sessions.fold(0, (sum, s) => sum + s.totalOrders);
}
