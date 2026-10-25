import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../core/utils/api_response_utils.dart';
import '../domain/entities/ingredient.dart';
import '../domain/entities/ingredient_movement.dart';
import '../domain/entities/recipe_line.dart';
import 'pending_inventory_overlay.dart';

/// Resultado de una operación que puede quedar en la cola sin internet.
class InventoryWriteResult {
  /// Se aplicó en el servidor (con internet).
  final bool synced;
  const InventoryWriteResult({required this.synced});
}

/// Inventario por insumos + recetas, local-first:
///  - LECTURA: siempre de la caché del dispositivo (instantánea), con la
///    cola offline aplicada encima (`applyPendingInventory`). La red solo
///    refresca esa caché.
///  - ESCRITURA: con internet va directo; sin internet se encola y se
///    manda sola al reconectar (`AppSyncService`). Las operaciones de
///    stock llevan `client_request_id`, así un reintento no duplica.
class InventoryRepository {
  static const ingredientsKey = 'inventory_ingredients';
  static const recipesKey = 'inventory_recipes';

  /// Copia liviana de los extras (`{id, name, price}`) para nombrarlos en
  /// "se usa en…" y en costos sin internet.
  static const modifiersKey = 'inventory_modifiers';
  static String movementsKey(String? ingredientId) =>
      'inventory_movements_${ingredientId ?? 'all'}';

  final Dio dio;
  final NetworkInfo networkInfo;
  final LocalCacheService cache;
  final OfflineQueueService queue;

  InventoryRepository({
    required this.dio,
    required this.networkInfo,
    required this.cache,
    required this.queue,
  });

  // ─────────────────────────── Lectura ───────────────────────────

  /// Copia local + cola offline, sin tocar la red.
  InventoryOverlay readLocal() {
    final ingredients = (cache.getList(ingredientsKey) ?? const [])
        .map(Ingredient.fromJson)
        .toList();
    final recipes =
        (cache.getList(recipesKey) ?? const []).map(RecipeLine.fromJson).toList();
    return applyPendingInventory(
      ingredients: ingredients,
      recipes: recipes,
      // Ids locales de algo ya sincronizado → id real, igual que al
      // reproducir la cola (si no, un ajuste a un insumo creado offline
      // se "perdería" de la vista apenas el alta sincroniza).
      queue: queue.getAll().map(queue.remapEntry),
    );
  }

  bool get hasLocalData => cache.getList(ingredientsKey) != null;

  /// Extras conocidos (id → nombre, precio), de la última copia local.
  Map<String, ({String name, double price})> readModifiers() {
    final out = <String, ({String name, double price})>{};
    for (final m in cache.getList(modifiersKey) ?? const <Map<String, dynamic>>[]) {
      final id = m['id'];
      if (id is! String) continue;
      final p = m['price'];
      out[id] = (
        name: m['name'] as String? ?? 'Extra',
        price: p is num ? p.toDouble() : double.tryParse('$p') ?? 0,
      );
    }
    return out;
  }

  /// Trae insumos y recetas del servidor y actualiza la caché. `Left` si
  /// no hay red o falló — la UI sigue con lo local.
  Future<Either<Failure, void>> refresh() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final results = await Future.wait([
        dio.get(InventoryPaths.ingredients),
        dio.get(InventoryPaths.recipes),
      ]);
      await cache.saveList(
        ingredientsKey,
        ApiResponseUtils.list(results[0]).whereType<Map<String, dynamic>>().toList(),
      );
      await cache.saveList(
        recipesKey,
        ApiResponseUtils.list(results[1]).whereType<Map<String, dynamic>>().toList(),
      );
      // Extras: no es crítico — si falla, el inventario igual queda al día.
      try {
        final mods = await dio.get('/products/modifiers/all');
        await cache.saveList(modifiersKey, [
          for (final m in ApiResponseUtils.list(mods).whereType<Map<String, dynamic>>())
            {'id': m['id'], 'name': m['name'], 'price': m['price']},
        ]);
      } on DioException catch (_) {}
      return const Right(null);
    } on DioException catch (e) {
      return Left(_failure(e));
    }
  }

  /// Historial: del servidor si hay red (y se guarda), si no la última
  /// copia. Los movimientos todavía en cola se agregan arriba.
  Future<List<IngredientMovement>> movements({String? ingredientId, int limit = 100}) async {
    final key = movementsKey(ingredientId);
    List<IngredientMovement> list =
        (cache.getList(key) ?? const []).map(IngredientMovement.fromJson).toList();
    if (await networkInfo.isConnected) {
      try {
        final res = await dio.get(InventoryPaths.movements, queryParameters: {
          if (ingredientId != null) 'ingredient_id': ingredientId,
          'limit': limit,
        });
        final raw = ApiResponseUtils.list(res).whereType<Map<String, dynamic>>().toList();
        await cache.saveList(key, raw);
        list = raw.map(IngredientMovement.fromJson).toList();
      } on DioException catch (_) {
        // Sin red útil: queda la copia local.
      }
    }
    final pending = readLocal()
        .pendingMovements
        .where((m) => ingredientId == null || m.ingredientId == ingredientId);
    return [...pending, ...list];
  }

  // ─────────────────────────── Insumos ───────────────────────────

  Future<Either<Failure, Ingredient>> createIngredient({
    required String name,
    required IngredientUnit unit,
    double? minStock,
    double? initialStock,
    double? unitCost,
    String? category,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'unit': unit.code,
      if (minStock != null) 'min_stock': minStock,
      if (initialStock != null && initialStock != 0) 'initial_stock': initialStock,
      if (unitCost != null) 'unit_cost': unitCost,
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
    };
    if (await networkInfo.isConnected) {
      try {
        final res = await dio.post(InventoryPaths.ingredients, data: body);
        final created = Ingredient.fromJson(ApiResponseUtils.object(res));
        await _upsertCachedIngredients([created]);
        return Right(created);
      } on DioException catch (e) {
        if (!_isConnectionError(e)) return Left(_failure(e));
      }
    }
    final localId = 'local_ing_${DateTime.now().microsecondsSinceEpoch}';
    await enqueueCreateEntity(
      queue,
      method: 'POST',
      path: InventoryPaths.ingredients,
      body: body,
      localId: localId,
    );
    return Right(readLocal().ingredients.firstWhere(
          (i) => i.id == localId,
          orElse: () => Ingredient(
            id: localId,
            name: name.trim(),
            unit: unit,
            currentStock: initialStock ?? 0,
            minStock: minStock ?? 0,
            avgCost: unitCost ?? 0,
            category: category,
          ),
        ));
  }

  Future<Either<Failure, InventoryWriteResult>> updateIngredient(
    String id,
    Map<String, dynamic> changes,
  ) {
    return _write(
      method: 'PATCH',
      path: InventoryPaths.ingredient(id),
      body: changes,
      onSuccess: (res) async =>
          _upsertCachedIngredients([Ingredient.fromJson(ApiResponseUtils.object(res))]),
    );
  }

  Future<Either<Failure, InventoryWriteResult>> deleteIngredient(String id) {
    return _write(
      method: 'DELETE',
      path: InventoryPaths.ingredient(id),
      onSuccess: (_) async {
        final list = cache.getList(ingredientsKey) ?? [];
        await cache.saveList(ingredientsKey, list.where((j) => j['id'] != id).toList());
        final recipes = cache.getList(recipesKey) ?? [];
        await cache.saveList(
          recipesKey,
          recipes.where((j) => j['ingredient_id'] != id).toList(),
        );
      },
    );
  }

  // ─────────────────────────── Recetas ───────────────────────────

  Future<Either<Failure, InventoryWriteResult>> setRecipe({
    required RecipeOwnerType ownerType,
    required String ownerId,
    required List<({String ingredientId, double quantity})> lines,
  }) {
    final body = {
      'owner_type': ownerType.code,
      'owner_id': ownerId,
      'items': [
        for (final l in lines)
          if (l.quantity > 0) {'ingredient_id': l.ingredientId, 'quantity': l.quantity},
      ],
    };
    return _write(
      method: 'PUT',
      path: InventoryPaths.recipes,
      body: body,
      onSuccess: (res) async {
        final ownerKey = '${ownerType.code}_id';
        final rest = (cache.getList(recipesKey) ?? [])
            .where((j) => j[ownerKey] != ownerId)
            .toList();
        final saved = ApiResponseUtils.list(res).whereType<Map<String, dynamic>>();
        await cache.saveList(recipesKey, [...rest, ...saved]);
      },
    );
  }

  // ─────────────────── Operaciones de stock ───────────────────

  Future<Either<Failure, InventoryWriteResult>> purchase({
    required List<({String ingredientId, double quantity, double? unitCost})> lines,
    String? supplier,
    String? invoiceNumber,
    String? notes,
  }) {
    return _stockOperation(InventoryPaths.purchases, {
      if (supplier != null && supplier.trim().isNotEmpty) 'supplier': supplier.trim(),
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoice_number': invoiceNumber.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'lines': [
        for (final l in lines)
          {
            'ingredient_id': l.ingredientId,
            'quantity': l.quantity,
            if (l.unitCost != null) 'unit_cost': l.unitCost,
          },
      ],
    });
  }

  Future<Either<Failure, InventoryWriteResult>> waste({
    required List<({String ingredientId, double quantity, String? reason})> lines,
    String? notes,
  }) {
    return _stockOperation(InventoryPaths.waste, {
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'lines': [
        for (final l in lines)
          {
            'ingredient_id': l.ingredientId,
            'quantity': l.quantity,
            if (l.reason != null && l.reason!.isNotEmpty) 'reason': l.reason,
          },
      ],
    });
  }

  Future<Either<Failure, InventoryWriteResult>> adjust({
    required String ingredientId,
    required double delta,
    String? notes,
  }) {
    return _stockOperation(InventoryPaths.adjustments, {
      'ingredient_id': ingredientId,
      'delta': delta,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  /// [lines]: `expected` = lo que el dispositivo mostraba al contar (ver
  /// `CountLineDto.expected` en el backend).
  Future<Either<Failure, InventoryWriteResult>> count({
    required List<({String ingredientId, double counted, double expected})> lines,
    String? notes,
  }) {
    return _stockOperation(InventoryPaths.counts, {
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'lines': [
        for (final l in lines)
          {'ingredient_id': l.ingredientId, 'counted': l.counted, 'expected': l.expected},
      ],
    });
  }

  Future<Either<Failure, InventoryWriteResult>> _stockOperation(
    String path,
    Map<String, dynamic> body,
  ) {
    return _write(
      method: 'POST',
      path: path,
      body: {...body, 'client_request_id': const Uuid().v4()},
      onSuccess: (res) async {
        final data = ApiResponseUtils.object(res);
        final changed = (data['ingredients'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Ingredient.fromJson)
            .toList();
        await _upsertCachedIngredients(changed);
      },
    );
  }

  // ─────────────────────────── Internos ───────────────────────────

  /// Con internet manda y aplica [onSuccess] a la caché; sin internet (o
  /// si se cae justo) lo encola tal cual. Errores de validación del
  /// servidor (400/404/409) se devuelven: reintentarlos no los arregla.
  Future<Either<Failure, InventoryWriteResult>> _write({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required Future<void> Function(Response res) onSuccess,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final res = await dio.request(path, data: body, options: Options(method: method));
        await onSuccess(res);
        return const Right(InventoryWriteResult(synced: true));
      } on DioException catch (e) {
        if (!_isConnectionError(e)) return Left(_failure(e));
      }
    }
    await enqueueGenericMutation(queue, method: method, path: path, body: body);
    return const Right(InventoryWriteResult(synced: false));
  }

  Future<void> _upsertCachedIngredients(List<Ingredient> changed) async {
    if (changed.isEmpty) return;
    final list = List<Map<String, dynamic>>.from(cache.getList(ingredientsKey) ?? const []);
    for (final ing in changed) {
      final i = list.indexWhere((j) => j['id'] == ing.id);
      if (i >= 0) {
        list[i] = ing.toJson();
      } else {
        list.add(ing.toJson());
      }
    }
    list.sort((a, b) => (a['name'] as String? ?? '')
        .toLowerCase()
        .compareTo((b['name'] as String? ?? '').toLowerCase()));
    await cache.saveList(ingredientsKey, list);
  }

  bool _isConnectionError(DioException e) =>
      e.response == null &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown);

  Failure _failure(DioException e) {
    final status = e.response?.statusCode;
    final msg = ApiResponseUtils.errorMessage(e) ?? 'No se pudo completar la operación';
    if (status == 401) return const UnauthorizedFailure();
    if (status == 404) return NotFoundFailure(msg);
    if (status == 400 || status == 409 || status == 422) return ValidationFailure(msg);
    if (e.response == null) return NetworkFailure(msg);
    return ServerFailure(msg);
  }
}
