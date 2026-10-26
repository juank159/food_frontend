import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/branch/branch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dio falso: responde `/branches/mine` con [mine], o falla (sin red).
Dio _dio({List<Map<String, dynamic>>? mine}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (mine == null) {
      return h.reject(DioException(requestOptions: o, type: DioExceptionType.connectionError));
    }
    return h.resolve(Response(requestOptions: o, statusCode: 200, data: mine));
  }));
  return dio;
}

Map<String, dynamic> _b(String id, {bool def = false}) =>
    {'id': id, 'name': 'Sede $id', 'is_active': true, 'is_default': def};

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('dispositivo nuevo en negocio con varias sedes: pone la principal y pide confirmar', () async {
    final s = BranchService(prefs: prefs)..restore('t1');
    await s.refresh(_dio(mine: [_b('a'), _b('b', def: true)]), roleCode: 'cashier');
    expect(s.current.value?.id, 'b');
    expect(s.needsChoice.value, isTrue);
    expect(s.isMulti, isTrue);
  });

  test('una sola sede: no pide nada', () async {
    final s = BranchService(prefs: prefs)..restore('t1');
    await s.refresh(_dio(mine: [_b('a', def: true)]), roleCode: 'admin');
    expect(s.current.value?.id, 'a');
    expect(s.needsChoice.value, isFalse);
    expect(s.isMulti, isFalse);
  });

  test('el dispositivo recuerda su sede (por negocio) y sin red no la pierde', () async {
    final s = BranchService(prefs: prefs)..restore('t1');
    await s.refresh(_dio(mine: [_b('a'), _b('b')]), roleCode: 'admin');
    await s.select(s.mine.firstWhere((b) => b.id == 'a'));

    final again = BranchService(prefs: prefs)..restore('t1');
    expect(again.current.value?.id, 'a');
    await again.refresh(_dio(), roleCode: 'admin'); // sin red
    expect(again.current.value?.id, 'a');
    expect(again.mine.length, 2);

    final otroNegocio = BranchService(prefs: prefs)..restore('t2');
    expect(otroNegocio.current.value, isNull);
  });

  test('empleado no asignado a la sede del dispositivo: pasa a la suya y avisa', () async {
    final s = BranchService(prefs: prefs)..restore('t1');
    await s.refresh(_dio(mine: [_b('a'), _b('b')]), roleCode: 'admin');
    await s.select(s.mine.firstWhere((b) => b.id == 'a'));
    await s.refresh(_dio(mine: [_b('b')]), roleCode: 'waiter');
    expect(s.current.value?.id, 'b');
    expect(s.notice.value, contains('Sede a'));
  });

  test('"ver todas" solo para admin/gerente', () async {
    final s = BranchService(prefs: prefs)..restore('t1');
    await s.refresh(_dio(mine: [_b('a'), _b('b')]), roleCode: 'admin');
    await s.setViewAll(true);
    await s.refresh(_dio(mine: [_b('a'), _b('b')]), roleCode: 'cashier');
    expect(s.viewAll.value, isFalse);
  });
}
