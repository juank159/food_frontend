import 'dart:io';
import 'package:flutter/services.dart';

/// Bridge entre Flutter y el [PaymentNotificationListenerService] de Android.
/// Solo funciona en Android; en iOS todos los métodos son no-ops.
class PaymentListenerChannel {
  PaymentListenerChannel._();

  static const _events = EventChannel('com.foodplatform/payment_notifications');
  static const _methods = MethodChannel('com.foodplatform/payment_methods');

  /// Stream de eventos de pago detectados por el servicio nativo.
  /// Cada evento es un Map con: bank, bank_package, amount, speech_text, raw_text.
  static Stream<Map<Object?, Object?>> get paymentStream {
    if (!Platform.isAndroid) return const Stream.empty();
    return _events.receiveBroadcastStream().cast<Map<Object?, Object?>>();
  }

  static Future<bool> isNotificationListenerEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methods.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationListenerSettings() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod('openNotificationListenerSettings');
  }

  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methods.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod('requestIgnoreBatteryOptimization');
  }

  /// Sincroniza la configuración al servicio nativo (enabled banks, template).
  static Future<void> updateConfig({
    required bool enabled,
    required List<String> enabledBanks,
    required String template,
  }) async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod('updateConfig', {
      'enabled': enabled,
      'enabled_banks': enabledBanks,
      'template': template,
    });
  }

  /// Habla el texto usando TTS nativo. Útil para probar que el audio funciona.
  static Future<void> testTts(String text) async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod('testTts', {'text': text});
  }
}
