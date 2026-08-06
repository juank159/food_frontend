import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/services/payment_listener_channel.dart';
import '../../../../core/utils/api_response_utils.dart';

// SharedPreferences keys
const _kEnabled = 'pn_enabled';
const _kTemplate = 'pn_template';
const _kBankPrefix = 'pn_bank_';

/// Bancos colombianos soportados: packageName → nombre amigable.
const kSupportedBanks = <String, String>{
  'com.nequi.mobileapp': 'Nequi',
  'com.bancolombia.bancolombia': 'Bancolombia',
  'co.com.davivienda.daviplataapp': 'Daviplata',
  'com.movii.app': 'Movii',
  'com.bbva.bbvanetcash': 'BBVA',
  'co.com.bancobogota.pab': 'Banco Bogotá',
};

class PaymentListenerController extends GetxController {
  final _prefs = GetIt.instance<SharedPreferences>();
  final _dio = GetIt.instance<Dio>();

  // ── Estado reactivo ──────────────────────────────────────────────────────
  final isEnabled = false.obs;
  final template = 'Llegó {monto} por {banco}'.obs;
  final enabledBanks = <String>{}.obs;
  final hasListenerPermission = false.obs;
  final hasBatteryOptimization = false.obs;
  final isSending = false.obs;

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

  // ── Carga inicial ────────────────────────────────────────────────────────

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

  // ── Escuchar eventos del servicio nativo ─────────────────────────────────

  void _listenPayments() {
    _sub = PaymentListenerChannel.paymentStream.listen(
      (event) => _onPaymentDetected(event),
      onError: (e) => debugPrint('[PaymentListener] error: $e'),
    );
  }

  void _onPaymentDetected(Map<Object?, Object?> event) {
    final bank = event['bank']?.toString() ?? '';
    final amount = event['amount']?.toString() ?? '';
    final speechText = event['speech_text']?.toString() ?? '';
    debugPrint('[PaymentListener] Pago detectado: $amount de $bank');
    _sendWebhook(bank: bank, amount: amount, speechText: speechText);
  }

  // ── Webhook al backend ───────────────────────────────────────────────────

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

  // ── Setters ──────────────────────────────────────────────────────────────

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

  // ── Permisos ─────────────────────────────────────────────────────────────

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

  Future<void> testTts() async {
    final text = template.value
        .replaceAll('{monto}', '\$50.000')
        .replaceAll('{banco}', 'Nequi')
        .replaceAll('{banco_nombre}', 'Nequi');
    await PaymentListenerChannel.testTts(text);
  }

  // ── Sincronizar config al servicio nativo ────────────────────────────────

  void _syncNative() {
    PaymentListenerChannel.updateConfig(
      enabled: isEnabled.value,
      enabledBanks: enabledBanks.toList(),
      template: template.value,
    );
  }
}
