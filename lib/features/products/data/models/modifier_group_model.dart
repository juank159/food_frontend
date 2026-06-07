import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../domain/entities/modifier_group.dart';
import 'modifier_model.dart';

part 'modifier_group_model.g.dart';

/// Modifier Group Model
/// Modelo de datos para grupos de modificadores con serialización JSON
@JsonSerializable()
class ModifierGroupModel {
  final String id;

  @JsonKey(name: 'product_id')
  final String productId;

  final String name;
  final String? description;

  @JsonKey(name: 'selection_type')
  final String selectionType;

  @JsonKey(name: 'min_selections')
  final int minSelections;

  @JsonKey(name: 'max_selections')
  final int? maxSelections;

  @JsonKey(name: 'is_required')
  final bool isRequired;

  @JsonKey(name: 'sort_order')
  final int sortOrder;

  @JsonKey(name: 'is_active')
  final bool isActive;

  final List<ModifierModel> modifiers;

  const ModifierGroupModel({
    required this.id,
    required this.productId,
    required this.name,
    this.description,
    required this.selectionType,
    this.minSelections = 0,
    this.maxSelections,
    this.isRequired = false,
    this.sortOrder = 0,
    this.isActive = true,
    this.modifiers = const [],
  });

  /// Crear desde JSON
  factory ModifierGroupModel.fromJson(Map<String, dynamic> json) =>
      _$ModifierGroupModelFromJson(json);

  /// Convertir a JSON
  Map<String, dynamic> toJson() => _$ModifierGroupModelToJson(this);

  /// Convertir a Entity
  ModifierGroup toEntity() {
    return ModifierGroup(
      id: id,
      productId: productId,
      name: name,
      description: description,
      selectionType: SelectionType.fromString(selectionType),
      minSelections: minSelections,
      maxSelections: maxSelections,
      isRequired: isRequired,
      sortOrder: sortOrder,
      isActive: isActive,
      modifiers: modifiers.map((m) => m.toEntity()).toList(),
    );
  }

  /// Crear desde Entity
  factory ModifierGroupModel.fromEntity(ModifierGroup entity) {
    return ModifierGroupModel(
      id: entity.id,
      productId: entity.productId,
      name: entity.name,
      description: entity.description,
      selectionType: entity.selectionType.value,
      minSelections: entity.minSelections,
      maxSelections: entity.maxSelections,
      isRequired: entity.isRequired,
      sortOrder: entity.sortOrder,
      isActive: entity.isActive,
      modifiers: entity.modifiers.map((m) => ModifierModel.fromEntity(m)).toList(),
    );
  }
}
