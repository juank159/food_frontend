import 'package:dio/dio.dart';
import '../../../../core/utils/api_response_utils.dart';

/// Cobro manual de planes. El negocio SOLICITA un plan y el administrador
/// de la plataforma lo activa cuando recibe el pago (no hay pasarela).
///
/// Endpoints del negocio: `/subscriptions/request-plan`, `/request`,
/// `/request/cancel`. Endpoints de la plataforma: `/platform/*` (el
/// backend verifica que el usuario sea admin de la plataforma).
class PlanBillingApi {
  final Dio dio;

  PlanBillingApi(this.dio);

  /// Mensaje legible de un error de la API (o un fallback).
  static String messageOf(Object e, [String fallback = 'No se pudo completar']) =>
      ApiResponseUtils.errorMessage(e) ?? fallback;

  // ───────────────────────────── Negocio ─────────────────────────────

  Future<Map<String, dynamic>> requestPlan({
    required String planCode,
    required String billingCycle,
    String? notes,
  }) async {
    final r = await dio.post('/subscriptions/request-plan', data: {
      'plan_code': planCode,
      'billing_cycle': billingCycle,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return ApiResponseUtils.object(r);
  }

  /// Solicitud pendiente del negocio, o `null`.
  Future<Map<String, dynamic>?> pendingRequest() async {
    final r = await dio.get('/subscriptions/request');
    final body = ApiResponseUtils.object(r);
    final req = body['request'];
    return req is Map<String, dynamic> ? req : null;
  }

  Future<void> cancelRequest() async {
    await dio.post('/subscriptions/request/cancel');
  }

  // ───────────────────────────── Plataforma ─────────────────────────────

  Future<bool> isPlatformAdmin() async {
    try {
      final r = await dio.get('/platform/me');
      return ApiResponseUtils.object(r)['is_platform_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> requests({String? status}) async {
    final r = await dio.get(
      '/platform/requests',
      queryParameters: {if (status != null) 'status': status},
    );
    return ApiResponseUtils.list(r).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> tenants() async {
    final r = await dio.get('/platform/tenants');
    return ApiResponseUtils.list(r).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> approve(
    String requestId, {
    double? paidAmount,
    String? reference,
  }) async {
    await dio.post('/platform/requests/$requestId/approve', data: {
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (reference != null && reference.trim().isNotEmpty)
        'payment_reference': reference.trim(),
    });
  }

  Future<void> reject(String requestId, {String? reason}) async {
    await dio.post('/platform/requests/$requestId/reject', data: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> activate(
    String tenantId, {
    required String planCode,
    required String billingCycle,
    double? paidAmount,
    String? reference,
  }) async {
    await dio.post('/platform/tenants/$tenantId/activate', data: {
      'plan_code': planCode,
      'billing_cycle': billingCycle,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (reference != null && reference.trim().isNotEmpty)
        'payment_reference': reference.trim(),
    });
  }
}
