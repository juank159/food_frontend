import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/customer_address_model.dart';
import '../models/customer_model.dart';
import '../models/customer_statistics_model.dart';

/// Customer Remote Data Source
///
/// Cubre los endpoints expuestos por `customers.controller.ts`.
abstract class CustomerRemoteDataSource {
  Future<List<CustomerModel>> getCustomers({bool? isActive, String? search});
  Future<CustomerModel> getCustomerById(String id);
  Future<CustomerModel?> getCustomerByPhone(String phone);
  Future<CustomerStatisticsModel> getStatistics();
  Future<List<CustomerAddressModel>> getAddresses(String customerId);

  Future<CustomerModel> createCustomer({
    required String fullName,
    required String phone,
    String? email,
    String? notes,
    bool isActive = true,
  });

  Future<CustomerModel> updateCustomer({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  });

  Future<void> deleteCustomer(String id);

  Future<CustomerAddressModel> createAddress({
    required String customerId,
    required String label,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool isDefault = false,
  });

  Future<CustomerAddressModel> updateAddress({
    required String addressId,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool? isDefault,
  });

  Future<void> deleteAddress(String addressId);
}

class CustomerRemoteDataSourceImpl implements CustomerRemoteDataSource {
  final Dio dio;

  CustomerRemoteDataSourceImpl({required this.dio});

  // Helpers ────────────────────────────────────────────────────────────────

  /// Extrae el payload "data" o devuelve la respuesta tal cual. El backend
  /// algunas veces envuelve, otras devuelve el objeto plano.
  dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData['data'] ?? responseData;
    }
    return responseData;
  }

  List<dynamic> _unwrapList(dynamic responseData) {
    final unwrapped = _unwrap(responseData);
    if (unwrapped is List) return unwrapped;
    return const [];
  }

  // Customers ─────────────────────────────────────────────────────────────

  @override
  Future<List<CustomerModel>> getCustomers({
    bool? isActive,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (isActive != null) queryParams['is_active'] = isActive.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await dio.get(
        ApiConstants.customers,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        return _unwrapList(response.data)
            .map((j) => CustomerModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ServerException('Failed to load customers');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerModel> getCustomerById(String id) async {
    try {
      final response = await dio.get(ApiConstants.customerById(id));
      if (response.statusCode == 200) {
        return CustomerModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to load customer');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerModel?> getCustomerByPhone(String phone) async {
    try {
      final response = await dio.get('${ApiConstants.customers}/phone/$phone');
      if (response.statusCode == 200) {
        final data = _unwrap(response.data);
        if (data == null) return null;
        return CustomerModel.fromJson(data as Map<String, dynamic>);
      }
      throw ServerException('Failed to load customer by phone');
    } on DioException catch (e) {
      // El backend puede devolver `null` con 200 — lo soportamos arriba —
      // pero también podría dar 404; en ese caso el cliente sencillamente
      // no existe.
      if (e.response?.statusCode == 404) return null;
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerStatisticsModel> getStatistics() async {
    try {
      final response =
          await dio.get('${ApiConstants.customers}/statistics');
      if (response.statusCode == 200) {
        return CustomerStatisticsModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to load customer statistics');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<CustomerAddressModel>> getAddresses(String customerId) async {
    try {
      final response = await dio
          .get('${ApiConstants.customers}/$customerId/addresses');
      if (response.statusCode == 200) {
        return _unwrapList(response.data)
            .map((j) =>
                CustomerAddressModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ServerException('Failed to load addresses');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerModel> createCustomer({
    required String fullName,
    required String phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) async {
    try {
      final body = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'is_active': isActive,
      };
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;

      final response = await dio.post(ApiConstants.customers, data: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return CustomerModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to create customer');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerModel> updateCustomer({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (phone != null) body['phone'] = phone;
      if (email != null) body['email'] = email;
      if (notes != null) body['notes'] = notes;
      if (isActive != null) body['is_active'] = isActive;

      final response =
          await dio.patch(ApiConstants.customerById(id), data: body);
      if (response.statusCode == 200) {
        return CustomerModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to update customer');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      final response = await dio.delete(ApiConstants.customerById(id));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete customer');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // Addresses ─────────────────────────────────────────────────────────────

  @override
  Future<CustomerAddressModel> createAddress({
    required String customerId,
    required String label,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool isDefault = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'customer_id': customerId,
        'label': label,
        'address_line1': addressLine1,
        'city': city,
        'is_default': isDefault,
      };
      if (addressLine2 != null && addressLine2.isNotEmpty) {
        body['address_line2'] = addressLine2;
      }
      if (state != null && state.isNotEmpty) body['state'] = state;
      if (postalCode != null && postalCode.isNotEmpty) {
        body['postal_code'] = postalCode;
      }
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (deliveryInstructions != null && deliveryInstructions.isNotEmpty) {
        body['delivery_instructions'] = deliveryInstructions;
      }

      final response = await dio.post(
        '${ApiConstants.customers}/addresses',
        data: body,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return CustomerAddressModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to create address');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerAddressModel> updateAddress({
    required String addressId,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool? isDefault,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (label != null) body['label'] = label;
      if (addressLine1 != null) body['address_line1'] = addressLine1;
      if (addressLine2 != null) body['address_line2'] = addressLine2;
      if (city != null) body['city'] = city;
      if (state != null) body['state'] = state;
      if (postalCode != null) body['postal_code'] = postalCode;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (deliveryInstructions != null) {
        body['delivery_instructions'] = deliveryInstructions;
      }
      if (isDefault != null) body['is_default'] = isDefault;

      final response = await dio.patch(
        '${ApiConstants.customers}/addresses/$addressId',
        data: body,
      );
      if (response.statusCode == 200) {
        return CustomerAddressModel.fromJson(_unwrap(response.data));
      }
      throw ServerException('Failed to update address');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    try {
      final response = await dio
          .delete('${ApiConstants.customers}/addresses/$addressId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete address');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // Error handling ────────────────────────────────────────────────────────

  void _handleDioException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (status == 404) {
      throw NotFoundException('Customer not found');
    } else if (status == 409) {
      final msg = _extractMessage(e.response?.data) ?? 'Resource conflict';
      throw ConflictException(msg);
    } else if (status == 400) {
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
