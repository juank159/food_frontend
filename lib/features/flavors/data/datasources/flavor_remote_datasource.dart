import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/flavor_model.dart';

/// Fuente de datos remota para cremas/sabores.
abstract class FlavorRemoteDataSource {
  Future<List<FlavorModel>> getFlavors({String? categoryId});
  Future<FlavorModel> createFlavor(Map<String, dynamic> data);
  Future<FlavorModel> updateFlavor(String id, Map<String, dynamic> data);
  Future<void> deleteFlavor(String id);
}

class FlavorRemoteDataSourceImpl implements FlavorRemoteDataSource {
  final Dio dio;
  FlavorRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<FlavorModel>> getFlavors({String? categoryId}) async {
    try {
      final response = await dio.get(
        ApiConstants.flavors,
        queryParameters: {
          if (categoryId != null) 'category_id': categoryId,
        },
      );
      return ApiResponseUtils.list(response)
          .whereType<Map<String, dynamic>>()
          .map(FlavorModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<FlavorModel> createFlavor(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(ApiConstants.flavors, data: data);
      return FlavorModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<FlavorModel> updateFlavor(String id, Map<String, dynamic> data) async {
    try {
      final response = await dio.patch(ApiConstants.flavorById(id), data: data);
      return FlavorModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> deleteFlavor(String id) async {
    try {
      await dio.delete(ApiConstants.flavorById(id));
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return e.message ?? 'Error de conexión';
  }
}
