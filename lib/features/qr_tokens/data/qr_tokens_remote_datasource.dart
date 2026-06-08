import 'package:dio/dio.dart';

import '../../../core/config/constants/api_constants.dart';
import '../../../core/utils/api_response_utils.dart';
import 'models/qr_token_model.dart';

/// Datasource para el módulo QR Tokens.
///
/// Acceso directo desde el controller (sin repository/usecase) porque
/// la feature es contenida y no comparte lógica de dominio con otras.
class QrTokensRemoteDataSource {
  QrTokensRemoteDataSource({required this.dio});
  final Dio dio;

  Future<List<QrTokenModel>> list() async {
    final response = await dio.get(ApiConstants.qrTokens);
    return ApiResponseUtils.list(response)
        .map((e) => QrTokenModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QrTokenModel> create({
    required QrTokenType type,
    required String displayLabel,
    String? tableElementId,
    String? zoneLabel,
  }) async {
    final body = <String, dynamic>{
      'type': type.apiValue,
      'display_label': displayLabel,
      if (tableElementId != null && tableElementId.isNotEmpty)
        'table_element_id': tableElementId,
      if (zoneLabel != null && zoneLabel.isNotEmpty) 'zone_label': zoneLabel,
    };
    final response = await dio.post(ApiConstants.qrTokens, data: body);
    return QrTokenModel.fromJson(ApiResponseUtils.object(response));
  }

  Future<QrTokenModel> update(
    String id, {
    String? displayLabel,
    String? tableElementId,
    String? zoneLabel,
  }) async {
    final body = <String, dynamic>{
      if (displayLabel != null) 'display_label': displayLabel,
      if (tableElementId != null) 'table_element_id': tableElementId,
      if (zoneLabel != null) 'zone_label': zoneLabel,
    };
    final response = await dio.patch(ApiConstants.qrTokenById(id), data: body);
    return QrTokenModel.fromJson(ApiResponseUtils.object(response));
  }

  Future<void> deactivate(String id) async {
    await dio.patch(ApiConstants.qrTokenDeactivate(id));
  }

  Future<QrTokenModel> reactivate(String id) async {
    final response = await dio.patch(ApiConstants.qrTokenReactivate(id));
    return QrTokenModel.fromJson(ApiResponseUtils.object(response));
  }

  /// Bulk-create: crea N QRs en secuencia ("Mesa 1"..."Mesa N").
  /// Acepta máximo 200 por request.
  Future<List<QrTokenModel>> bulkCreate({
    required QrTokenType type,
    required String labelPrefix,
    required int from,
    required int to,
    String? zoneLabel,
  }) async {
    final response = await dio.post(
      '${ApiConstants.qrTokens}/bulk',
      data: {
        'type': type.apiValue,
        'label_prefix': labelPrefix,
        'from': from,
        'to': to,
        if (zoneLabel != null && zoneLabel.isNotEmpty)
          'zone_label': zoneLabel,
      },
    );
    return ApiResponseUtils.list(response)
        .map((e) => QrTokenModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
