// lib/features/payments/data/datasources/payment_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../models/payment_model.dart';

/// Payment Remote Data Source
/// Fuente de datos remota para pagos
abstract class PaymentRemoteDataSource {
  /// Crea un nuevo pago
  Future<PaymentModel> createPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  });

  /// Procesa el pago completo de una orden
  Future<PaymentModel> processOrderPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  });

  /// Procesa pagos divididos
  Future<List<PaymentModel>> processSplitPayment({
    required String orderId,
    required List<Map<String, dynamic>> payments,
  });

  /// Cobra una cuenta abierta entera. El monto se distribuye FIFO entre
  /// los tickets pendientes. Devuelve los payments creados.
  Future<List<PaymentModel>> processTabPayment({
    required String tabSessionId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? tenantPaymentAccountId,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
  });

  /// Reembolsa un pago
  Future<PaymentModel> refundPayment({
    required String paymentId,
    double? refundAmount,
    required String refundReason,
  });

  /// Obtiene todos los pagos con filtros
  Future<Map<String, dynamic>> getPayments({
    String? orderId,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    String? processedBy,
    int? page,
    int? limit,
  });

  /// Obtiene un pago por ID
  Future<PaymentModel> getPaymentById(String id);

  /// Obtiene todos los pagos de una orden
  Future<List<PaymentModel>> getPaymentsByOrder(String orderId);
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final Dio dio;

  PaymentRemoteDataSourceImpl({required this.dio});

  // ─────────────────────────── Helpers ───────────────────────────
  //
  // El backend devuelve respuestas con DOS formatos distintos según el
  // endpoint:
  //
  //   - Endpoints con paginación: `{data: [...], meta: {...}}`
  //   - Endpoints simples (lista entera o detalle): payload raw, sin
  //     envoltura.
  //
  // Antes el código asumía siempre `response.data['data']`, lo que
  // crasheaba con `type 'String' is not a subtype of type 'int' of
  // 'index'` cuando el backend devolvía una lista directa (porque las
  // listas solo aceptan índice `int`, no string). Estos helpers
  // manejan ambos casos.

  /// Extrae un objeto/Map de la respuesta. Si viene envuelto en `{data:
  /// {...}}` desempaqueta; si viene plano, lo devuelve tal cual.
  Map<String, dynamic> _extractObject(Response response) {
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    throw ServerException(
      'Formato de respuesta inesperado (no es Map): ${raw.runtimeType}',
    );
  }

  /// Extrae una `List<dynamic>` de la respuesta, soportando los tres
  /// formatos: `[...]` directo, `{data: [...]}` y `{data: {data: [...]}}`
  /// (paginación anidada).
  List<dynamic> _extractList(Response response) {
    final raw = response.data;
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is List) return inner;
      if (inner is Map<String, dynamic>) {
        final nested = inner['data'];
        if (nested is List) return nested;
      }
    }
    throw ServerException(
      'Formato de respuesta inesperado (no es List): ${raw.runtimeType}',
    );
  }

  // ─────────────────────── Implementation ───────────────────────

  @override
  Future<PaymentModel> createPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.payments,
        data: {
          'order_id': orderId,
          'payment_method': paymentMethod.value,
          'amount': amount,
          if (receivedAmount != null) 'received_amount': receivedAmount,
          if (transactionReference != null)
            'transaction_reference': transactionReference,
          if (notes != null) 'notes': notes,
          if (tenantPaymentAccountId != null)
            'tenant_payment_account_id': tenantPaymentAccountId,
        },
      );

      return PaymentModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<PaymentModel> processOrderPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) async {
    try {
      final response = await dio.post(
        '${ApiConstants.payments}/order/$orderId/pay',
        data: {
          'payment_method': paymentMethod.value,
          if (receivedAmount != null) 'received_amount': receivedAmount,
          if (transactionReference != null)
            'transaction_reference': transactionReference,
          if (notes != null) 'notes': notes,
          if (tenantPaymentAccountId != null)
            'tenant_payment_account_id': tenantPaymentAccountId,
        },
      );

      return PaymentModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<PaymentModel>> processSplitPayment({
    required String orderId,
    required List<Map<String, dynamic>> payments,
  }) async {
    try {
      final response = await dio.post(
        '${ApiConstants.payments}/order/$orderId/split',
        data: {'payments': payments},
      );

      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<PaymentModel>> processTabPayment({
    required String tabSessionId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? tenantPaymentAccountId,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.processTabPayment(tabSessionId),
        data: {
          'amount': amount,
          'payment_method': paymentMethod.value,
          if (tenantPaymentAccountId != null)
            'tenant_payment_account_id': tenantPaymentAccountId,
          if (receivedAmount != null) 'received_amount': receivedAmount,
          if (transactionReference != null)
            'transaction_reference': transactionReference,
          if (notes != null) 'notes': notes,
        },
      );
      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<PaymentModel> refundPayment({
    required String paymentId,
    double? refundAmount,
    required String refundReason,
  }) async {
    try {
      final response = await dio.post(
        '${ApiConstants.payments}/$paymentId/refund',
        data: {
          if (refundAmount != null) 'refund_amount': refundAmount,
          'refund_reason': refundReason,
        },
      );

      return PaymentModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getPayments({
    String? orderId,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    String? processedBy,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        if (orderId != null) 'order_id': orderId,
        if (paymentMethod != null) 'payment_method': paymentMethod.value,
        if (status != null) 'status': status.value,
        if (processedBy != null) 'processed_by': processedBy,
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      };

      final response = await dio.get(
        ApiConstants.payments,
        queryParameters: queryParameters,
      );

      final payments = _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();

      // Meta para paginación — buscamos `meta` (formato nuevo) o los
      // campos sueltos `total/page/limit` (formato viejo).
      final raw = response.data;
      Map<String, dynamic>? meta;
      if (raw is Map<String, dynamic>) {
        if (raw['meta'] is Map<String, dynamic>) {
          meta = raw['meta'] as Map<String, dynamic>;
        } else if (raw['data'] is Map<String, dynamic>) {
          meta = raw['data'] as Map<String, dynamic>;
        }
      }

      return {
        'data': payments,
        'total': meta?['total'] ?? meta?['totalItems'] ?? payments.length,
        'page': meta?['page'] ?? 1,
        'limit': meta?['limit'] ?? payments.length,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<PaymentModel> getPaymentById(String id) async {
    try {
      final response = await dio.get('${ApiConstants.payments}/$id');

      return PaymentModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<PaymentModel>> getPaymentsByOrder(String orderId) async {
    try {
      final response =
          await dio.get('${ApiConstants.payments}/order/$orderId');

      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Maneja errores de Dio y los convierte a excepciones personalizadas.
  ///
  /// El backend puede devolver un body con un `code` semántico además
  /// del `message`. Para errores que la UI necesita distinguir (ej:
  /// `CASH_SESSION_REQUIRED` → mostrar dialog con botón "Abrir caja")
  /// prefijamos el mensaje con `{code}:` para que el controller lo
  /// detecte sin tener que introducir tipos nuevos de excepción.
  Exception _handleError(DioException error) {
    final data = error.response?.data;
    String? msgFromBody;
    String? codeFromBody;
    if (data is Map<String, dynamic>) {
      msgFromBody = data['message']?.toString();
      codeFromBody = data['code']?.toString();
    }

    final prefixedMsg = (codeFromBody != null && msgFromBody != null)
        ? '$codeFromBody:$msgFromBody'
        : msgFromBody;

    switch (error.response?.statusCode) {
      case 400:
        return ValidationException(prefixedMsg ?? 'Datos inválidos');
      case 401:
        return UnauthorizedException();
      case 404:
        return NotFoundException(msgFromBody ?? 'Pago no encontrado');
      case 500:
        return ServerException(msgFromBody ?? 'Error del servidor');
      default:
        return NetworkException(error.message ?? 'Error de red');
    }
  }
}
