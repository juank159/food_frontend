// lib/features/tables/domain/enums/floor_plan_icons.dart

import 'package:flutter/material.dart';

/// Tipos de iconos de cocina/comida
enum KitchenIconType {
  restaurant('restaurant', 'Restaurante', Icons.restaurant),
  fastFood('fastFood', 'Comida Rápida', Icons.fastfood),
  pizza('pizza', 'Pizzería', Icons.local_pizza),
  iceCream('iceCream', 'Heladería', Icons.icecream),
  coffee('coffee', 'Cafetería', Icons.local_cafe),
  bakery('bakery', 'Panadería', Icons.bakery_dining),
  ramen('ramen', 'Ramen/Sopas', Icons.ramen_dining),
  dining('dining', 'Comedor', Icons.dining),
  breakfast('breakfast', 'Desayunos', Icons.free_breakfast),
  brunch('brunch', 'Brunch', Icons.brunch_dining);

  final String value;
  final String displayName;
  final IconData icon;

  const KitchenIconType(this.value, this.displayName, this.icon);
}

/// Tipos de iconos de decoración
enum DecorationIconType {
  plant('plant', 'Planta', Icons.local_florist),
  potted('potted', 'Maceta', Icons.park),
  grass('grass', 'Césped', Icons.grass),
  forest('forest', 'Árbol', Icons.forest),
  flower('flower', 'Flores', Icons.eco),
  art('art', 'Arte', Icons.palette),
  frame('frame', 'Cuadro', Icons.image),
  lamp('lamp', 'Lámpara', Icons.lightbulb_outline),
  mirror('mirror', 'Espejo', Icons.photo_size_select_actual),
  curtain('curtain', 'Cortina', Icons.weekend);

  final String value;
  final String displayName;
  final IconData icon;

  const DecorationIconType(this.value, this.displayName, this.icon);
}

/// Tipos de iconos de puertas
enum DoorIconType {
  sliding('sliding', 'Puerta Corredera', Icons.door_sliding),
  main('main', 'Puerta Principal', Icons.meeting_room),
  back('back', 'Puerta Trasera', Icons.sensor_door),
  doubleDoor('double', 'Puerta Doble', Icons.double_arrow),
  emergency('emergency', 'Salida Emergencia', Icons.exit_to_app),
  revolving('revolving', 'Puerta Giratoria', Icons.autorenew),
  garage('garage', 'Puerta Garaje', Icons.garage);

  final String value;
  final String displayName;
  final IconData icon;

  const DoorIconType(this.value, this.displayName, this.icon);
}

/// Tipos de iconos de bar
enum BarIconType {
  cocktail('cocktail', 'Cócteles', Icons.local_bar),
  wine('wine', 'Vinos', Icons.wine_bar),
  beer('beer', 'Cervecería', Icons.sports_bar),
  liquor('liquor', 'Licorería', Icons.liquor),
  nightlife('nightlife', 'Bar Nocturno', Icons.nightlife),
  tapas('tapas', 'Tapas/Snacks', Icons.tapas);

  final String value;
  final String displayName;
  final IconData icon;

  const BarIconType(this.value, this.displayName, this.icon);
}

/// Tipos de iconos de baño
enum BathroomIconType {
  wc('wc', 'Baño', Icons.wc),
  accessible('accessible', 'Baño Accesible', Icons.accessible),
  male('male', 'Baño Hombres', Icons.man),
  female('female', 'Baño Mujeres', Icons.woman),
  family('family', 'Baño Familiar', Icons.family_restroom),
  baby('baby', 'Cambiador', Icons.baby_changing_station);

  final String value;
  final String displayName;
  final IconData icon;

  const BathroomIconType(this.value, this.displayName, this.icon);
}

/// Modelo para almacenar información completa del icono
class FloorPlanIconData {
  final String category;
  final String subType;
  final IconData icon;
  final String displayName;

  FloorPlanIconData({
    required this.category,
    required this.subType,
    required this.icon,
    required this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'subType': subType,
      'displayName': displayName,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
    };
  }

  factory FloorPlanIconData.fromJson(Map<String, dynamic> json) {
    return FloorPlanIconData(
      category: json['category'] as String,
      subType: json['subType'] as String,
      displayName: json['displayName'] as String,
      icon: IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String?,
      ),
    );
  }
}
