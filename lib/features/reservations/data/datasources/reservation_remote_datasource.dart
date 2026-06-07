import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../models/reservation_model.dart';

/// Reservation Remote Data Source
///
/// Cubre los endpoints expuestos por `reservations.controller.ts`.
abstract class ReservationRemoteDataSource {
  Future<List<ReservationModel>> getReservations({
    ReservationStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int? page,
    int? limit,
  });

  Future<List<ReservationModel>> getUpcomingReservations({int hours = 24});

  Future<ReservationModel> getReservationById(String id);

  Future<ReservationModel> createReservation({
    required String customerName,
    required int partySize,
    required DateTime reservedFor,
    String? customerPhone,
    String? customerEmail,
    String? customerId,
    String? tableElementId,
    String? floorPlanId,
    int? durationMinutes,
    String? notes,
  });

  Future<ReservationModel> updateReservation({
    required String id,
    String? customerName,
    int? partySize,
    DateTime? reservedFor,
    String? customerPhone,
    String? customerEmail,
    String? tableElementId,
    String? floorPlanId,
    int? durationMinutes,
    String? notes,
  });

  Future<ReservationModel> updateReservationStatus({
    required String id,
    required ReservationStatus status,
    String? notes,
  });

  Future<ReservationModel> cancelReservation({
    required String id,
    String? reason,
  });

  Future<void> deleteReservation(String id);
}

class ReservationRemoteDataSourceImpl implements ReservationRemoteDataSource {
  final Dio dio;

  ReservationRemoteDataSourceImpl({required this.dio});

  // ─────────────────────────── Helpers ───────────────────────────

  /// Extrae el payload "data" o devuelve la respuesta tal cual (el backend
  /// a veces envuelve, otras devuelve el objeto plano).
  dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData['data'] ?? responseData;
    }
    return responseData;
  }

  List<dynamic> _unwrapList(dynamic responseData) {
    final unwrapped = _unwrap(responseData);
    if (unwrapped is List) return unwrapped;
    // Algunos endpoints paginados devuelven { items: [...], total: n }.
    if (unwrapped is Map<String, dynamic>) {
      final items = unwrapped['items'] ?? unwrapped['rows'];
      if (items is List) return items;
    }
    return const [];
  }

  // ─────────────────────────── List / Detail ───────────────────────────

  @override
  Future<List<ReservationModel>> getReservations({
    ReservationStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status.value;
      if (dateFrom != null) {
        queryParams['date_from'] = dateFrom.toUtc().toIso8601String();
      }
      if (dateTo != null) {
        queryParams['date_to'] = dateTo.toUtc().toIso8601String();
      }
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await dio.get(
        ApiConstants.reservations,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return _unwrapList(response.data)
            .map((j) => ReservationModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ServerException('Failed to load reservations');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<ReservationModel>> getUpcomingReservations({
    int hours = 24,
  }) async {
    try {
      final response = await dio.get(
        ApiConstants.upcomingReservations,
        queryParameters: {'hours': hours},
      );
      if (response.statusCode == 200) {
        return _unwrapList(response.data)
            .map((j) => ReservationModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ServerException('Failed to load upcoming reservations');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ReservationModel> getReservationById(String id) async {
    try {
      final response = await dio.get(ApiConstants.reservationById(id));
      if (response.statusCode == 200) {
        return ReservationModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to load reservation');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // ─────────────────────────── Mutations ───────────────────────────

  @override
  Future<ReservationModel> createReservation({
    required String customerName,
    required int partySize,
    required DateTime reservedFor,
    String? customerPhone,
    String? customerEmail,
    String? customerId,
    String? tableElementId,
    String? floorPlanId,
    int? durationMinutes,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'customer_name': customerName,
        'party_size': partySize,
        'reserved_for': reservedFor.toUtc().toIso8601String(),
      };
      if (customerPhone != null && customerPhone.isNotEmpty) {
        body['customer_phone'] = customerPhone;
      }
      if (customerEmail != null && customerEmail.isNotEmpty) {
        body['customer_email'] = customerEmail;
      }
      if (customerId != null && customerId.isNotEmpty) {
        body['customer_id'] = customerId;
      }
      if (tableElementId != null && tableElementId.isNotEmpty) {
        body['table_element_id'] = tableElementId;
      }
      if (floorPlanId != null && floorPlanId.isNotEmpty) {
        body['floor_plan_id'] = floorPlanId;
      }
      if (durationMinutes != null) body['duration_minutes'] = durationMinutes;
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;

      final response = await dio.post(ApiConstants.reservations, data: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ReservationModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to create reservation');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ReservationModel> updateReservation({
    required String id,
    String? customerName,
    int? partySize,
    DateTime? reservedFor,
    String? customerPhone,
    String? customerEmail,
    String? tableElementId,
    String? floorPlanId,
    int? durationMinutes,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (customerName != null) body['customer_name'] = customerName;
      if (partySize != null) body['party_size'] = partySize;
      if (reservedFor != null) {
        body['reserved_for'] = reservedFor.toUtc().toIso8601String();
      }
      if (customerPhone != null) body['customer_phone'] = customerPhone;
      if (customerEmail != null) body['customer_email'] = customerEmail;
      if (tableElementId != null) body['table_element_id'] = tableElementId;
      if (floorPlanId != null) body['floor_plan_id'] = floorPlanId;
      if (durationMinutes != null) body['duration_minutes'] = durationMinutes;
      if (notes != null) body['notes'] = notes;

      final response = await dio.patch(
        ApiConstants.reservationById(id),
        data: body,
      );
      if (response.statusCode == 200) {
        return ReservationModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to update reservation');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ReservationModel> updateReservationStatus({
    required String id,
    required ReservationStatus status,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{'status': status.value};
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;

      final response = await dio.patch(
        ApiConstants.reservationStatus(id),
        data: body,
      );
      if (response.statusCode == 200) {
        return ReservationModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to update reservation status');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ReservationModel> cancelReservation({
    required String id,
    String? reason,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) body['reason'] = reason;

      final response = await dio.post(
        ApiConstants.cancelReservationEndpoint(id),
        data: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ReservationModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to cancel reservation');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteReservation(String id) async {
    try {
      final response = await dio.delete(ApiConstants.reservationById(id));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete reservation');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // ─────────────────────────── Error mapping ───────────────────────────

  void _handleDioException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (status == 404) {
      throw NotFoundException('Reservation not found');
    } else if (status == 409) {
      final msg = _extractMessage(e.response?.data) ?? 'Resource conflict';
      throw ConflictException(msg);
    } else if (status == 400 || status == 422) {
      final msg = _extractMessage(e.response?.data) ?? 'Bad request';
      throw ValidationException(msg);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      final msg = _extractMessage(e.response?.data) ?? 'Server error occurred';
      throw ServerException(msg);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final raw = data['message'];
      if (raw is List) return raw.join(', ');
      if (raw is String) return raw;
    }
    return null;
  }
}
