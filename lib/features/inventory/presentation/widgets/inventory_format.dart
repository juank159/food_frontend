import 'package:intl/intl.dart';
import '../../domain/entities/ingredient.dart';

final NumberFormat _qty = NumberFormat('#,##0.###', 'es_CO');

/// Número para mostrar (1.250,5) — hasta 3 decimales, sin ceros de más.
String fmtNumber(double v) => _qty.format(v);

/// Cantidad legible en la unidad más cómoda: 1.250 g → "1,25 kg",
/// 2.000 ml → "2 l". La unidad base del insumo no cambia, es solo vista.
String fmtQty(double v, IngredientUnit unit) {
  if (unit == IngredientUnit.g && v.abs() >= 1000) {
    return '${fmtNumber(v / 1000)} kg';
  }
  if (unit == IngredientUnit.ml && v.abs() >= 1000) {
    return '${fmtNumber(v / 1000)} l';
  }
  return '${fmtNumber(v)} ${unit.short}';
}

/// Cantidad con signo para movimientos ("+200 und", "−1,5 kg").
String fmtDelta(double v, IngredientUnit unit) {
  final s = fmtQty(v.abs(), unit);
  if (v > 0) return '+$s';
  if (v < 0) return '−$s';
  return s;
}

/// Lee lo que el usuario escribe: acepta "1,5" y "1.5" (sin separador
/// de miles en el campo).
double? parseQty(String raw) {
  final t = raw.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  final normalized = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(normalized);
}

/// Precio por unidad base legible: "$800 / und", "$20 / g".
String unitCostLabel(String money, IngredientUnit unit) => '$money / ${unit.short}';
