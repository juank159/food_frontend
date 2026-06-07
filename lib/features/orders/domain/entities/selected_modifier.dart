import 'package:equatable/equatable.dart';

/// Selected Modifier
/// Representa un modificador seleccionado para tracking en el carrito
/// Se usa cuando el usuario está seleccionando modificadores antes de agregar al carrito
class SelectedModifier extends Equatable {
  /// ID del modificador original
  final String modifierId;

  /// Nombre del modificador (para display)
  final String name;

  /// Precio del modificador
  final double price;

  /// Cantidad seleccionada
  final int quantity;

  const SelectedModifier({
    required this.modifierId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  /// Calcular el subtotal
  double get subtotal => price * quantity;

  /// Verifica si tiene costo
  bool get hasCost => price > 0;

  /// Crear copia con cambios
  SelectedModifier copyWith({
    String? modifierId,
    String? name,
    double? price,
    int? quantity,
  }) {
    return SelectedModifier(
      modifierId: modifierId ?? this.modifierId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Convertir a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'modifier_id': modifierId,
      'quantity': quantity,
      'price': price,
    };
  }

  /// Crear desde Modifier entity (cuando el usuario selecciona un modificador)
  factory SelectedModifier.fromModifier({
    required String modifierId,
    required String name,
    required double price,
    int quantity = 1,
  }) {
    return SelectedModifier(
      modifierId: modifierId,
      name: name,
      price: price,
      quantity: quantity,
    );
  }

  @override
  List<Object?> get props => [modifierId, name, price, quantity];

  @override
  String toString() {
    return 'SelectedModifier(id: $modifierId, name: $name, qty: $quantity, price: $price)';
  }
}
