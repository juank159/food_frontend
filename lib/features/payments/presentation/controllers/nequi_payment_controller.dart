import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Estados posibles del flujo QR Nequi.
enum NequiPaymentState {
  idle,
  generatingQR,
  qrReady,
  paid,
  expired,
  error,
}

/// Controla el flujo completo de pago QR Nequi:
///   1. Llama al backend para generar el QR.
///   2. Muestra el QR y hace polling cada 3 s.
///   3. Cuando el webhook confirma el pago, el estado cambia a `paid`.
///   4. Si el QR expira, cambia a `expired`.
class NequiPaymentController extends GetxController {
  final Dio _dio;

  NequiPaymentController({required Dio dio}) : _dio = dio;

  // ── Estado reactivo ──────────────────────────────────────────────────────
  final Rx<NequiPaymentState> state = NequiPaymentState.idle.obs;
  final RxString qrPayload = ''.obs;
  final Rx<String?> qrType = Rx<String?>(null); // 'text' | 'base64'
  final RxString transactionId = ''.obs;
  final Rx<DateTime?> expiresAt = Rx<DateTime?>(null);
  final RxString errorMsg = ''.obs;

  /// Segundos restantes hasta expiración (actualizado cada segundo).
  final RxInt secondsLeft = 0.obs;

  Timer? _pollingTimer;
  Timer? _countdownTimer;

  @override
  void onClose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.onClose();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  /// Genera el QR en el backend y arranca el polling + countdown.
  Future<void> generateQR({
    required String orderId,
    required double amount,
  }) async {
    state.value = NequiPaymentState.generatingQR;
    errorMsg.value = '';
    _stopTimers();

    try {
      final res = await _dio.post('/payments/nequi/qr', data: {
        'orderId': orderId,
        'amount': amount,
      });
      final data = ApiResponseUtils.object(res);

      transactionId.value = data['transactionId'] as String;
      qrPayload.value = data['qrPayload'] as String;
      qrType.value = data['qrType'] as String? ?? 'text';

      final expiresRaw = data['expiresAt'];
      expiresAt.value = expiresRaw != null ? DateTime.parse(expiresRaw as String) : null;

      state.value = NequiPaymentState.qrReady;
      _startPolling();
      _startCountdown();
    } on DioException catch (e) {
      errorMsg.value = ApiResponseUtils.errorMessage(e) ?? 'Error generando QR';
      state.value = NequiPaymentState.error;
      AppSnackbar.show('Error Nequi', errorMsg.value);
    }
  }

  /// Cancela el flujo y limpia los timers.
  void cancel() {
    _stopTimers();
    state.value = NequiPaymentState.idle;
    qrPayload.value = '';
    transactionId.value = '';
    expiresAt.value = null;
    secondsLeft.value = 0;
  }

  // ── Internals ────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void _startCountdown() {
    final exp = expiresAt.value;
    if (exp == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = exp.difference(DateTime.now()).inSeconds;
      secondsLeft.value = remaining < 0 ? 0 : remaining;
    });
  }

  void _stopTimers() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _poll() async {
    if (state.value != NequiPaymentState.qrReady) {
      _stopTimers();
      return;
    }
    try {
      final res = await _dio.get('/payments/nequi/status/${transactionId.value}');
      final data = ApiResponseUtils.object(res);
      final status = data['status'] as String? ?? 'pending';

      if (status == 'paid') {
        _stopTimers();
        state.value = NequiPaymentState.paid;
      } else if (status == 'expired' || status == 'cancelled') {
        _stopTimers();
        state.value = NequiPaymentState.expired;
      }
      // 'pending' → seguir esperando
    } on DioException {
      // Silenciar errores de red — el countdown hará expirar si se pierde conexión
    }
  }
}
