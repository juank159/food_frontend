import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/local_cache_service.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Item de la lista de compras / checklist.
class ChecklistItem {
  final String id;
  final String text;
  final bool isDone;

  const ChecklistItem({
    required this.id,
    required this.text,
    required this.isDone,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        text: (json['text'] as String?) ?? '',
        isDone: (json['is_done'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'is_done': isDone};
}

/// Controller de la checklist ("lo que hace falta comprar"). Usa Dio
/// directo (patrón simple, como BusinessSettings). Endpoints `/checklist`.
class ChecklistController extends GetxController {
  late final Dio _dio;
  late final LocalCacheService _cache;

  final RxList<ChecklistItem> items = <ChecklistItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;

  int get pendingCount => items.where((i) => !i.isDone).length;
  int get doneCount => items.where((i) => i.isDone).length;

  @override
  void onInit() {
    super.onInit();
    _dio = GetIt.I<Dio>();
    _cache = GetIt.I<LocalCacheService>();
    load();
  }

  /// Local-first (mismo patrón que products/categories/etc.): pinta la
  /// lista cacheada al instante antes de esperar la red.
  Future<void> load() async {
    final cachedRaw = _cache.getList(CacheKeys.checklist);
    final cached = cachedRaw
        ?.map(ChecklistItem.fromJson)
        .toList();
    final paintedFromCache = cached != null && cached.isNotEmpty;
    if (paintedFromCache) items.value = cached;

    isLoading.value = !paintedFromCache;
    error.value = '';
    try {
      final res = await _dio.get('/checklist');
      final list = ApiResponseUtils.list(res)
          .whereType<Map<String, dynamic>>()
          .map(ChecklistItem.fromJson)
          .toList();
      items.value = list;
      await _cache.saveList(
        CacheKeys.checklist,
        list.map((i) => i.toJson()).toList(),
      );
    } catch (e) {
      if (!paintedFromCache) {
        error.value = ApiResponseUtils.errorMessage(e) ?? 'Error';
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty || isSaving.value) return;
    isSaving.value = true;
    try {
      final res = await _dio.post('/checklist', data: {'text': t});
      final item = ChecklistItem.fromJson(ApiResponseUtils.object(res));
      // Pendiente nuevo arriba (la lista va pendientes primero, recientes
      // arriba — coincide con el orden del backend).
      items.insert(0, item);
    } catch (e) {
      AppSnackbar.show('No se pudo agregar', ApiResponseUtils.errorMessage(e) ?? 'Error');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggle(ChecklistItem item) async {
    // Optimista: reflejamos el cambio y revertimos si falla.
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    final optimistic = ChecklistItem(
      id: item.id,
      text: item.text,
      isDone: !item.isDone,
    );
    items[idx] = optimistic;
    try {
      await _dio.patch('/checklist/${item.id}', data: {'is_done': !item.isDone});
      await load(); // re-ordena (comprados al fondo)
    } catch (e) {
      items[idx] = item; // revertir
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }

  Future<void> remove(ChecklistItem item) async {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    final removed = items.removeAt(idx);
    try {
      await _dio.delete('/checklist/${item.id}');
    } catch (e) {
      items.insert(idx, removed); // revertir
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }

  Future<void> clearCompleted() async {
    if (doneCount == 0) return;
    try {
      await _dio.delete('/checklist/completed');
      items.removeWhere((i) => i.isDone);
    } catch (e) {
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }
}
