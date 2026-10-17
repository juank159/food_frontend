import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/features/tab_sessions/domain/entities/tab_session.dart';
import 'package:menu_plat/features/tab_sessions/domain/repositories/tab_session_repository.dart';
import 'package:menu_plat/features/tab_sessions/domain/usecases/tab_session_usecases.dart';
import 'package:menu_plat/features/tab_sessions/presentation/controllers/open_tabs_controller.dart';

TabSession _tab(String id) => TabSession(
      id: id,
      openedBy: 'user-1',
      openedAt: DateTime(2026, 1, 1),
      status: TabSessionStatus.open,
      totalOrders: 1,
      subtotal: 10000,
      taxAmount: 0,
      discountAmount: 0,
      tipAmount: 0,
      deliveryFee: 0,
      totalAmount: 10000,
      paidAmount: 0,
      balance: 10000,
    );

class _UnusedRepo implements TabSessionRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUseCases implements TabSessionUseCases {
  Either<Failure, List<TabSession>> findOpenResult = const Right(<TabSession>[]);
  List<TabSession>? peekResult;
  Duration delay = Duration.zero;

  @override
  TabSessionRepository get repository => _UnusedRepo();

  @override
  Future<Either<Failure, List<TabSession>>> findOpen() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return findOpenResult;
  }

  @override
  Future<List<TabSession>?> getCachedOpenTabsPeek() async => peekResult;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _FakeUseCases useCases;
  late OpenTabsController controller;

  setUp(() {
    useCases = _FakeUseCases();
    controller = OpenTabsController(useCases: useCases);
  });

  test(
    'local-first: pinta las cuentas cacheadas de inmediato, antes de la red',
    () async {
      useCases.peekResult = [_tab('cached-1')];
      useCases.findOpenResult = Right([_tab('fresh-1')]);
      useCases.delay = const Duration(milliseconds: 20);

      final future = controller.load();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(controller.sessions.map((s) => s.id), ['cached-1']);
      expect(controller.isLoading.value, isFalse);

      await future;
      expect(controller.sessions.map((s) => s.id), ['fresh-1']);
    },
  );

  test('sin caché: muestra loading hasta que responda la red', () async {
    useCases.peekResult = null;
    useCases.findOpenResult = Right([_tab('fresh-1')]);

    await controller.load();

    expect(controller.sessions.map((s) => s.id), ['fresh-1']);
  });

  test(
    'si ya pintó del caché y la red falla, no borra lo pintado ni muestra error',
    () async {
      useCases.peekResult = [_tab('cached-1')];
      useCases.findOpenResult = const Left(NetworkFailure());

      await controller.load();

      expect(controller.sessions.map((s) => s.id), ['cached-1']);
      expect(controller.errorMessage.value, isEmpty);
    },
  );
}
