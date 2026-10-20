import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/local_cache_service.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/date_period.dart';
import 'expenses_controller.dart' show moneyToDouble;

/// Frecuencia de pago — no todos los negocios pagan mensual.
enum PayFrequency {
  weekly('weekly', 'Semanal'),
  biweekly('biweekly', 'Quincenal'),
  monthly('monthly', 'Mensual');

  final String apiValue;
  final String displayName;
  const PayFrequency(this.apiValue, this.displayName);

  static PayFrequency fromApi(String? value) => PayFrequency.values
      .firstWhere((f) => f.apiValue == value, orElse: () => PayFrequency.monthly);
}

/// Entrada de nómina (pago a un empleado por un período).
class PayrollEntry {
  final String id;
  final String? userId;
  final String employeeName;
  final String periodLabel;
  final double baseAmount;
  final double additions;
  final double deductions;
  final double netAmount;
  final bool isPaid;
  final DateTime? paidAt;
  final String? notes;
  final PayFrequency payFrequency;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const PayrollEntry({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.periodLabel,
    required this.baseAmount,
    required this.additions,
    required this.deductions,
    required this.netAmount,
    required this.isPaid,
    this.paidAt,
    this.notes,
    this.payFrequency = PayFrequency.monthly,
    this.periodStart,
    this.periodEnd,
  });

  factory PayrollEntry.fromJson(Map<String, dynamic> json) => PayrollEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        employeeName: (json['employee_name'] as String?) ?? '',
        periodLabel: (json['period_label'] as String?) ?? '',
        baseAmount: moneyToDouble(json['base_amount']),
        additions: moneyToDouble(json['additions']),
        deductions: moneyToDouble(json['deductions']),
        netAmount: moneyToDouble(json['net_amount']),
        isPaid: (json['is_paid'] as bool?) ?? false,
        paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
        notes: json['notes'] as String?,
        payFrequency: PayFrequency.fromApi(json['pay_frequency'] as String?),
        periodStart: DateTime.tryParse(json['period_start']?.toString() ?? ''),
        periodEnd: DateTime.tryParse(json['period_end']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'employee_name': employeeName,
        'period_label': periodLabel,
        'base_amount': baseAmount,
        'additions': additions,
        'deductions': deductions,
        'net_amount': netAmount,
        'is_paid': isPaid,
        'paid_at': paidAt?.toIso8601String(),
        'notes': notes,
        'pay_frequency': payFrequency.apiValue,
        'period_start': periodStart?.toIso8601String(),
        'period_end': periodEnd?.toIso8601String(),
      };
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Controller de nómina. Dio directo. Endpoints `/payroll`.
class PayrollController extends GetxController {
  late final Dio _dio;
  late final LocalCacheService _cache;

  static const _cacheKey = 'payroll_snapshot';

  final RxList<PayrollEntry> items = <PayrollEntry>[].obs;
  final RxDouble totalNet = 0.0.obs;
  final RxDouble totalPaid = 0.0.obs;
  final RxDouble totalPending = 0.0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  // ── Filtro de período — bug real reportado: no había forma de ver
  // "hoy/esta semana/quincena/este mes", solo la lista completa.
  final Rx<DatePeriod> datePeriod = DatePeriod.all.obs;

  @override
  void onInit() {
    super.onInit();
    _dio = GetIt.I<Dio>();
    _cache = GetIt.I<LocalCacheService>();
    load();
  }

  void setDatePeriod(DatePeriod period) {
    if (datePeriod.value == period) return;
    datePeriod.value = period;
    load();
  }

  /// Local-first (mismo patrón que el resto): pinta la última nómina
  /// cacheada al instante, refresca atrás sin bloquear. El filtro de
  /// período se aplica solo del lado de la red (`date_from`/`date_to`)
  /// — la caché local guarda siempre el último snapshot SIN filtrar,
  /// simple y suficiente para el pintado inicial.
  Future<void> load() async {
    final cachedRaw = _cache.getObject(_cacheKey);
    final paintedFromCache = cachedRaw != null && datePeriod.value == DatePeriod.all;
    if (paintedFromCache) _applySnapshot(cachedRaw);

    isLoading.value = !paintedFromCache;
    error.value = '';
    try {
      final range = resolveDatePeriod(datePeriod.value);
      final res = await _dio.get('/payroll', queryParameters: {
        if (range.start != null) 'date_from': _isoDate(range.start!),
        if (range.end != null) 'date_to': _isoDate(range.end!),
      });
      final obj = ApiResponseUtils.object(res);
      _applySnapshot(obj);
      if (datePeriod.value == DatePeriod.all) {
        await _cache.saveObject(_cacheKey, {
          'items': items.map((e) => e.toJson()).toList(),
          'total_net': totalNet.value,
          'total_paid': totalPaid.value,
          'total_pending': totalPending.value,
        });
      }
    } catch (e) {
      if (!paintedFromCache) {
        error.value = ApiResponseUtils.errorMessage(e) ?? 'Error al cargar nómina';
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _applySnapshot(Map<String, dynamic> obj) {
    items.value = ((obj['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PayrollEntry.fromJson)
        .toList();
    totalNet.value = moneyToDouble(obj['total_net']);
    totalPaid.value = moneyToDouble(obj['total_paid']);
    totalPending.value = moneyToDouble(obj['total_pending']);
  }

  Future<bool> save({
    String? id,
    String? userId,
    required String employeeName,
    required String periodLabel,
    required double baseAmount,
    double additions = 0,
    double deductions = 0,
    bool isPaid = false,
    String? notes,
    PayFrequency payFrequency = PayFrequency.monthly,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final data = {
        if (userId != null) 'user_id': userId,
        'employee_name': employeeName.trim(),
        'period_label': periodLabel.trim(),
        'base_amount': baseAmount,
        'additions': additions,
        'deductions': deductions,
        'is_paid': isPaid,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'pay_frequency': payFrequency.apiValue,
        if (periodStart != null) 'period_start': _isoDate(periodStart),
        if (periodEnd != null) 'period_end': _isoDate(periodEnd),
      };
      if (id == null) {
        await _dio.post('/payroll', data: data);
      } else {
        await _dio.patch('/payroll/$id', data: data);
      }
      await load();
      return true;
    } catch (e) {
      AppSnackbar.show(
        'No se pudo guardar',
        ApiResponseUtils.errorMessage(e) ?? 'Error',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Marca pagado / pendiente (optimista).
  Future<void> togglePaid(PayrollEntry entry) async {
    final idx = items.indexWhere((e) => e.id == entry.id);
    if (idx == -1) return;
    try {
      await _dio.patch('/payroll/${entry.id}', data: {'is_paid': !entry.isPaid});
      await load();
    } catch (e) {
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }

  Future<void> remove(PayrollEntry entry) async {
    final idx = items.indexWhere((e) => e.id == entry.id);
    if (idx == -1) return;
    final removed = items.removeAt(idx);
    try {
      await _dio.delete('/payroll/${entry.id}');
      await load();
    } catch (e) {
      items.insert(idx, removed);
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }
}
