import 'package:equatable/equatable.dart';

/// Crema/sabor reutilizable por categoría (ej. Heladería).
class Flavor extends Equatable {
  final String id;
  final String name;
  final String categoryId;
  final int sortOrder;
  final bool isAvailable;

  const Flavor({
    required this.id,
    required this.name,
    required this.categoryId,
    this.sortOrder = 0,
    this.isAvailable = true,
  });

  @override
  List<Object?> get props => [id, name, categoryId, sortOrder, isAvailable];
}
