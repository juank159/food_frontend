import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Input Formatter para agregar separadores de miles
/// Formatea números mientras se escriben (ej: 8000 -> 8.000)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'es_CO');
  final bool allowDecimals;

  ThousandsSeparatorInputFormatter({this.allowDecimals = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si el texto está vacío, retornar
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remover separadores y puntos decimales para obtener solo números
    String cleanedText = newValue.text.replaceAll('.', '').replaceAll(',', '');

    // Si allowDecimals es true, manejar decimales
    if (allowDecimals && cleanedText.contains('.')) {
      final parts = cleanedText.split('.');
      if (parts.length == 2) {
        final integerPart = parts[0];
        final decimalPart = parts[1];

        if (integerPart.isEmpty) {
          return newValue;
        }

        final formattedInteger = _formatNumber(integerPart);
        final formattedText = '$formattedInteger,$decimalPart';

        return TextEditingValue(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
    }

    // Validar que solo contenga dígitos
    if (!RegExp(r'^\d+$').hasMatch(cleanedText)) {
      return oldValue;
    }

    // Formatear el número
    final formattedText = _formatNumber(cleanedText);

    // Calcular la nueva posición del cursor
    int selectionIndex = formattedText.length;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }

  String _formatNumber(String number) {
    if (number.isEmpty) return '';

    final int value = int.tryParse(number) ?? 0;
    if (value == 0 && number != '0') return '';

    return _formatter.format(value);
  }
}

/// Input Formatter para números decimales con separadores de miles
/// Permite decimales y formatea la parte entera con separadores
class DecimalThousandsSeparatorInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  DecimalThousandsSeparatorInputFormatter({this.decimalDigits = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Permitir solo dígitos, punto y coma
    String text = newValue.text;

    // Reemplazar punto por coma si se usa como separador decimal
    text = text.replaceAll('.', ',');

    // Validar formato básico
    if (!RegExp(r'^[\d,]*$').hasMatch(text)) {
      return oldValue;
    }

    // Dividir en parte entera y decimal
    List<String> parts = text.split(',');

    // No permitir más de una coma
    if (parts.length > 2) {
      return oldValue;
    }

    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    // Formatear parte entera
    if (integerPart.isNotEmpty) {
      final int? value = int.tryParse(integerPart);
      if (value == null) return oldValue;

      final formatter = NumberFormat('#,###', 'es_CO');
      integerPart = formatter.format(value);
    }

    // Limitar decimales
    if (decimalPart != null && decimalPart.length > decimalDigits) {
      decimalPart = decimalPart.substring(0, decimalDigits);
    }

    // Construir texto formateado
    String formattedText = integerPart;
    if (decimalPart != null) {
      formattedText += ',$decimalPart';
    } else if (parts.length > 1) {
      // Mantener la coma si el usuario la acaba de escribir
      formattedText += ',';
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

/// Utilidad para convertir texto formateado a número
class NumberFormatHelper {
  /// Convierte texto con separadores a double
  /// Ejemplo: "8.000" -> 8000.0
  /// Ejemplo: "8.000,50" -> 8000.50
  static double? parseFormattedNumber(String formattedText) {
    if (formattedText.isEmpty) return null;

    // Remover puntos (separadores de miles)
    String cleanedText = formattedText.replaceAll('.', '');

    // Reemplazar coma por punto (separador decimal)
    cleanedText = cleanedText.replaceAll(',', '.');

    return double.tryParse(cleanedText);
  }

  /// Convierte texto con separadores a int
  /// Ejemplo: "8.000" -> 8000
  static int? parseFormattedInt(String formattedText) {
    if (formattedText.isEmpty) return null;

    // Remover todos los separadores
    String cleanedText = formattedText.replaceAll('.', '').replaceAll(',', '');

    return int.tryParse(cleanedText);
  }

  /// Formatea un número a string con separadores
  /// Ejemplo: 8000 -> "8.000"
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,###', 'es_CO');
    return formatter.format(number);
  }

  /// Formatea un número decimal a string con separadores
  /// Ejemplo: 8000.50 -> "8.000,50"
  static String formatDecimal(double number, {int decimals = 2}) {
    final formatter = NumberFormat('#,##0.${'0' * decimals}', 'es_CO');
    return formatter.format(number);
  }
}
