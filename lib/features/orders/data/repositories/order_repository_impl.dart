import 'package:dartz/dartz.dart' hide Order;
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

/// Order Repository Implementation
/// Implementación concreta del repositorio de órdenes
class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  OrderRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<Order>>> getOrders({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? limit,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getOrders(
          status: status,
          orderType: orderType,
          tableId: tableId,
          customerId: customerId,
          startDate: startDate,
          endDate: endDate,
          page: page,
          limit: limit,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Orders not found'));
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
  Future<Either<Failure, Order>> getOrderById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getOrderById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, Order>> getOrderByNumber(String orderNumber) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getOrderByNumber(orderNumber);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, List<Order>>> getActiveOrders() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getActiveOrders();
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Active orders not found'));
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
  Future<Either<Failure, List<Order>>> getOrdersByTable(String tableId) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getOrdersByTable(tableId);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Orders not found'));
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
  Future<Either<Failure, List<Order>>> getOrdersByCustomer(
      String customerId) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getOrdersByCustomer(customerId);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Orders not found'));
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
  Future<Either<Failure, List<Order>>> getPendingPaymentOrders() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getPendingPaymentOrders();
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Orders not found'));
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
  Future<Either<Failure, Order>> createOrder({
    required OrderType orderType,
    OrderSource orderSource = OrderSource.pos,
    String? tableId,
    String? tableElementId,
    String? tabSessionId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    Map<String, dynamic>? deliveryAddress,
    String? assignedTo,
    required List<Map<String, dynamic>> items,
    String? specialInstructions,
    double discountAmount = 0,
    double? discountPercentage,
    double deliveryFee = 0,
    double tipAmount = 0,
    double? taxAmount,
    PaymentMethod? paymentMethod,
    int? estimatedTime,
    Map<String, dynamic>? metadata,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final orderData = <String, dynamic>{
          'order_type': orderType.value,
          'order_source': orderSource.value,
          'items': items,
          'discount_amount': discountAmount,
          'delivery_fee': deliveryFee,
          'tip_amount': tipAmount,
        };

        if (tableId != null) orderData['table_id'] = tableId;
        if (tableElementId != null) orderData['table_element_id'] = tableElementId;
        if (tabSessionId != null) orderData['tab_session_id'] = tabSessionId;
        if (customerId != null) orderData['customer_id'] = customerId;
        if (customerName != null) orderData['customer_name'] = customerName;
        if (customerPhone != null) orderData['customer_phone'] = customerPhone;
        if (customerEmail != null) orderData['customer_email'] = customerEmail;
        if (deliveryAddress != null) {
          orderData['delivery_address'] = deliveryAddress;
        }
        if (assignedTo != null) orderData['assigned_to'] = assignedTo;
        if (specialInstructions != null) {
          orderData['special_instructions'] = specialInstructions;
        }
        if (discountPercentage != null) {
          orderData['discount_percentage'] = discountPercentage;
        }
        if (taxAmount != null) orderData['tax_amount'] = taxAmount;
        if (paymentMethod != null) {
          orderData['payment_method'] = paymentMethod.value;
        }
        if (estimatedTime != null) {
          orderData['estimated_time'] = estimatedTime;
        }
        if (metadata != null) orderData['metadata'] = metadata;

        final result = await remoteDataSource.createOrder(orderData);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
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
  Future<Either<Failure, Order>> updateOrderStatus({
    required String id,
    required OrderStatus status,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.updateOrderStatus(id, status);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, Order>> updateOrder({
    required String id,
    OrderStatus? status,
    String? tableId,
    String? customerId,
    String? customerName,
    String? assignedTo,
    String? specialInstructions,
    Map<String, dynamic>? deliveryAddress,
    int? estimatedTime,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final orderData = <String, dynamic>{};
        if (status != null) orderData['status'] = status.value;
        if (tableId != null) orderData['table_id'] = tableId;
        if (customerId != null) orderData['customer_id'] = customerId;
        if (customerName != null) orderData['customer_name'] = customerName;
        if (assignedTo != null) orderData['assigned_to'] = assignedTo;
        if (specialInstructions != null) {
          orderData['special_instructions'] = specialInstructions;
        }
        if (deliveryAddress != null) {
          orderData['delivery_address'] = deliveryAddress;
        }
        if (estimatedTime != null) {
          orderData['estimated_time'] = estimatedTime;
        }

        final result = await remoteDataSource.updateOrder(id, orderData);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, Order>> assignOrder({
    required String id,
    required String userId,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.assignOrder(id, userId);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, Order>> updatePaymentMethod({
    required String id,
    required PaymentMethod paymentMethod,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final orderData = {'payment_method': paymentMethod.value};
        final result = await remoteDataSource.updateOrder(id, orderData);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, Order>> markAsPaid({
    required String id,
    required PaymentMethod paymentMethod,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.markAsPaid(id, paymentMethod);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, Order>> cancelOrder({
    required String id,
    String? reason,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.cancelOrder(id, reason);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
  Future<Either<Failure, void>> deleteOrder(String id) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteOrder(id);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Order not found'));
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
