import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/services/payment_listener_channel.dart';
import '../../../../core/utils/api_response_utils.dart';

const _kEnabled = 'pn_enabled';
const _kTemplate = 'pn_template';
const _kBankPrefix = 'pn_bank_';

const kSupportedBanks = <String, String>{
  'com.nequi.mobileapp': 'Nequi',
  'com.bancolombia.bancolombia': 'Bancolombia',
  'co.com.davivienda.daviplataapp': 'Daviplata',
  'com.movii.app': 'Movii',
  'com.bbva.bbvanetcash': 'BBVA',
  'co.com.bancobogota.pab': 'Banco Bogotá',
};

class CapturedNotif {
  final String bank;
  final String rawText;
  final String amount;   // vacío si no se pudo extraer
  final bool debugOnly;  // true = notif recibida pero sin monto detectado
  final DateTime time;

  CapturedNotif({
    required this.bank,
    required this.rawText,
    required this.amount,
    required this.debugOnly,
    required this.time,
  });
}

class PaymentListenerController extends GetxController {
  final _prefs = GetIt.instance<SharedPreferences>();
  final _dio = GetIt.instance<Dio>();

  final isEnabled = false.obs;
  final template = 'Llegó {monto} por {banco}'.obs;
  final enabledBanks = <String>{}.obs;
  final hasListenerPermission = false.obs;
  final hasBatteryOptimization = false.obs;

  // Panel de debug: últimas 10 notificaciones bancarias capturadas
  final capturedNotifs = <CapturedNotif>[].obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _loadPrefs();
    _checkPermissions();
    _listenPayments();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _loadPrefs() {
    isEnabled.value = _prefs.getBool(_kEnabled) ?? false;
    template.value = _prefs.getString(_kTemplate) ?? 'Llegó {monto} por {banco}';
    final banks = <String>{};
    for (final pkg in kSupportedBanks.keys) {
      if (_prefs.getBool('$_kBankPrefix$pkg') ?? true) banks.add(pkg);
    }
    enabledBanks.assignAll(banks);
    _syncNative();
  }

  Future<void> _checkPermissions() async {
    hasListenerPermission.value = await PaymentListenerChannel.isNotificationListenerEnabled();
    hasBatteryOptimization.value = await PaymentListenerChannel.isBatteryOptimizationIgnored();
  }

  void _listenPayments() {
    _sub = PaymentListenerChannel.paymentStream.listen(
      _onEvent,
      onError: (e) => debugPrint('[PaymentListener] error: $e'),
    );
  }

  void _onEvent(Map<Object?, Object?> event) {
    final bank = event['bank']?.toString() ?? '';
    final amount = event['amount']?.toString() ?? '';
    final speechText = event['speech_text']?.toString() ?? '';
    final rawText = event['raw_text']?.toString() ?? '';
    final debugOnly = event['debug_only'] == true;

    // Guardar en el panel de debug (máximo 10 entradas)
    capturedNotifs.insert(0, CapturedNotif(
      bank: bank,
      rawText: rawText,
      amount: amount,
      debugOnly: debugOnly,
      time: DateTime.now(),
    ));
    if (capturedNotifs.length > 10) capturedNotifs.removeLast();

    // Solo enviar webhook si hay monto detectado
    if (!debugOnly && amount.isNotEmpty && speechText.isNotEmpty) {
      _sendWebhook(bank: bank, amount: amount, speechText: speechText);
    }
  }

  Future<void> _sendWebhook({
    required String bank,
    required String amount,
    required String speechText,
  }) async {
    try {
      await _dio.post(ApiConstants.paymentNotificationsWebhook, data: {
        'bank': bank,
        'amount': amount,
        'speech_text': speechText,
      });
    } catch (e) {
      debugPrint('[PaymentListener] webhook error: ${ApiResponseUtils.errorMessage(e)}');
    }
  }

  Future<void> setEnabled(bool value) async {
    isEnabled.value = value;
    await _prefs.setBool(_kEnabled, value);
    _syncNative();
  }

  Future<void> setTemplate(String value) async {
    template.value = value;
    await _prefs.setString(_kTemplate, value);
    _syncNative();
  }

  Future<void> toggleBank(String pkg, bool enabled) async {
    if (enabled) {
      enabledBanks.add(pkg);
    } else {
      enabledBanks.remove(pkg);
    }
    await _prefs.setBool('$_kBankPrefix$pkg', enabled);
    _syncNative();
  }

  Future<void> openNotificationSettings() async {
    await PaymentListenerChannel.openNotificationListenerSettings();
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermissions();
  }

  Future<void> requestBatteryOptimization() async {
    await PaymentListenerChannel.requestIgnoreBatteryOptimization();
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermissions();
  }

  Future<void> refreshPermissions() async => _checkPermissions();

  void clearDebugLog() => capturedNotifs.clear();

  Future<void> testTts() async {
    final text = template.value
        .replaceAll('{monto}', '\$50.000')
        .replaceAll('{banco}', 'Nequi')
        .replaceAll('{banco_nombre}', 'Nequi');
    await PaymentListenerChannel.testTts(text);
  }

  void _syncNative() {
    PaymentListenerChannel.updateConfig(
      enabled: isEnabled.value,
      enabledBanks: enabledBanks.toList(),
      template: template.value,
    );
  }
}
