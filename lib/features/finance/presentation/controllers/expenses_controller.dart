import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/date_period.dart';

/// Convierte a double tolerando String (Postgres manda decimal como texto),
/// num o null.
double moneyToDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Gasto del negocio (egreso).
class Expense {
  final String id;
  final String description;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String? notes;

  const Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.notes,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        description: (json['description'] as String?) ?? '',
        category: (json['category'] as String?) ?? 'other',
        amount: moneyToDouble(json['amount']),
        expenseDate:
            DateTime.tryParse(json['expense_date']?.toString() ?? '') ??
                DateTime.now(),
        notes: json['notes'] as String?,
      );
}

/// Etiquetas legibles de categorías (deben coincidir con EXPENSE_CATEGORIES
/// del backend).
const Map<String, String> kExpenseCategoryLabels = {
  'rent': 'Arriendo',
  'utilities': 'Servicios',
  'supplies': 'Insumos',
  'equipment': 'Equipos',
  'maintenance': 'Mantenimiento',
  'marketing': 'Marketing',
  'transport': 'Transporte',
  'taxes': 'Impuestos',
  'services': 'Servicios prof.',
  'payroll': 'Pago a personal',
  'other': 'Otros',
};

String expenseCategoryLabel(String code) =>
    kExpenseCategoryLabels[code] ?? code;

/// Controller de gastos. Dio directo (patrón checklist). Endpoints `/expenses`.
class ExpensesController extends GetxController {
  late final Dio _dio;

  final RxList<Expense> items = <Expense>[].obs;
  final RxDouble total = 0.0.obs;
  final RxMap<String, double> byCategory = <String, double>{}.obs;
  final Rx<DatePeriod> period = DatePeriod.thisMonth.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _dio = GetIt.I<Dio>();
    load();
  }

  void setPeriod(DatePeriod p) {
    if (p == period.value) return;
    period.value = p;
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      final range = resolveDatePeriod(period.value);
      final qp = <String, dynamic>{};
      if (range.start != null && range.end != null) {
        qp['date_from'] = range.start!.toUtc().toIso8601String();
        qp['date_to'] = range.end!.toUtc().toIso8601String();
      }
      final res = await _dio.get('/expenses', queryParameters: qp);
      final obj = ApiResponseUtils.object(res);
      items.value = ((obj['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Expense.fromJson)
          .toList();
      total.value = moneyToDouble(obj['total']);
      final cats = (obj['by_category'] as Map?) ?? const {};
      byCategory.value = cats.map(
        (k, v) => MapEntry(k.toString(), moneyToDouble(v)),
      );
    } catch (e) {
      error.value = ApiResponseUtils.errorMessage(e) ?? 'Error al cargar gastos';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> save({
    String? id,
    required String description,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? notes,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final data = {
        'description': description.trim(),
        'category': category,
        'amount': amount,
        'expense_date': expenseDate.toUtc().toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
      if (id == null) {
        await _dio.post('/expenses', data: data);
      } else {
        await _dio.patch('/expenses/$id', data: data);
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

  Future<void> remove(Expense expense) async {
    final idx = items.indexWhere((e) => e.id == expense.id);
    if (idx == -1) return;
    final removed = items.removeAt(idx);
    total.value -= removed.amount;
    try {
      await _dio.delete('/expenses/${expense.id}');
      await load();
    } catch (e) {
      items.insert(idx, removed);
      total.value += removed.amount;
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }
}
