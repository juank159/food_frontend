import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/config/constants/order_enums.dart';
import 'package:menu_plat/core/error/exceptions.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/core/network/network_info.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/payments/data/datasources/payment_local_datasource.dart';
import 'package:menu_plat/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:menu_plat/features/payments/data/repositories/payment_repository_impl.dart';

class _Net implements NetworkInfo {
  bool connected = true;
  @override
  Future<bool> get isConnected async => connected;
}

class _Local implements PaymentLocalDataSource {
  final queued = <Map<String, dynamic>>[];
  @override
  Future<void> enqueuePayment(Map<String, dynamic> dto) async => queued.add(dto);
  @override
  List<QueueEntry> getPendingPayments() => const [];
}

/// El remoto anota el id que se le mandó y falla como se le pida.
class _Remote implements PaymentRemoteDataSource {
  Exception? fail;
  String? sentRequestId;

  @override
  dynamic noSuchMethod(Invocation i) {
    sentRequestId = i.namedArguments[#clientRequestId] as String?;
    throw fail ?? UnimplementedError();
  }
}

void main() {
  late _Net net;
  late _Local local;
  late _Remote remote;
  late PaymentRepositoryImpl repo;

  setUp(() {
    net = _Net();
    local = _Local();
    remote = _Remote();
    repo = PaymentRepositoryImpl(remoteDataSource: remote, localDataSource: local, networkInfo: net);
  });

  test('sin red: el cobro del ticket se encola con client_request_id', () async {
    net.connected = false;
    final r = await repo.createPayment(orderId: 'o1', paymentMethod: PaymentMethod.cash, amount: 5000);
    expect(r.fold((f) => f, (_) => null), isA<OfflineQueuedFailure>());
    expect(local.queued.single['type'], 'createPayment');
    expect(local.queued.single['client_request_id'], isNotEmpty);
  });

  test('la red se cae A MITAD del cobro: se encola con el MISMO id que se mandó (no cobra dos veces)', () async {
    remote.fail = NetworkException('timeout');
    final r = await repo.processTabPayment(
      tabSessionId: 't1',
      amount: 28500,
      paymentMethod: PaymentMethod.cash,
    );
    expect(r.fold((f) => f, (_) => null), isA<OfflineQueuedFailure>());
    expect(remote.sentRequestId, isNotNull);
    expect(local.queued.single['client_request_id'], remote.sentRequestId);
  });

  test('el servidor rechazó (ej. 403 plan vencido): se informa y NO se encola', () async {
    remote.fail = ServerException('PLAN_REQUIRED');
    final r = await repo.processOrderPayment(orderId: 'o1', paymentMethod: PaymentMethod.card);
    expect(r.fold((f) => f, (_) => null), isA<ServerFailure>());
    expect(local.queued, isEmpty);
  });

  test('venta de mostrador hecha sin internet: el cobro va a la cola referenciando la orden por su client_request_id, AUN con red', () async {
    final r = await repo.createPayment(
      orderId: '${offlineOrderPrefix}crid-123',
      paymentMethod: PaymentMethod.cash,
      amount: 6000,
    );
    expect(r.fold((f) => f, (_) => null), isA<OfflineQueuedFailure>());
    expect(remote.sentRequestId, isNull, reason: 'no debe intentar online: la orden todavía no existe en el servidor');
    expect(local.queued.single['order_client_request_id'], 'crid-123');
    expect(local.queued.single.containsKey('order_id'), isFalse);
  });
}
