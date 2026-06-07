library;

/// Table Enums
/// Enumeraciones para el módulo de mesas

/// Estado de una mesa
enum TableStatus {
  available('available', 'Disponible'),
  occupied('occupied', 'Ocupada'),
  reserved('reserved', 'Reservada'),
  cleaning('cleaning', 'En Limpieza'),
  maintenance('maintenance', 'En Mantenimiento'),
  unavailable('unavailable', 'No Disponible');

  final String value;
  final String displayName;

  const TableStatus(this.value, this.displayName);

  static TableStatus fromString(String value) {
    return TableStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TableStatus.available,
    );
  }

  // Helpers para estados
  bool get isAvailableForOrders =>
      this == TableStatus.available || this == TableStatus.reserved;
  bool get isOccupied => this == TableStatus.occupied;
  bool get canBeReserved => this == TableStatus.available;
}

/// Tipo de mesa según capacidad o zona
enum TableType {
  standard('standard', 'Estándar'),
  vip('vip', 'VIP'),
  outdoor('outdoor', 'Exterior'),
  bar('bar', 'Barra'),
  private('private', 'Privado'),
  booth('booth', 'Booth');

  final String value;
  final String displayName;

  const TableType(this.value, this.displayName);

  static TableType fromString(String value) {
    return TableType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TableType.standard,
    );
  }
}

/// Forma de la mesa
enum TableShape {
  round('round', 'Redonda'),
  square('square', 'Cuadrada'),
  rectangular('rectangular', 'Rectangular'),
  oval('oval', 'Ovalada');

  final String value;
  final String displayName;

  const TableShape(this.value, this.displayName);

  static TableShape fromString(String value) {
    return TableShape.values.firstWhere(
      (shape) => shape.value == value,
      orElse: () => TableShape.rectangular,
    );
  }
}
