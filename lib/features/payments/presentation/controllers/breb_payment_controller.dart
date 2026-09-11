import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Estados posibles del flujo de cobro Bre-B.
enum BrebPaymentState {
  idle,
  creatingCharge,
  waiting,
  paid,
  expired,
  error,
}

/// Una llave Bre-B del negocio, tal cual la devuelve el backend al crear
/// un cobro — el negocio puede tener varias (una por banco) y se le
/// muestran TODAS al cliente para que transfiera a la que tenga a mano.
class BrebLlave {
  final String id;
  final String label;
  final String llave;
  const BrebLlave({required this.id, required this.label, required this.llave});

  factory BrebLlave.fromJson(Map<String, dynamic> json) => BrebLlave(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? 'Llave',
        llave: json['llave'] as String? ?? '',
      );
}

/// Controla el flujo de cobro Bre-B (transferencia directa con llave,
/// conciliada por el backend a partir del correo que reenvía Nequi):
///   1. Llama al backend para crear el cobro (queda "pending").
///   2. Muestra la llave + monto y hace polling cada 3 s (red de seguridad;
///      la confirmación real casi siempre llega antes vía push, ver
///      [markConfirmed]).
///   3. Cuando se concilia el correo, el estado cambia a `paid`.
class BrebPaymentController extends GetxController {
  final Dio _dio;

  BrebPaymentController({required Dio dio}) : _dio = dio;

  /// El diálogo Bre-B no se registra en el árbol de dependencias de GetX
  /// (se instancia directo, igual que `NequiPaymentController`) — este
  /// puntero estático simple es lo único que necesita
  /// `PushNotificationService` para encontrar "el cobro que está esperando
  /// confirmación ahora mismo" y actualizarlo apenas llega el push, sin
  /// esperar el próximo tick del polling. Solo puede haber un cobro Bre-B
  /// abierto a la vez (un cajero cobrando una cuenta por vez).
  static BrebPaymentController? active;

  /// `orderId` del cobro en curso — lo guarda el propio [createCharge] para
  /// que el push handler pueda verificar que el evento es de ESTE cobro.
  String? _activeOrderId;
  String? get activeOrderId => _activeOrderId;

  // ── Estado reactivo ──────────────────────────────────────────────────────
  final Rx<BrebPaymentState> state = BrebPaymentState.idle.obs;
  final RxString chargeId = ''.obs;
  /// Todas las llaves del negocio — se muestran juntas al cliente.
  final RxList<BrebLlave> llaves = <BrebLlave>[].obs;
  final Rx<DateTime?> expiresAt = Rx<DateTime?>(null);
  final RxString payerName = ''.obs;
  final RxString errorMsg = ''.obs;

  /// Segundos restantes hasta expiración (actualizado cada segundo).
  final RxInt secondsLeft = 0.obs;

  Timer? _pollingTimer;
  Timer? _countdownTimer;

  @override
  void onClose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    if (identical(active, this)) active = null;
    super.onClose();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  /// Crea el cobro en el backend y arranca el polling + countdown.
  /// Exactamente uno de [orderId] / [tabSessionId] debe venir — una orden
  /// puntual o el saldo consolidado de una cuenta abierta.
  Future<void> createCharge({
    String? orderId,
    String? tabSessionId,
    required double amount,
  }) async {
    assert(
      (orderId == null) != (tabSessionId == null),
      'createCharge requiere exactamente uno: orderId o tabSessionId',
    );
    state.value = BrebPaymentState.creatingCharge;
    errorMsg.value = '';
    _stopTimers();
    _activeOrderId = orderId ?? tabSessionId;
    active = this;

    try {
      final res = await _dio.post('/payments/breb/charge', data: {
        if (orderId != null) 'orderId': orderId,
        if (tabSessionId != null) 'tabSessionId': tabSessionId,
        'amount': amount,
      });
      final data = ApiResponseUtils.object(res);

      chargeId.value = data['chargeId'] as String;
      final rawLlaves = (data['llaves'] as List?)?.cast<Map<String, dynamic>>();
      if (rawLlaves != null && rawLlaves.isNotEmpty) {
        llaves.value = rawLlaves.map(BrebLlave.fromJson).toList();
      } else {
        // Compat con un backend viejo que todavía solo mande `llave`
        // (string único) — no debería pasar en producción una vez
        // desplegado el backend nuevo, pero evita una pantalla vacía
        // durante un rollout donde ambas versiones convivan un rato.
        final legacy = data['llave'] as String?;
        llaves.value = legacy != null && legacy.isNotEmpty
            ? [BrebLlave(id: 'legacy', label: 'Llave', llave: legacy)]
            : [];
      }

      final expiresRaw = data['expiresAt'];
      expiresAt.value = expiresRaw != null ? DateTime.parse(expiresRaw as String) : null;

      state.value = BrebPaymentState.waiting;
      _startPolling();
      _startCountdown();
    } on DioException catch (e) {
      errorMsg.value = ApiResponseUtils.errorMessage(e) ?? 'Error iniciando el cobro';
      state.value = BrebPaymentState.error;
      AppSnackbar.show('Error Bre-B', errorMsg.value);
    }
  }

  /// Llamado por el push notification handler cuando llega la confirmación
  /// en tiempo real — evita esperar al próximo tick del polling de 3s.
  void markConfirmed({String? payer}) {
    if (state.value != BrebPaymentState.waiting) return;
    _stopTimers();
    if (payer != null && payer.isNotEmpty) payerName.value = payer;
    state.value = BrebPaymentState.paid;
  }

  /// Cancela el flujo y limpia los timers.
  void cancel() {
    final id = chargeId.value;
    _stopTimers();
    if (id.isNotEmpty && state.value == BrebPaymentState.waiting) {
      // Fire-and-forget: si falla, el cobro igual expira solo por TTL.
      () async {
        try {
          await _dio.post('/payments/breb/cancel/$id');
        } catch (_) {}
      }();
    }
    state.value = BrebPaymentState.idle;
    chargeId.value = '';
    llaves.clear();
    expiresAt.value = null;
    secondsLeft.value = 0;
    if (identical(active, this)) active = null;
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
    if (state.value != BrebPaymentState.waiting) {
      _stopTimers();
      return;
    }
    try {
      final res = await _dio.get('/payments/breb/status/${chargeId.value}');
      final data = ApiResponseUtils.object(res);
      final status = data['status'] as String? ?? 'pending';

      if (status == 'matched') {
        _stopTimers();
        payerName.value = data['payerName'] as String? ?? '';
        state.value = BrebPaymentState.paid;
      } else if (status == 'expired' || status == 'cancelled') {
        _stopTimers();
        state.value = BrebPaymentState.expired;
      }
      // 'pending' → seguir esperando
    } on DioException {
      // Silenciar errores de red — el countdown hará expirar si se pierde conexión
    }
  }
}
