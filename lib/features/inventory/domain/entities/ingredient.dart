import 'package:equatable/equatable.dart';

/// Familia de unidades: solo se convierte dentro de la misma familia
/// (kg ↔ g, l ↔ ml). "Unidad" no convierte con nada.
enum UnitFamily { count, mass, volume }

/// Unidad base en la que se lleva el stock de un insumo — coincide con
/// el enum `IngredientUnit` del backend. Todo lo que viaja al servidor
/// (stock, receta, compra) va en ESTA unidad; las conversiones (el
/// cajero escribe "2 kg" de un insumo que se lleva en gramos) se hacen
/// solo en la UI con [convert].
enum IngredientUnit {
  unit('unit', 'Unidad', 'und', UnitFamily.count, 1),
  g('g', 'Gramo', 'g', UnitFamily.mass, 1),
  kg('kg', 'Kilogramo', 'kg', UnitFamily.mass, 1000),
  lb('lb', 'Libra', 'lb', UnitFamily.mass, 500),
  ml('ml', 'Mililitro', 'ml', UnitFamily.volume, 1),
  l('l', 'Litro', 'l', UnitFamily.volume, 1000);

  final String code;
  final String label;
  final String short;
  final UnitFamily family;

  /// Cuántas unidades "chicas" (g / ml / und) equivale 1 de esta.
  /// Libra = 500 g (libra colombiana de mercado, la que usan los
  /// proveedores de carnes/quesos acá).
  final double factor;

  const IngredientUnit(this.code, this.label, this.short, this.family, this.factor);

  static IngredientUnit fromCode(String? code) => IngredientUnit.values
      .firstWhere((u) => u.code == code, orElse: () => IngredientUnit.unit);

  /// Unidades en las que se puede capturar una cantidad de un insumo
  /// que se lleva en esta unidad.
  List<IngredientUnit> get compatible =>
      IngredientUnit.values.where((u) => u.family == family).toList();

  /// Convierte [value] expresado en [from] a esta unidad.
  double convertFrom(double value, IngredientUnit from) {
    if (from.family != family) return value;
    return value * from.factor / factor;
  }
}

/// Insumo / materia prima ("Arepa tipo A", "Queso", "Gaseosa 400 ml").
class Ingredient extends Equatable {
  final String id;
  final String name;
  final IngredientUnit unit;

  /// Stock en la unidad base. Puede ser negativo: la regla es "vender
  /// y avisar", nunca bloquear una venta por inventario.
  final double currentStock;
  final double minStock;

  /// Costo promedio ponderado por unidad base.
  final double avgCost;
  final double? lastCost;
  final String? category;
  final String? sku;
  final bool isActive;
  final String? notes;
  final DateTime? updatedAt;

  /// Creado sin internet, todavía sin id real del servidor.
  bool get isPendingSync => id.startsWith('local_');

  const Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    this.minStock = 0,
    this.avgCost = 0,
    this.lastCost,
    this.category,
    this.sku,
    this.isActive = true,
    this.notes,
    this.updatedAt,
  });

  bool get isOut => currentStock <= 0;
  bool get isLow => !isOut && minStock > 0 && currentStock <= minStock;

  /// Valor del inventario de este insumo (lo negativo no suma).
  double get stockValue => (currentStock > 0 ? currentStock : 0) * avgCost;

  Ingredient copyWith({
    String? id,
    String? name,
    IngredientUnit? unit,
    double? currentStock,
    double? minStock,
    double? avgCost,
    double? lastCost,
    String? category,
    String? sku,
    bool? isActive,
    String? notes,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      avgCost: avgCost ?? this.avgCost,
      lastCost: lastCost ?? this.lastCost,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      updatedAt: updatedAt,
    );
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      unit: IngredientUnit.fromCode(json['unit'] as String?),
      currentStock: _num(json['current_stock']),
      minStock: _num(json['min_stock']),
      avgCost: _num(json['avg_cost']),
      lastCost: json['last_cost'] == null ? null : _num(json['last_cost']),
      category: json['category'] as String?,
      sku: json['sku'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit.code,
        'current_stock': currentStock,
        'min_stock': minStock,
        'avg_cost': avgCost,
        'last_cost': lastCost,
        'category': category,
        'sku': sku,
        'is_active': isActive,
        'notes': notes,
        'updated_at': updatedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        name,
        unit,
        currentStock,
        minStock,
        avgCost,
        lastCost,
        category,
        sku,
        isActive,
        notes,
      ];
}
