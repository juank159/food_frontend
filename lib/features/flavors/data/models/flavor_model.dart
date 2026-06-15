import '../../domain/entities/flavor.dart';

/// Modelo de datos para sabores/cremas. JSON hand-written (sin build_runner).
class FlavorModel extends Flavor {
  const FlavorModel({
    required super.id,
    required super.name,
    required super.categoryId,
    super.sortOrder,
    super.isAvailable,
  });

  factory FlavorModel.fromJson(Map<String, dynamic> json) {
    return FlavorModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isAvailable: (json['is_available'] as bool?) ?? true,
    );
  }
}
