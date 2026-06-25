import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';

/// Category Repository
/// Contrato de repositorio para categorías
abstract class CategoryRepository {
  /// Obtiene todas las categorías
  Future<Either<Failure, List<Category>>> getCategories({
    bool? isActive,
    String? search,
    int? page,
    int? limit,
  });

  /// Obtiene el árbol de categorías (estructura jerárquica)
  Future<Either<Failure, List<Category>>> getCategoryTree({
    bool? isActive,
  });

  /// Obtiene solo las categorías activas
  Future<Either<Failure, List<Category>>> getActiveCategories();

  /// Obtiene solo las categorías raíz (sin padre)
  Future<Either<Failure, List<Category>>> getRootCategories({
    bool? isActive,
  });

  /// Obtiene una categoría por ID
  Future<Either<Failure, Category>> getCategoryById(String id);

  /// Obtiene las subcategorías de una categoría padre
  Future<Either<Failure, List<Category>>> getSubcategories(String parentId);

  /// Busca categorías por nombre o descripción
  Future<Either<Failure, List<Category>>> searchCategories(String query);

  Future<Either<Failure, Category>> createCategory({
    required String name,
    required String description,
    String? imageUrl,
    String? color,
    String? icon,
    bool isActive = true,
    int displayOrder = 0,
    String? parentId,
    bool printsKitchen = true,
    List<String>? quickNotes,
    String? flavorLabel,
  });

  Future<Either<Failure, Category>> updateCategory({
    required String id,
    String? name,
    String? description,
    String? imageUrl,
    String? color,
    String? icon,
    bool? isActive,
    int? displayOrder,
    String? parentId,
    bool? printsKitchen,
    List<String>? quickNotes,
    String? flavorLabel,
  });

  /// Elimina una categoría
  Future<Either<Failure, void>> deleteCategory(String id);
}
