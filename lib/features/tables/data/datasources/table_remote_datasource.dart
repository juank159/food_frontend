// lib/features/tables/data/datasources/table_remote_datasource.dart

import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/table_model.dart';

/// Table Remote Data Source
/// Maneja las llamadas HTTP para el módulo de mesas
abstract class TableRemoteDataSource {
  Future<List<TableModel>> getTables({
    TableStatus? status,
    String? zone,
    String? section,
    bool? isActive,
  });
  Future<TableModel> getTableById(String id);
  Future<TableModel> getTableByNumber(String tableNumber);
  Future<List<TableModel>> getAvailableTables({int? minCapacity, String? zone});
  Future<List<TableModel>> getOccupiedTables();
  Future<List<TableModel>> getTablesByZone(String zone);
  Future<List<TableModel>> getTablesBySection(String section);
  Future<TableModel> createTable(Map<String, dynamic> tableData);
  Future<TableModel> updateTable(String id, Map<String, dynamic> tableData);
  Future<TableModel> updateTableStatus(String id, TableStatus status);
  Future<TableModel> occupyTable(
    String id,
    String? orderId,
    String? assignedTo,
  );
  Future<TableModel> releaseTable(String id);
  Future<TableModel> reserveTable(
    String id,
    Map<String, dynamic> reservationData,
  );
  Future<TableModel> markForCleaning(String id);
  Future<TableModel> completeCleaning(String id);
  Future<void> deleteTable(String id);
  Future<List<TableModel>> getTableLayout();
  Future<TableModel> updateTablePosition(
    String id,
    double positionX,
    double positionY,
    double? width,
    double? height,
    String? shape,
  );
}

class TableRemoteDataSourceImpl implements TableRemoteDataSource {
  final Dio dio;

  TableRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<TableModel>> getTables({
    TableStatus? status,
    String? zone,
    String? section,
    bool? isActive,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status.value;
      if (zone != null) queryParams['zone'] = zone;
      if (section != null) queryParams['section'] = section;
      if (isActive != null) queryParams['isActive'] = isActive;

      final response = await dio.get(
        ApiConstants.tables,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = _extractListData(response.data);
        return data.map((json) => TableModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to load tables');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> getTableById(String id) async {
    try {
      final response = await dio.get(ApiConstants.tableById(id));

      if (response.statusCode == 200) {
        return TableModel.fromJson(_extractSingleData(response.data));
      } else {
        throw ServerException('Failed to load table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> getTableByNumber(String tableNumber) async {
    try {
      final response = await dio.get(
        ApiConstants.tables,
        queryParameters: {'tableNumber': tableNumber},
      );

      if (response.statusCode == 200) {
        final list = ApiResponseUtils.list(response)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (list.isEmpty) throw NotFoundException('Table not found');
        return TableModel.fromJson(list.first);
      } else {
        throw ServerException('Failed to load table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<TableModel>> getAvailableTables({
    int? minCapacity,
    String? zone,
  }) async {
    try {
      final queryParams = <String, dynamic>{'status': 'available'};
      if (minCapacity != null) queryParams['minCapacity'] = minCapacity;
      if (zone != null) queryParams['zone'] = zone;

      final response = await dio.get(
        ApiConstants.availableTables,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = _extractListData(response.data);
        return data.map((json) => TableModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to load available tables');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<TableModel>> getOccupiedTables() async {
    try {
      final response = await dio.get(ApiConstants.occupiedTables);

      if (response.statusCode == 200) {
        final data = _extractListData(response.data);
        return data.map((json) => TableModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to load occupied tables');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<TableModel>> getTablesByZone(String zone) async {
    try {
      final response = await dio.get(ApiConstants.tablesByZone(zone));

      if (response.statusCode == 200) {
        final data = _extractListData(response.data);
        return data.map((json) => TableModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to load tables by zone');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<TableModel>> getTablesBySection(String section) async {
    try {
      final response = await dio.get(
        ApiConstants.tables,
        queryParameters: {'section': section},
      );

      if (response.statusCode == 200) {
        final data = _extractListData(response.data);
        return data.map((json) => TableModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to load tables by section');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> createTable(Map<String, dynamic> tableData) async {
    try {
      final response = await dio.post(ApiConstants.tables, data: tableData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to create table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> updateTable(
    String id,
    Map<String, dynamic> tableData,
  ) async {
    try {
      final response = await dio.put(
        ApiConstants.tableById(id),
        data: tableData,
      );

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to update table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> updateTableStatus(String id, TableStatus status) async {
    try {
      final response = await dio.patch(
        ApiConstants.tableStatus(id),
        data: {'status': status.value},
      );

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to update table status');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> occupyTable(
    String id,
    String? orderId,
    String? assignedTo,
  ) async {
    try {
      final data = <String, dynamic>{'status': 'occupied'};
      if (orderId != null) data['current_order_id'] = orderId;
      if (assignedTo != null) data['assigned_to'] = assignedTo;

      final response = await dio.patch(ApiConstants.tableById(id), data: data);

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to occupy table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> releaseTable(String id) async {
    try {
      final response = await dio.patch(
        ApiConstants.tableById(id),
        data: {
          'status': 'cleaning',
          'current_order_id': null,
          'assigned_to': null,
        },
      );

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to release table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> reserveTable(
    String id,
    Map<String, dynamic> reservationData,
  ) async {
    try {
      final data = {'status': 'reserved', ...reservationData};

      final response = await dio.patch(ApiConstants.tableById(id), data: data);

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to reserve table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> markForCleaning(String id) async {
    try {
      final response = await dio.patch(
        ApiConstants.tableStatus(id),
        data: {'status': 'cleaning'},
      );

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to mark table for cleaning');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> completeCleaning(String id) async {
    try {
      final response = await dio.patch(
        ApiConstants.tableStatus(id),
        data: {'status': 'available'},
      );

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to complete cleaning');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteTable(String id) async {
    try {
      final response = await dio.delete(ApiConstants.tableById(id));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete table');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<TableModel>> getTableLayout() async {
    try {
      final response = await dio.get(ApiConstants.tableLayout);

      if (response.statusCode == 200) {
        final data = _extractListData(response.data);
        return data.map((json) => TableModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to load table layout');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<TableModel> updateTablePosition(
    String id,
    double positionX,
    double positionY,
    double? width,
    double? height,
    String? shape,
  ) async {
    try {
      final data = <String, dynamic>{
        'position_x': positionX,
        'position_y': positionY,
      };
      if (width != null) data['width'] = width;
      if (height != null) data['height'] = height;
      if (shape != null) data['shape'] = shape;

      final response = await dio.patch(
        ApiConstants.tablePosition(id),
        data: data,
      );

      if (response.statusCode == 200) {
        return TableModel.fromJson(ApiResponseUtils.object(response));
      } else {
        throw ServerException('Failed to update table position');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  List<dynamic> _extractListData(dynamic responseData) {
    if (responseData is List) {
      return responseData;
    } else if (responseData is Map && responseData.containsKey('data')) {
      final data = responseData['data'];
      if (data is List) {
        return data;
      }
    }
    throw ServerException('Invalid response format: expected List or Map with data key');
  }

  dynamic _extractSingleData(dynamic responseData) {
    if (responseData is Map && responseData.containsKey('data')) {
      return responseData['data'];
    }
    return responseData;
  }

  void _handleDioException(DioException e) {
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException('Table not found');
    } else if (e.response?.statusCode == 400) {
      final message = ApiResponseUtils.errorMessage(e) ?? 'Bad request';
      throw ValidationException(message);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      throw ServerException(
        ApiResponseUtils.errorMessage(e) ?? 'Server error occurred',
      );
    }
  }
}
