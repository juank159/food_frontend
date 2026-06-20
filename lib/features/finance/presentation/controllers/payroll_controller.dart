import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import 'expenses_controller.dart' show moneyToDouble;

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
      );
}

/// Controller de nómina. Dio directo. Endpoints `/payroll`.
class PayrollController extends GetxController {
  late final Dio _dio;

  final RxList<PayrollEntry> items = <PayrollEntry>[].obs;
  final RxDouble totalNet = 0.0.obs;
  final RxDouble totalPaid = 0.0.obs;
  final RxDouble totalPending = 0.0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _dio = GetIt.I<Dio>();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      final res = await _dio.get('/payroll');
      final obj = ApiResponseUtils.object(res);
      items.value = ((obj['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PayrollEntry.fromJson)
          .toList();
      totalNet.value = moneyToDouble(obj['total_net']);
      totalPaid.value = moneyToDouble(obj['total_paid']);
      totalPending.value = moneyToDouble(obj['total_pending']);
    } catch (e) {
      error.value =
          ApiResponseUtils.errorMessage(e) ?? 'Error al cargar nómina';
    } finally {
      isLoading.value = false;
    }
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
