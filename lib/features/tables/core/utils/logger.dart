import 'package:logger/logger.dart';

/// Logger centralizado para el feature de tables/floor plan
/// Configurado para mostrar logs apropiados según el entorno
final tablesLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Level.debug, // Cambiar a Level.warning en producción
);
