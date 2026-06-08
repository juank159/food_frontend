import 'package:dio/dio.dart';

import '../../../core/config/constants/api_constants.dart';
import '../../../core/utils/api_response_utils.dart';
import 'models/menu_schedule_grid_item.dart';

class MenuSchedulesRemoteDataSource {
  MenuSchedulesRemoteDataSource({required this.dio});
  final Dio dio;

  /// Trae la grilla (producto + flag programado) para una fecha.
  /// Si [date] es null → backend usa HOY.
  Future<List<MenuScheduleGridItem>> grid({String? date}) async {
    final response = await dio.get(
      ApiConstants.menuSchedulesGrid,
      queryParameters: date == null ? null : {'date': date},
    );
    return ApiResponseUtils.list(response)
        .map(
          (e) => MenuScheduleGridItem.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Toggle on/off de UN producto para una fecha. El backend retorna
  /// `{ enabled, schedule }` donde schedule es null si quedó off.
  Future<ToggleResult> toggle({
    required String productId,
    required String date,
  }) async {
    final response = await dio.post(
      ApiConstants.menuSchedulesToggle,
      data: {'product_id': productId, 'date': date},
    );
    final payload = ApiResponseUtils.object(response);
    return ToggleResult(
      enabled: payload['enabled'] as bool? ?? false,
      schedule: payload['schedule'] == null
          ? null
          : ScheduleLite.fromJson(
              payload['schedule'] as Map<String, dynamic>,
            ),
    );
  }

  /// Atajo: programa TODOS los productos para una fecha.
  Future<ProgramAllResult> programAllForDay({
    String? date,
    bool replace = false,
  }) async {
    final response = await dio.post(
      ApiConstants.menuSchedulesProgramAll,
      data: {
        if (date != null) 'date': date,
        'replace': replace,
      },
    );
    final payload = ApiResponseUtils.object(response);
    return ProgramAllResult(
      created: (payload['created'] as num?)?.toInt() ?? 0,
      skipped: (payload['skipped'] as num?)?.toInt() ?? 0,
      deleted: (payload['deleted'] as num?)?.toInt() ?? 0,
    );
  }

  /// Bulk toggle (poner is_active=true/false para una lista de schedules).
  Future<int> bulkToggle({
    required List<String> ids,
    required bool isActive,
  }) async {
    final response = await dio.post(
      '${ApiConstants.menuSchedules}/bulk-toggle',
      data: {'ids': ids, 'is_active': isActive},
    );
    final payload = ApiResponseUtils.object(response);
    return (payload['updated'] as num?)?.toInt() ?? 0;
  }

  /// Update detallado de un schedule (precio especial, horario, etc.).
  Future<void> update(
    String id, {
    bool? isActive,
    String? availableFrom,
    String? availableTo,
    int? dailyQuantityLimit,
    double? specialPrice,
    String? badgeLabel,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (isActive != null) body['is_active'] = isActive;
    if (availableFrom != null) body['available_from'] = availableFrom;
    if (availableTo != null) body['available_to'] = availableTo;
    if (dailyQuantityLimit != null) {
      body['daily_quantity_limit'] = dailyQuantityLimit;
    }
    if (specialPrice != null) body['special_price'] = specialPrice;
    if (badgeLabel != null) body['badge_label'] = badgeLabel;
    if (notes != null) body['notes'] = notes;

    await dio.patch('${ApiConstants.menuSchedules}/$id', data: body);
  }
}

class ToggleResult {
  final bool enabled;
  final ScheduleLite? schedule;
  const ToggleResult({required this.enabled, required this.schedule});
}

class ProgramAllResult {
  final int created;
  final int skipped;
  final int deleted;
  const ProgramAllResult({
    required this.created,
    required this.skipped,
    required this.deleted,
  });
}
