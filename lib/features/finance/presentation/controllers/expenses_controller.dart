import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../../../core/services/offline_queue_service.dart';
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
  final String paymentSource;
  final DateTime expenseDate;
  final String? notes;

  const Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.paymentSource,
    required this.expenseDate,
    this.notes,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        description: (json['description'] as String?) ?? '',
        category: (json['category'] as String?) ?? 'other',
        amount: moneyToDouble(json['amount']),
        paymentSource:
            (json['payment_source'] as String?) ?? 'cash_register',
        expenseDate:
            DateTime.tryParse(json['expense_date']?.toString() ?? '') ??
                DateTime.now(),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'category': category,
        'amount': amount,
        'payment_source': paymentSource,
        'expense_date': expenseDate.toUtc().toIso8601String(),
        'notes': notes,
      };
}

/// Fuentes de pago (deben coincidir con EXPENSE_PAYMENT_SOURCES del backend).
/// Solo 'cash_register' afecta el cuadre de caja; el resto son egresos contables.
const Map<String, String> kExpensePaymentSourceLabels = {
  'cash_register': 'Caja',
  'bank_account': 'Cuenta bancaria',
  'petty_cash': 'Caja menor',
  'credit_card': 'Tarjeta',
  'personal': 'Efectivo propio',
};

IconData expensePaymentSourceIcon(String source) {
  switch (source) {
    case 'cash_register':
      return Icons.point_of_sale;
    case 'bank_account':
      return Icons.account_balance;
    case 'petty_cash':
      return Icons.wallet;
    case 'credit_card':
      return Icons.credit_card;
    case 'personal':
      return Icons.person_outline;
    default:
      return Icons.payments_outlined;
  }
}

String expensePaymentSourceLabel(String code) =>
    kExpensePaymentSourceLabels[code] ?? code;

/// Etiquetas legibles de categorías (deben coincidir con EXPENSE_CATEGORIES
/// del backend).
const Map<String, String> kExpenseCategoryLabels = {
  'rent': 'Arriendo',
  'utilities': 'Servicios',
  'supplies': 'Insumos',
  'inventory_purchase': 'Pago a proveedor',
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
  late final LocalCacheService _cache;
  late final OfflineQueueService _queue;
  late final NetworkInfo _networkInfo;

  final RxList<Expense> items = <Expense>[].obs;
  final RxDouble total = 0.0.obs;
  final RxMap<String, double> byCategory = <String, double>{}.obs;
  final Rx<DatePeriod> period = DatePeriod.thisMonth.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  String get _cacheKey => 'expenses_${period.value.name}';

  @override
  void onInit() {
    super.onInit();
    _dio = GetIt.I<Dio>();
    _cache = GetIt.I<LocalCacheService>();
    _queue = GetIt.I<OfflineQueueService>();
    _networkInfo = GetIt.I<NetworkInfo>();
    load();
  }

  void setPeriod(DatePeriod p) {
    if (p == period.value) return;
    period.value = p;
    load();
  }

  /// Local-first (mismo patrón que el resto): pinta lo cacheado de
  /// ESTE período al instante, refresca atrás sin bloquear.
  Future<void> load() async {
    final cachedRaw = _cache.getObject(_cacheKey);
    final paintedFromCache = cachedRaw != null;
    if (paintedFromCache) _applySnapshot(cachedRaw);

    isLoading.value = !paintedFromCache;
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
      _applySnapshot(obj);
      await _cache.saveObject(_cacheKey, {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total.value,
        'by_category': Map<String, dynamic>.from(byCategory),
      });
    } catch (e) {
      if (!paintedFromCache) {
        error.value = ApiResponseUtils.errorMessage(e) ?? 'Error al cargar gastos';
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _applySnapshot(Map<String, dynamic> obj) {
    items.value = ((obj['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Expense.fromJson)
        .toList();
    total.value = moneyToDouble(obj['total']);
    final cats = (obj['by_category'] as Map?) ?? const {};
    byCategory.value = cats.map(
      (k, v) => MapEntry(k.toString(), moneyToDouble(v)),
    );
  }

  /// Sin conexión, SOLO para crear (id == null): encola el gasto y lo
  /// refleja de inmediato como optimista. Igual que shifts, un gasto
  /// es un registro hoja — nada más lo va a referenciar antes de
  /// sincronizar, así que es seguro encolarlo (a diferencia de crear
  /// un producto o abrir una cuenta). Editar/borrar un gasto existente
  /// sigue requiriendo conexión — son acciones poco frecuentes y de
  /// bajo valor para la complejidad de encolarlas.
  Future<bool> save({
    String? id,
    required String description,
    required String category,
    required double amount,
    required String paymentSource,
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
        'payment_source': paymentSource,
        'expense_date': expenseDate.toUtc().toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

      if (id == null && !await _networkInfo.isConnected) {
        final optimistic = Expense(
          id: 'local_${const Uuid().v4()}',
          description: description.trim(),
          category: category,
          amount: amount,
          paymentSource: paymentSource,
          expenseDate: expenseDate,
          notes: notes,
        );
        items.insert(0, optimistic);
        total.value += amount;
        byCategory[category] = (byCategory[category] ?? 0) + amount;
        await _queue.enqueue(QueueEntry(
          id: const Uuid().v4(),
          type: QueueOperationType.createExpense,
          payload: data,
          createdAt: DateTime.now(),
        ));
        AppSnackbar.show(
          'Guardado sin conexión',
          'Se va a enviar al servidor cuando vuelva la señal.',
        );
        return true;
      }

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
