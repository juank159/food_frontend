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
  /// QR ya armado con el monto de ESTE cobro — `null` si la llave no
  /// tiene una plantilla de QR configurada (Ajustes → Bre-B) o si la
  /// plantilla está rota (el backend igual muestra la llave en texto
  /// como respaldo, ver `BrebService._safeBuildQr`).
  final String? qrPayload;

  const BrebLlave({
    required this.id,
    required this.label,
    required this.llave,
    this.qrPayload,
  });

  factory BrebLlave.fromJson(Map<String, dynamic> json) => BrebLlave(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? 'Llave',
        llave: json['llave'] as String? ?? '',
        qrPayload: json['qrPayload'] as String?,
      );
}

/// Un pago Bre-B que SÍ llegó al banco pero el backend no pudo asignar
/// solo a un cobro (el cliente transfirió otro valor, llegó tarde, dos
/// transferencias iguales al mismo tiempo…). El cajero lo asigna a mano.
class BrebReceivedPayment {
  final String id;
  final double amount;
  final String? payerName;
  final String? bankLabel;
  final DateTime? receivedAt;

  const BrebReceivedPayment({
    required this.id,
    required this.amount,
    this.payerName,
    this.bankLabel,
    this.receivedAt,
  });

  factory BrebReceivedPayment.fromJson(Map<String, dynamic> json) =>
      BrebReceivedPayment(
        id: json['id'] as String? ?? '',
        amount: _toDouble(json['amount']),
        payerName: json['payerName'] as String?,
        bankLabel: json['bankLabel'] as String?,
        receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? ''),
      );
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
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
  /// Monto EXACTO que debe transferir el cliente. Puede ser hasta $9 menor
  /// que lo pedido: el backend lo ajusta hacia abajo para que no haya dos
  /// cobros pendientes del mismo valor y así cada correo del banco se
  /// asigne sin confusión a su venta (el negocio absorbe la diferencia).
  final RxDouble chargeAmount = 0.0.obs;
  /// Lo que se pidió cobrar (precio de la venta).
  final RxDouble requestedAmount = 0.0.obs;

  /// Diferencia absorbida por el negocio (0 si no hubo ajuste).
  double get adjustment {
    final d = requestedAmount.value - chargeAmount.value;
    return d > 0.009 ? d : 0;
  }
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
    requestedAmount.value = amount;
    chargeAmount.value = amount;
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
      // Un backend viejo no manda `amount` → se cobra lo pedido.
      if (data['amount'] != null) chargeAmount.value = _toDouble(data['amount']);
      if (data['requestedAmount'] != null) {
        requestedAmount.value = _toDouble(data['requestedAmount']);
      }
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
      // Bre-B no se puede cobrar offline: el pago solo existe cuando el
      // backend concilia el correo del banco. Mensaje claro en vez del
      // error técnico de conexión.
      final noInternet = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown;
      errorMsg.value = noInternet
          ? 'Bre-B necesita internet para confirmar el pago con el banco. '
              'Cobrá con otro método (efectivo, tarjeta, transferencia) y se sincroniza solo.'
          : ApiResponseUtils.errorMessage(e) ?? 'Error iniciando el cobro';
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

  /// Pagos recibidos (últimas 24 h) que el backend no pudo asignar solos.
  Future<List<BrebReceivedPayment>> loadUnassigned() async {
    final res = await _dio.get('/payments/breb/unassigned');
    final raw = ApiResponseUtils.list(res);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BrebReceivedPayment.fromJson)
        .toList();
  }

  /// Asigna a mano [payment] a ESTE cobro. El backend lo hace atómico: si
  /// otro cajero ya lo asignó, falla con un mensaje claro. Devuelve `null`
  /// si salió bien o el mensaje de error.
  Future<String?> assignReceived(BrebReceivedPayment payment) async {
    final id = chargeId.value;
    if (id.isEmpty) return 'No hay un cobro activo';
    try {
      await _dio.post('/payments/breb/assign', data: {
        'chargeId': id,
        'emailId': payment.id,
      });
      _stopTimers();
      if (payment.payerName != null && payment.payerName!.isNotEmpty) {
        payerName.value = payment.payerName!;
      }
      chargeAmount.value = payment.amount < requestedAmount.value
          ? payment.amount
          : requestedAmount.value;
      state.value = BrebPaymentState.paid;
      return null;
    } on DioException catch (e) {
      return ApiResponseUtils.errorMessage(e) ?? 'No se pudo asignar el pago';
    }
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
    chargeAmount.value = 0;
    requestedAmount.value = 0;
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
