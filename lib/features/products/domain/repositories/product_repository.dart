import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/product.dart';
import '../entities/product_variant.dart';
import '../entities/modifier.dart';
import '../entities/modifier_group.dart';

/// Product Repository Interface (Domain Layer)
/// Define el contrato para operaciones con productos
abstract class ProductRepository {
  /// Obtener lista de productos con filtros opcionales
  Future<Either<Failure, List<Product>>> getProducts({
    String? categoryId,
    bool? isAvailable,
    String? search,
    List<String>? tags,
    int? page,
    int? limit,
  });

  /// Obtener un producto por ID
  Future<Either<Failure, Product>> getProductById(String id);

  /// Obtener productos disponibles
  Future<Either<Failure, List<Product>>> getAvailableProducts();

  /// Obtener productos con stock bajo
  Future<Either<Failure, List<Product>>> getLowStockProducts();

  /// Obtener productos por categoría
  Future<Either<Failure, List<Product>>> getProductsByCategory(
    String categoryId,
  );

  /// Buscar producto por SKU
  Future<Either<Failure, Product>> getProductBySku(String sku);

  /// Crear un nuevo producto
  Future<Either<Failure, Product>> createProduct({
    required String name,
    required double basePrice,
    required String sku,
    required String categoryId,
    String? description,
    double? cost,
    bool? requiresPreparation,
    int? preparationTime,
    String? imageUrl,
    List<String>? images,
    String? barcode,
    bool? isAvailable,
    bool? isFeatured,
    List<String>? tags,
    List<String>? allergens,
    Map<String, dynamic>? nutritionalInfo,
    bool? trackInventory,
    int? currentStock,
    int? minStockAlert,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  });

  /// Actualizar un producto
  Future<Either<Failure, Product>> updateProduct({
    required String id,
    String? name,
    double? basePrice,
    String? sku,
    String? categoryId,
    String? description,
    double? cost,
    bool? requiresPreparation,
    int? preparationTime,
    String? imageUrl,
    List<String>? images,
    String? barcode,
    bool? isAvailable,
    bool? isFeatured,
    List<String>? tags,
    List<String>? allergens,
    Map<String, dynamic>? nutritionalInfo,
    bool? trackInventory,
    int? currentStock,
    int? minStockAlert,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  });

  /// Actualizar stock de un producto
  Future<Either<Failure, Product>> updateStock({
    required String id,
    required int quantity,
    required String operation, // 'ADD' o 'SUBTRACT'
  });

  /// Eliminar un producto
  Future<Either<Failure, void>> deleteProduct(String id);

  /// Crear una nueva variante
  Future<Either<Failure, ProductVariant>> createVariant({
    required String productId,
    required String name,
    required double priceModifier,
    String? description,
    bool? isDefault,
    int? sortOrder,
    bool? isAvailable,
    String? sku,
  });

  /// Actualizar una variante
  Future<Either<Failure, ProductVariant>> updateVariant({
    required String variantId,
    String? name,
    double? priceModifier,
    String? description,
    bool? isDefault,
    int? sortOrder,
    bool? isAvailable,
    String? sku,
  });

  /// Eliminar una variante
  Future<Either<Failure, void>> deleteVariant(String variantId);

  // Modifier methods
  /// Obtener modificadores
  Future<Either<Failure, List<Modifier>>> getModifiers({
    String? productId,
    String? categoryId,
    bool? isAvailable,
  });

  /// Obtener un modificador por ID
  Future<Either<Failure, Modifier>> getModifierById(String id);

  /// Crear modificador
  Future<Either<Failure, Modifier>> createModifier({
    required String name,
    String? description,
    required ModifierType type,
    required double price,
    int? maxQuantity,
    bool? isAvailable,
    int? sortOrder,
    List<String>? productIds,
    List<String>? categoryIds,
  });

  /// Actualizar modificador
  Future<Either<Failure, Modifier>> updateModifier({
    required String id,
    String? name,
    String? description,
    ModifierType? type,
    double? price,
    int? maxQuantity,
    bool? isAvailable,
    int? sortOrder,
    List<String>? productIds,
    List<String>? categoryIds,
  });

  /// Eliminar modificador
  Future<Either<Failure, void>> deleteModifier(String id);

  // Modifier Group methods
  /// Obtener grupos de modificadores
  Future<Either<Failure, List<ModifierGroup>>> getModifierGroups({
    String? productId,
    bool? isActive,
  });

  /// Crear grupo de modificadores
  Future<Either<Failure, ModifierGroup>> createModifierGroup({
    required String name,
    required String productId,
    String? description,
    required SelectionType selectionType,
    int? minSelections,
    int? maxSelections,
    bool? isRequired,
    int? sortOrder,
    List<String>? modifierIds,
  });

  /// Actualizar grupo de modificadores
  Future<Either<Failure, ModifierGroup>> updateModifierGroup({
    required String id,
    String? name,
    String? description,
    SelectionType? selectionType,
    int? minSelections,
    int? maxSelections,
    bool? isRequired,
    int? sortOrder,
  });

  /// Eliminar grupo de modificadores
  Future<Either<Failure, void>> deleteModifierGroup(String id);

  /// Asociar modificadores a un grupo (relación N:M)
  Future<Either<Failure, ModifierGroup>> addModifiersToGroup({
    required String groupId,
    required List<String> modifierIds,
  });

  /// Quitar un modificador de un grupo
  Future<Either<Failure, void>> removeModifierFromGroup({
    required String groupId,
    required String modifierId,
  });
}
