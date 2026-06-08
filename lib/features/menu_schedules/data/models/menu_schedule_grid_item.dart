/// Modelo del item del endpoint `GET /menu-schedules/grid`.
///
/// Un item por producto del tenant. `schedule` es null si el producto
/// NO está programado para la fecha consultada — la UI muestra el
/// toggle en off; al activarlo se llama `/menu-schedules/toggle` que
/// crea el schedule.
class MenuScheduleGridItem {
  final ProductLite product;
  final ScheduleLite? schedule;

  bool get isProgrammed => schedule != null && schedule!.isActive;
  String? get scheduleId => schedule?.id;

  const MenuScheduleGridItem({
    required this.product,
    required this.schedule,
  });

  factory MenuScheduleGridItem.fromJson(Map<String, dynamic> json) {
    return MenuScheduleGridItem(
      product: ProductLite.fromJson(
        json['product'] as Map<String, dynamic>,
      ),
      schedule: json['schedule'] == null
          ? null
          : ScheduleLite.fromJson(
              json['schedule'] as Map<String, dynamic>,
            ),
    );
  }
}

/// Subset del producto necesario para renderizar la grilla.
class ProductLite {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final String? categoryId;
  final String? categoryName;

  const ProductLite({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.basePrice,
    required this.categoryId,
    required this.categoryName,
  });

  factory ProductLite.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>?;
    return ProductLite(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      basePrice: _parseDouble(json['base_price']),
      categoryId: json['category_id'] as String?,
      categoryName: cat?['name'] as String?,
    );
  }
}

/// Subset del schedule necesario para renderizar la grilla.
class ScheduleLite {
  final String id;
  final bool isActive;
  final String? availableFrom;
  final String? availableTo;
  final int? dailyQuantityLimit;
  final double? specialPrice;
  final String? badgeLabel;

  const ScheduleLite({
    required this.id,
    required this.isActive,
    required this.availableFrom,
    required this.availableTo,
    required this.dailyQuantityLimit,
    required this.specialPrice,
    required this.badgeLabel,
  });

  factory ScheduleLite.fromJson(Map<String, dynamic> json) {
    return ScheduleLite(
      id: json['id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      availableFrom: json['available_from'] as String?,
      availableTo: json['available_to'] as String?,
      dailyQuantityLimit: (json['daily_quantity_limit'] as num?)?.toInt(),
      specialPrice: _parseNullableDouble(json['special_price']),
      badgeLabel: json['badge_label'] as String?,
    );
  }
}

double _parseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _parseNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
