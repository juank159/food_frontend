import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/network/network_info.dart';
import 'package:menu_plat/features/shifts/data/datasources/shift_local_datasource.dart';
import 'package:menu_plat/features/shifts/data/datasources/shift_remote_datasource.dart';
import 'package:menu_plat/features/shifts/data/models/shift_model.dart';
import 'package:menu_plat/features/shifts/data/repositories/shift_repository_impl.dart';

class _FakeNetworkInfo implements NetworkInfo {
  bool connected = true;
  @override
  Future<bool> get isConnected async => connected;
}

class _FakeRemote implements ShiftRemoteDataSource {
  ShiftModel? clockInResult;
  ShiftModel? clockOutResult;

  @override
  Future<ShiftModel> clockIn({String? notes}) async => clockInResult!;

  @override
  Future<ShiftModel> clockOut({String? notes}) async => clockOutResult!;

  @override
  Future<ShiftModel?> getMyCurrent() async => null;

  @override
  Future<List<ShiftModel>> getMine({DateTime? from, DateTime? to, int? limit}) async =>
      [];

  @override
  Future<List<ShiftModel>> getActiveStaff() async => [];
}

class _FakeLocal implements ShiftLocalDataSource {
  ShiftModel? pending;
  List<Map<String, dynamic>> enqueuedClockIns = [];
  List<Map<String, dynamic>> enqueuedClockOuts = [];

  @override
  Future<void> enqueueClockIn(Map<String, dynamic> dto) async {
    enqueuedClockIns.add(dto);
  }

  @override
  Future<void> enqueueClockOut(Map<String, dynamic> dto) async {
    enqueuedClockOuts.add(dto);
  }

  @override
  Future<void> savePendingShift(ShiftModel? shift) async => pending = shift;

  @override
  Future<ShiftModel?> getPendingShift() async => pending;

  @override
  Future<void> clearPendingShift() async => pending = null;
}

void main() {
  late _FakeNetworkInfo networkInfo;
  late _FakeRemote remote;
  late _FakeLocal local;
  late ShiftRepositoryImpl repo;

  setUp(() {
    networkInfo = _FakeNetworkInfo();
    remote = _FakeRemote();
    local = _FakeLocal();
    repo = ShiftRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      networkInfo: networkInfo,
    );
  });

  test(
    'BUG REAL evitado: fichar entrada SIN conexión encola la operación y devuelve un turno optimista (no falla)',
    () async {
      networkInfo.connected = false;

      final result = await repo.clockIn(notes: 'turno mañana');

      expect(result.isRight(), isTrue);
      expect(local.enqueuedClockIns, hasLength(1));
      expect(local.enqueuedClockIns.first['notes'], 'turno mañana');
      // getMyCurrent debe reflejar "estoy en turno" de inmediato.
      final current = await repo.getMyCurrent();
      expect(current.isRight(), isTrue);
      current.fold((_) => fail('no debería fallar'), (shift) {
        expect(shift, isNotNull);
        expect(shift!.clockOut, isNull);
      });
    },
  );

  test(
    'fichar salida sin conexión: encola y getMyCurrent ya no muestra turno abierto',
    () async {
      networkInfo.connected = false;
      await repo.clockIn();

      final result = await repo.clockOut(notes: 'listo');

      expect(result.isRight(), isTrue);
      expect(local.enqueuedClockOuts, hasLength(1));
      final current = await repo.getMyCurrent();
      current.fold((_) => fail('no debería fallar'), (shift) {
        expect(shift, isNull); // ya fichó salida, no hay turno abierto
      });
    },
  );

  test('con conexión: va directo al remoto, sin encolar ni dejar pending', () async {
    networkInfo.connected = true;
    remote.clockInResult = ShiftModel(
      id: 'real-1',
      userId: 'u1',
      clockIn: DateTime.now().toIso8601String(),
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    final result = await repo.clockIn();

    expect(local.enqueuedClockIns, isEmpty);
    result.fold((_) => fail('no debería fallar'), (shift) {
      expect(shift.id, 'real-1');
    });
  });

  test(
    'getMyCurrent sin conexión y sin ningún pending: devuelve null, no falla',
    () async {
      networkInfo.connected = false;

      final result = await repo.getMyCurrent();

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('no debería fallar'), (shift) {
        expect(shift, isNull);
      });
    },
  );
}
