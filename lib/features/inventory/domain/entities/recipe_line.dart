import 'package:equatable/equatable.dart';

/// De qué cuelga una receta: el producto, una variante o un extra.
enum RecipeOwnerType {
  product('product'),
  variant('variant'),
  modifier('modifier');

  final String code;
  const RecipeOwnerType(this.code);
}

/// Una línea de receta: 1 unidad del dueño consume [quantity] (en la
/// unidad base del insumo) de [ingredientId].
class RecipeLine extends Equatable {
  final String ingredientId;
  final double quantity;
  final String? productId;
  final String? variantId;
  final String? modifierId;

  const RecipeLine({
    required this.ingredientId,
    required this.quantity,
    this.productId,
    this.variantId,
    this.modifierId,
  });

  RecipeOwnerType get ownerType => productId != null
      ? RecipeOwnerType.product
      : variantId != null
          ? RecipeOwnerType.variant
          : RecipeOwnerType.modifier;

  String get ownerId => productId ?? variantId ?? modifierId ?? '';

  factory RecipeLine.fromJson(Map<String, dynamic> json) {
    final q = json['quantity'];
    return RecipeLine(
      ingredientId: json['ingredient_id'] as String,
      quantity: q is num ? q.toDouble() : double.tryParse(q.toString()) ?? 0,
      productId: json['product_id'] as String?,
      variantId: json['variant_id'] as String?,
      modifierId: json['modifier_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'quantity': quantity,
        'product_id': productId,
        'variant_id': variantId,
        'modifier_id': modifierId,
      };

  @override
  List<Object?> get props => [ingredientId, quantity, productId, variantId, modifierId];
}
