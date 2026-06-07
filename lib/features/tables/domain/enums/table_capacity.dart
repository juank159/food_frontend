// lib/features/tables/domain/enums/table_capacity.dart

/// Capacidad de las mesas del restaurante
enum TableCapacity {
  /// Mesa para 2 personas
  two,

  /// Mesa para 4 personas
  four,

  /// Mesa para 6 personas
  six,

  /// Mesa para 8 personas
  eight,

  /// Mesa para 10 personas
  ten,
}

extension TableCapacityExtension on TableCapacity {
  int get seats {
    switch (this) {
      case TableCapacity.two:
        return 2;
      case TableCapacity.four:
        return 4;
      case TableCapacity.six:
        return 6;
      case TableCapacity.eight:
        return 8;
      case TableCapacity.ten:
        return 10;
    }
  }

  String get displayName {
    switch (this) {
      case TableCapacity.two:
        return 'Mesa 2 Puestos';
      case TableCapacity.four:
        return 'Mesa 4 Puestos';
      case TableCapacity.six:
        return 'Mesa 6 Puestos';
      case TableCapacity.eight:
        return 'Mesa 8 Puestos';
      case TableCapacity.ten:
        return 'Mesa 10 Puestos';
    }
  }

  String get shortName {
    switch (this) {
      case TableCapacity.two:
        return '2P';
      case TableCapacity.four:
        return '4P';
      case TableCapacity.six:
        return '6P';
      case TableCapacity.eight:
        return '8P';
      case TableCapacity.ten:
        return '10P';
    }
  }

  /// Ancho visual de la mesa en píxeles
  double get visualWidth {
    switch (this) {
      case TableCapacity.two:
        return 60.0;
      case TableCapacity.four:
        return 80.0;
      case TableCapacity.six:
        return 120.0;
      case TableCapacity.eight:
        return 160.0;
      case TableCapacity.ten:
        return 180.0;
    }
  }

  /// Alto visual de la mesa en píxeles
  double get visualHeight {
    switch (this) {
      case TableCapacity.two:
        return 60.0;
      case TableCapacity.four:
        return 80.0;
      case TableCapacity.six:
        return 80.0;
      case TableCapacity.eight:
        return 100.0;
      case TableCapacity.ten:
        return 120.0;
    }
  }

  /// Forma de la mesa (solo rectangular o cuadrada)
  TableShape get shape {
    switch (this) {
      case TableCapacity.two:
        return TableShape.square; // Mesa cuadrada pequeña
      case TableCapacity.four:
        return TableShape.square; // Mesa cuadrada
      case TableCapacity.six:
        return TableShape.rectangular; // Mesa rectangular
      case TableCapacity.eight:
        return TableShape.rectangular; // Mesa rectangular larga
      case TableCapacity.ten:
        return TableShape.rectangular; // Mesa rectangular muy larga
    }
  }
}

enum TableShape {
  square,
  round,
  rectangular,
  oval,
}

/// Extension para parsear strings de capacidad
extension TableCapacityParser on String {
  /// Convierte un string como "two", "four", "six" a su número correspondiente
  int? toCapacityNumber() {
    switch (toLowerCase()) {
      case 'two':
        return 2;
      case 'four':
        return 4;
      case 'six':
        return 6;
      case 'eight':
        return 8;
      case 'ten':
        return 10;
      default:
        // Si ya es un número, intentar parsearlo
        return int.tryParse(this);
    }
  }
}
