import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../../../core/services/offline_queue_service.dart';
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
  late final NetworkInfo _networkInfo;
  late final OfflineQueueService _offlineQueue;

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
    _networkInfo = GetIt.I<NetworkInfo>();
    _offlineQueue = GetIt.I<OfflineQueueService>();
    load();
  }

  Future<void> _persistCache() async {
    await _cache.saveList(
      CacheKeys.checklist,
      items.map((i) => i.toJson()).toList(),
    );
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

  /// Bug real reportado (pedido explícito: que funcione con o sin
  /// internet): esto solo intentaba la red — sin conexión, agregar un
  /// item fallaba con un snackbar de error. Igual que productos/
  /// pedidos, sin conexión se agrega optimista con un id local y se
  /// encola la creación (`createEntity` — si más adelante se marca o
  /// borra ESE mismo item antes de sincronizar, el id local en esas
  /// otras entradas de la cola se resuelve solo al id real).
  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty || isSaving.value) return;
    isSaving.value = true;
    try {
      if (!await _networkInfo.isConnected) {
        final localId = 'local_chk_${DateTime.now().microsecondsSinceEpoch}';
        final item = ChecklistItem(id: localId, text: t, isDone: false);
        items.insert(0, item);
        await _persistCache();
        await enqueueCreateEntity(
          _offlineQueue,
          method: 'POST',
          path: '/checklist',
          body: {'text': t},
          localId: localId,
        );
        return;
      }
      final res = await _dio.post('/checklist', data: {'text': t});
      final item = ChecklistItem.fromJson(ApiResponseUtils.object(res));
      // Pendiente nuevo arriba (la lista va pendientes primero, recientes
      // arriba — coincide con el orden del backend).
      items.insert(0, item);
      await _persistCache();
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
    await _persistCache();

    if (!await _networkInfo.isConnected) {
      // `genericMutation` con el id tal cual (puede ser `local_...` si
      // el item mismo se creó offline) — el remap de la cola lo
      // resuelve solo al sincronizar, en orden, antes de este PATCH.
      await enqueueGenericMutation(
        _offlineQueue,
        method: 'PATCH',
        path: '/checklist/${item.id}',
        body: {'is_done': !item.isDone},
      );
      return;
    }

    try {
      await _dio.patch('/checklist/${item.id}', data: {'is_done': !item.isDone});
      await load(); // re-ordena (comprados al fondo)
    } catch (e) {
      items[idx] = item; // revertir
      await _persistCache();
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }

  Future<void> remove(ChecklistItem item) async {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    final removed = items.removeAt(idx);
    await _persistCache();

    if (!await _networkInfo.isConnected) {
      // Mismo criterio que `toggle`: el id (local o real) se resuelve
      // solo al sincronizar, en el orden en que se encoló. Si el item
      // se había creado offline y se borra offline también, el efecto
      // final en el servidor es "se creó y se borró" — correcto.
      await enqueueGenericMutation(
        _offlineQueue,
        method: 'DELETE',
        path: '/checklist/${item.id}',
      );
      return;
    }

    try {
      await _dio.delete('/checklist/${item.id}');
    } catch (e) {
      items.insert(idx, removed); // revertir
      await _persistCache();
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }

  Future<void> clearCompleted() async {
    if (doneCount == 0) return;
    final removedItems = items.where((i) => i.isDone).toList();
    items.removeWhere((i) => i.isDone);
    await _persistCache();

    if (!await _networkInfo.isConnected) {
      await enqueueGenericMutation(
        _offlineQueue,
        method: 'DELETE',
        path: '/checklist/completed',
      );
      return;
    }

    try {
      await _dio.delete('/checklist/completed');
    } catch (e) {
      items.addAll(removedItems); // revertir
      await _persistCache();
      AppSnackbar.show('Error', ApiResponseUtils.errorMessage(e) ?? 'Error');
    }
  }
}
