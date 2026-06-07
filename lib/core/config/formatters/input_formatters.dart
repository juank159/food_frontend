import 'package:flutter/services.dart';

/// Professional input formatters
class AppInputFormatters {
  /// Phone number formatter (US format)
  /// Example: 1234567890 -> (123) 456-7890
  static TextInputFormatter phoneFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(RegExp(r'\D'), '');

      if (text.length <= 3) {
        return newValue.copyWith(text: text);
      } else if (text.length <= 6) {
        return newValue.copyWith(
          text: '(${text.substring(0, 3)}) ${text.substring(3)}',
        );
      } else {
        return newValue.copyWith(
          text: '(${text.substring(0, 3)}) ${text.substring(3, 6)}-${text.substring(6, text.length > 10 ? 10 : text.length)}',
        );
      }
    });
  }

  /// Credit card number formatter
  /// Example: 1234567890123456 -> 1234 5678 9012 3456
  static TextInputFormatter creditCardFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll(RegExp(r'\s'), '');
      final buffer = StringBuffer();

      for (int i = 0; i < text.length; i++) {
        buffer.write(text[i]);
        final nonZeroIndex = i + 1;
        if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
          buffer.write(' ');
        }
      }

      return newValue.copyWith(
        text: buffer.toString(),
        selection: TextSelection.collapsed(offset: buffer.length),
      );
    });
  }

  /// Price formatter
  /// Allows only numbers with up to 2 decimal places
  static TextInputFormatter priceFormatter() {
    return FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'));
  }

  /// Uppercase formatter
  static TextInputFormatter uppercaseFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      return newValue.copyWith(text: newValue.text.toUpperCase());
    });
  }

  /// No spaces formatter
  static TextInputFormatter noSpacesFormatter() {
    return FilteringTextInputFormatter.deny(RegExp(r'\s'));
  }

  /// Only letters formatter
  static TextInputFormatter onlyLettersFormatter() {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'));
  }

  /// Only numbers formatter
  static TextInputFormatter onlyNumbersFormatter() {
    return FilteringTextInputFormatter.digitsOnly;
  }
}
