import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_local_datasource.dart';
import '../datasources/payment_remote_datasource.dart';
import 'package:uuid/uuid.dart';

/// Prefijo del `orderId` de una venta hecha SIN internet que todavía no
/// tiene id real: `offline:<client_request_id de la orden>`.
const offlineOrderPrefix = 'offline:';

/// Payment Repository Implementation
/// Implementación concreta del repositorio de pagos
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;
  final PaymentLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  PaymentRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Encola un cobro para la cola offline (`SyncHandlers` → `resolvePaymentSyncRequest`).
  /// Lleva el MISMO `client_request_id` que el intento online (si lo hubo):
  /// si el servidor ya lo cobró y solo se perdió la respuesta, el reintento
  /// devuelve lo ya cobrado en vez de cobrar dos veces.
  Future<Either<Failure, T>> _queueOffline<T>(Map<String, dynamic> dto) async {
    await localDataSource.enqueuePayment(dto);
    return Left(const OfflineQueuedFailure());
  }

  /// Corre el cobro con red; si no hay red, o se cae a mitad del envío
  /// (`NetworkException` = no hubo respuesta), lo encola.
  Future<Either<Failure, T>> _payOrQueue<T>(
    Map<String, dynamic> offlineDto,
    Future<T> Function() online,
  ) async {
    if (!await networkInfo.isConnected) return _queueOffline<T>(offlineDto);
    try {
      return Right(await online());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException {
      return _queueOffline<T>(offlineDto);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Payment>> createPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) {
    // Bug real reportado: cobrar UN ticket sin internet fallaba directo
    // (el cobro de cuenta sí se encolaba). Ver `resolvePaymentSyncRequest`.
    final requestId = const Uuid().v4();
    // Orden creada sin internet (todavía sin id real): el pago SIEMPRE va a
    // la cola, DETRÁS de su orden, y la referencia por `client_request_id`.
    final offlineOrder = orderId.startsWith(offlineOrderPrefix);
    final dto = <String, dynamic>{
      'type': 'createPayment',
      if (offlineOrder)
        'order_client_request_id': orderId.substring(offlineOrderPrefix.length)
      else
        'order_id': orderId,
      'payment_method': paymentMethod.value,
      'amount': amount,
      if (receivedAmount != null) 'received_amount': receivedAmount,
      if (transactionReference != null)
        'transaction_reference': transactionReference,
      if (notes != null) 'notes': notes,
      if (tenantPaymentAccountId != null)
        'tenant_payment_account_id': tenantPaymentAccountId,
      'client_request_id': requestId,
    };
    if (offlineOrder) return _queueOffline<Payment>(dto);
    return _payOrQueue<Payment>(
      {
        'type': 'createPayment',
        'order_id': orderId,
        'payment_method': paymentMethod.value,
        'amount': amount,
        if (receivedAmount != null) 'received_amount': receivedAmount,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
        if (notes != null) 'notes': notes,
        if (tenantPaymentAccountId != null)
          'tenant_payment_account_id': tenantPaymentAccountId,
        'client_request_id': requestId,
      },
      () async => (await remoteDataSource.createPayment(
        orderId: orderId,
        paymentMethod: paymentMethod,
        amount: amount,
        receivedAmount: receivedAmount,
        transactionReference: transactionReference,
        notes: notes,
        tenantPaymentAccountId: tenantPaymentAccountId,
        clientRequestId: requestId,
      ))
          .toEntity(),
    );
  }

  @override
  Future<Either<Failure, Payment>> processOrderPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) {
    final requestId = const Uuid().v4();
    return _payOrQueue<Payment>(
      {
        'type': 'processOrderPayment',
        'order_id': orderId,
        'payment_method': paymentMethod.value,
        if (receivedAmount != null) 'received_amount': receivedAmount,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
        if (notes != null) 'notes': notes,
        if (tenantPaymentAccountId != null)
          'tenant_payment_account_id': tenantPaymentAccountId,
        'client_request_id': requestId,
      },
      () async => (await remoteDataSource.processOrderPayment(
        orderId: orderId,
        paymentMethod: paymentMethod,
        receivedAmount: receivedAmount,
        transactionReference: transactionReference,
        notes: notes,
        tenantPaymentAccountId: tenantPaymentAccountId,
        clientRequestId: requestId,
      ))
          .toEntity(),
    );
  }

  @override
  Future<Either<Failure, List<Payment>>> processSplitPayment({
    required String orderId,
    required List<Map<String, dynamic>> payments,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.processSplitPayment(
          orderId: orderId,
          payments: payments,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Payment>>> processTabPayment({
    required String tabSessionId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? tenantPaymentAccountId,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
  }) {
    final requestId = const Uuid().v4();
    return _payOrQueue<List<Payment>>(
      {
        'type': 'processTabPayment',
        'tab_session_id': tabSessionId,
        'amount': amount,
        'payment_method': paymentMethod.value,
        if (tenantPaymentAccountId != null)
          'tenant_payment_account_id': tenantPaymentAccountId,
        if (receivedAmount != null) 'received_amount': receivedAmount,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
        if (notes != null) 'notes': notes,
        'client_request_id': requestId,
      },
      () async => (await remoteDataSource.processTabPayment(
        tabSessionId: tabSessionId,
        amount: amount,
        paymentMethod: paymentMethod,
        tenantPaymentAccountId: tenantPaymentAccountId,
        receivedAmount: receivedAmount,
        transactionReference: transactionReference,
        notes: notes,
        clientRequestId: requestId,
      ))
          .map((m) => m.toEntity())
          .toList(),
    );
  }

  @override
  Future<Either<Failure, Payment>> refundPayment({
    required String paymentId,
    double? refundAmount,
    required String refundReason,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.refundPayment(
          paymentId: paymentId,
          refundAmount: refundAmount,
          refundReason: refundReason,
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPayments({
    String? orderId,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    String? processedBy,
    int? page,
    int? limit,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getPayments(
          orderId: orderId,
          paymentMethod: paymentMethod,
          status: status,
          processedBy: processedBy,
          page: page,
          limit: limit,
        );

        return Right({
          'data': (result['data'] as List)
              .map((model) => model.toEntity())
              .toList(),
          'total': result['total'],
          'page': result['page'],
          'limit': result['limit'],
        });
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Payment>> getPaymentById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getPaymentById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Payment>>> getPaymentsByOrder(
      String orderId) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getPaymentsByOrder(orderId);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }
}
