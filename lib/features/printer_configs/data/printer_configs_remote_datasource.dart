import 'package:dio/dio.dart';

import '../../../core/utils/api_response_utils.dart';
import 'models/printer_config_model.dart';

/// CRUD client para impresoras configuradas del tenant.
class PrinterConfigsRemoteDataSource {
  PrinterConfigsRemoteDataSource({required this.dio});
  final Dio dio;

  static const _base = '/printer-configs';

  Future<List<PrinterConfigModel>> list() async {
    final response = await dio.get(_base);
    return ApiResponseUtils.list(response)
        .map((e) => PrinterConfigModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PrinterConfigModel> create({
    required String name,
    required PrinterPurpose purpose,
    required PrinterConnectionType connectionType,
    String? host,
    int? port,
    required int paperWidth,
    bool isDefault = false,
    bool autoPrint = true,
    String? notes,
    List<String> allowedRoles = const [],
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'purpose': purpose.apiValue,
      'connection_type': connectionType.apiValue,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      'paper_width': paperWidth,
      'is_default': isDefault,
      'auto_print': autoPrint,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'allowed_roles': allowedRoles.isEmpty ? null : allowedRoles.join(','),
    };
    final response = await dio.post(_base, data: body);
    return PrinterConfigModel.fromJson(ApiResponseUtils.object(response));
  }

  Future<PrinterConfigModel> update(
    String id, {
    String? name,
    PrinterPurpose? purpose,
    PrinterConnectionType? connectionType,
    String? host,
    int? port,
    int? paperWidth,
    bool? isDefault,
    bool? autoPrint,
    bool? isActive,
    String? notes,
    List<String>? allowedRoles,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (purpose != null) body['purpose'] = purpose.apiValue;
    if (connectionType != null) {
      body['connection_type'] = connectionType.apiValue;
    }
    if (host != null) body['host'] = host;
    if (port != null) body['port'] = port;
    if (paperWidth != null) body['paper_width'] = paperWidth;
    if (isDefault != null) body['is_default'] = isDefault;
    if (autoPrint != null) body['auto_print'] = autoPrint;
    if (isActive != null) body['is_active'] = isActive;
    if (notes != null) body['notes'] = notes;
    if (allowedRoles != null) {
      body['allowed_roles'] = allowedRoles.isEmpty ? null : allowedRoles.join(',');
    }

    final response = await dio.patch('$_base/$id', data: body);
    return PrinterConfigModel.fromJson(ApiResponseUtils.object(response));
  }

  Future<PrinterConfigModel> setAsDefault(String id) async {
    final response = await dio.patch('$_base/$id/set-default');
    return PrinterConfigModel.fromJson(ApiResponseUtils.object(response));
  }

  Future<void> remove(String id) async {
    await dio.delete('$_base/$id');
  }
}
