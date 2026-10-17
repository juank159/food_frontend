import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/features/categories/domain/entities/category.dart';
import 'package:menu_plat/features/categories/domain/repositories/category_repository.dart';
import 'package:menu_plat/features/categories/domain/usecases/get_active_categories_usecase.dart';
import 'package:menu_plat/features/categories/domain/usecases/get_cached_categories_peek_usecase.dart';
import 'package:menu_plat/features/categories/domain/usecases/get_categories_usecase.dart';
import 'package:menu_plat/features/categories/domain/usecases/get_category_by_id_usecase.dart';
import 'package:menu_plat/features/categories/domain/usecases/get_category_tree_usecase.dart';
import 'package:menu_plat/features/categories/presentation/controllers/categories_controller.dart';

Category _category(String id, {bool isActive = true}) => Category(
      id: id,
      name: 'Categoría $id',
      description: '',
      isActive: isActive,
      displayOrder: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

class _UnusedRepo implements CategoryRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGetCategories implements GetCategoriesUseCase {
  Either<Failure, List<Category>> result = Right(<Category>[]);
  Duration delay = Duration.zero;
  bool? lastIsActive;
  String? lastSearch;

  @override
  CategoryRepository get repository => _UnusedRepo();

  @override
  Future<Either<Failure, List<Category>>> call({
    bool? isActive,
    String? search,
    int? page,
    int? limit,
  }) async {
    lastIsActive = isActive;
    lastSearch = search;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

class _FakeGetCachedPeek implements GetCachedCategoriesPeekUseCase {
  List<Category>? result;

  @override
  CategoryRepository get repository => _UnusedRepo();

  @override
  Future<List<Category>?> call() async => result;
}

void main() {
  late _FakeGetCategories getCategories;
  late _FakeGetCachedPeek getCachedPeek;
  late CategoriesController controller;

  setUp(() {
    getCategories = _FakeGetCategories();
    getCachedPeek = _FakeGetCachedPeek();
    controller = CategoriesController(
      getCategoriesUseCase: getCategories,
      getCategoryTreeUseCase: GetCategoryTreeUseCase(_UnusedRepo()),
      getActiveCategoriesUseCase: GetActiveCategoriesUseCase(_UnusedRepo()),
      getCategoryByIdUseCase: GetCategoryByIdUseCase(_UnusedRepo()),
      getCachedCategoriesPeekUseCase: getCachedPeek,
    );
  });

  test(
    'local-first: pinta el caché completo filtrado por isActive antes de que responda la red',
    () async {
      getCachedPeek.result = [
        _category('activa-1', isActive: true),
        _category('inactiva-1', isActive: false),
      ];
      getCategories.result = Right([_category('fresh-1')]);
      getCategories.delay = const Duration(milliseconds: 20);

      // showOnlyActive arranca en true (default) → debe filtrar el peek.
      final future = controller.loadCategories();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        controller.categories.map((c) => c.id),
        ['activa-1'], // la inactiva queda afuera del pintado instantáneo
      );
      expect(controller.isLoading.value, isFalse);

      await future;
      expect(controller.categories.map((c) => c.id), ['fresh-1']);
    },
  );

  test('sin caché: muestra loading hasta que responda la red', () async {
    getCachedPeek.result = null;
    getCategories.result = Right([_category('fresh-1')]);

    await controller.loadCategories();

    expect(controller.categories.map((c) => c.id), ['fresh-1']);
  });

  test(
    'si ya pintó del caché y la red falla, no borra lo pintado ni muestra error',
    () async {
      getCachedPeek.result = [_category('activa-1')];
      getCategories.result = const Left(NetworkFailure());

      await controller.loadCategories();

      expect(controller.categories.map((c) => c.id), ['activa-1']);
      expect(controller.errorMessage.value, isEmpty);
    },
  );

  test('con búsqueda de texto: no usa el peek de caché', () async {
    getCachedPeek.result = [_category('activa-1')];
    getCategories.result = Right([_category('search-result')]);

    await controller.loadCategories(search: 'bebidas');

    expect(controller.categories.map((c) => c.id), ['search-result']);
    expect(getCategories.lastSearch, 'bebidas');
  });
}
