/// Professional validators for forms
class Validators {
  /// Email validator
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo electrónico es requerido';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Por favor ingresa un correo válido';
    }

    return null;
  }

  /// Password validator (aligned with backend requirements)
  /// Minimum 8 characters, lowercase, uppercase, number, special character
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }

    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    if (value.length > 100) {
      return 'La contraseña debe tener máximo 100 caracteres';
    }

    // Require lowercase
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'La contraseña debe contener al menos una minúscula';
    }

    // Require uppercase
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'La contraseña debe contener al menos una mayúscula';
    }

    // Require number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'La contraseña debe contener al menos un número';
    }

    // Require special character
    if (!value.contains(RegExp(r'[@$!%*?&]'))) {
      return 'La contraseña debe contener al menos un carácter especial (@\$!%*?&)';
    }

    return null;
  }

  /// Required field validator
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Este campo'} es requerido';
    }
    return null;
  }

  /// Phone number validator (E.164 international format)
  /// Format: +[country code][number] - Example: +573001234567
  static String? phone(String? value) {
    // Phone is optional
    if (value == null || value.isEmpty) {
      return null;
    }

    // E.164 format validation
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');

    if (!phoneRegex.hasMatch(value)) {
      return 'Formato: +[código país][número] (ej: +573001234567)';
    }

    if (value.length > 15) {
      return 'El número debe tener máximo 15 caracteres';
    }

    return null;
  }

  /// Name validator (letters, spaces, hyphens, apostrophes)
  /// Aligned with backend: allows letters, spaces, hyphens, apostrophes
  static String? name(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'El nombre'} es requerido';
    }

    // Allow letters, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\u00f1\u00d1\s'-]+$").hasMatch(value)) {
      return '${fieldName ?? 'El nombre'} solo puede contener letras, espacios, guiones y apóstrofes';
    }

    if (value.trim().length < 3) {
      return '${fieldName ?? 'El nombre'} debe tener al menos 3 caracteres';
    }

    if (value.trim().length > 100) {
      return '${fieldName ?? 'El nombre'} debe tener máximo 100 caracteres';
    }

    return null;
  }

  /// Minimum length validator
  static String? minLength(String? value, int length, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Este campo'} es requerido';
    }

    if (value.length < length) {
      return '${fieldName ?? 'Este campo'} debe tener al menos $length caracteres';
    }

    return null;
  }

  /// Maximum length validator
  static String? maxLength(String? value, int length, {String? fieldName}) {
    if (value != null && value.length > length) {
      return '${fieldName ?? 'Este campo'} debe tener máximo $length caracteres';
    }

    return null;
  }

  /// Confirm password validator
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  /// Number validator
  static String? number(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Este campo'} es requerido';
    }

    if (double.tryParse(value) == null) {
      return 'Por favor ingresa un número válido';
    }

    return null;
  }

  /// Price validator
  static String? price(String? value) {
    final numberError = number(value, fieldName: 'El precio');
    if (numberError != null) return numberError;

    final price = double.parse(value!);
    if (price <= 0) {
      return 'El precio debe ser mayor a 0';
    }

    return null;
  }
}
