import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_datasource.dart';

/// Payment Repository Implementation
/// Implementación concreta del repositorio de pagos
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  PaymentRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Payment>> createPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.createPayment(
          orderId: orderId,
          paymentMethod: paymentMethod,
          amount: amount,
          receivedAmount: receivedAmount,
          transactionReference: transactionReference,
          notes: notes,
          tenantPaymentAccountId: tenantPaymentAccountId,
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
  Future<Either<Failure, Payment>> processOrderPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.processOrderPayment(
          orderId: orderId,
          paymentMethod: paymentMethod,
          receivedAmount: receivedAmount,
          transactionReference: transactionReference,
          notes: notes,
          tenantPaymentAccountId: tenantPaymentAccountId,
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
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.processTabPayment(
          tabSessionId: tabSessionId,
          amount: amount,
          paymentMethod: paymentMethod,
          tenantPaymentAccountId: tenantPaymentAccountId,
          receivedAmount: receivedAmount,
          transactionReference: transactionReference,
          notes: notes,
        );
        return Right(result.map((m) => m.toEntity()).toList());
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
