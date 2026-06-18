import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/subscription_model.dart';
import '../models/subscription_plan_model.dart';
import '../models/subscription_usage_model.dart';

/// Remote Data Source for Subscriptions
/// Handles all HTTP requests to subscription endpoints
abstract class SubscriptionRemoteDataSource {
  /// Get all available subscription plans
  Future<List<SubscriptionPlanModel>> getPlans();

  /// Get current user's subscription
  Future<SubscriptionModel> getCurrentSubscription();

  /// Get subscription usage and limits
  Future<SubscriptionUsageModel> getUsage();

  /// Change subscription plan
  Future<SubscriptionModel> changePlan({
    required String planCode,
    String? billingCycle,
  });

  /// Cancel subscription
  Future<SubscriptionModel> cancelSubscription({
    required bool immediately,
    String? reason,
  });

  /// Check if feature is available
  Future<bool> checkFeature(String featureName);

  /// Check limit status
  Future<Map<String, dynamic>> checkLimit({
    required String limitName,
    required int currentUsage,
  });
}

class SubscriptionRemoteDataSourceImpl
    implements SubscriptionRemoteDataSource {
  final Dio dio;

  SubscriptionRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<SubscriptionPlanModel>> getPlans() async {
    try {
      final response = await dio.get(ApiConstants.subscriptionPlans);

      if (response.statusCode == 200) {
        return ApiResponseUtils.list(response)
            .whereType<Map<String, dynamic>>()
            .map(SubscriptionPlanModel.fromJson)
            .toList();
      }

      throw ServerException(
        'Failed to load plans',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<SubscriptionModel> getCurrentSubscription() async {
    try {
      final response = await dio.get(ApiConstants.currentSubscription);

      if (response.statusCode == 200) {
        final data = response.data;
        return SubscriptionModel.fromJson(data as Map<String, dynamic>);
      }

      throw ServerException(
        'Failed to load subscription',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<SubscriptionUsageModel> getUsage() async {
    try {
      final response = await dio.get(ApiConstants.subscriptionUsage);

      if (response.statusCode == 200) {
        final data = response.data;
        return SubscriptionUsageModel.fromJson(data as Map<String, dynamic>);
      }

      throw ServerException(
        'Failed to load usage',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<SubscriptionModel> changePlan({
    required String planCode,
    String? billingCycle,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.changePlan,
        data: {
          'plan_code': planCode,
          if (billingCycle != null) 'billing_cycle': billingCycle,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['subscription'] ?? response.data;
        return SubscriptionModel.fromJson(data as Map<String, dynamic>);
      }

      throw ServerException(
        'Failed to change plan',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<SubscriptionModel> cancelSubscription({
    required bool immediately,
    String? reason,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.cancelSubscription,
        data: {
          'immediately': immediately,
          if (reason != null) 'cancellation_reason': reason,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['subscription'] ?? response.data;
        return SubscriptionModel.fromJson(data as Map<String, dynamic>);
      }

      throw ServerException(
        'Failed to cancel subscription',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<bool> checkFeature(String featureName) async {
    try {
      final response = await dio.post(
        ApiConstants.checkFeature,
        data: {'feature_name': featureName},
      );

      if (response.statusCode == 200) {
        return response.data['available'] as bool? ?? false;
      }

      throw ServerException(
        'Failed to check feature',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> checkLimit({
    required String limitName,
    required int currentUsage,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.checkLimit,
        data: {
          'limit_name': limitName,
          'current_usage': currentUsage,
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }

      throw ServerException(
        'Failed to check limit',
        response.statusCode,
      );
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  /// Handle Dio exceptions and convert to custom exceptions
  void _handleDioException(DioException e) {
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('No autorizado');
    } else if (e.response?.statusCode == 403) {
      throw UnauthorizedException(
        ApiResponseUtils.errorMessage(e) ?? 'Acceso denegado',
      );
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException('Recurso no encontrado');
    } else if (e.response?.statusCode == 400) {
      throw ValidationException(
        ApiResponseUtils.errorMessage(e) ?? 'Datos inválidos',
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Tiempo de espera agotado');
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException('Error de conexión');
    } else {
      throw ServerException(
        ApiResponseUtils.errorMessage(e) ?? 'Error del servidor',
        e.response?.statusCode,
      );
    }
  }
}
