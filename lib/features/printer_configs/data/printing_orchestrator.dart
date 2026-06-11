import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/theme/app_colors.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/utils/api_response_utils.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/safe_get.dart';
import '../../orders/data/models/order_item_model.dart';
import '../../orders/data/models/order_model.dart';
import '../../thermal_print/data/thermal_print_service.dart';
import '../presentation/controllers/printer_configs_controller.dart';
import 'esc_pos_generator.dart';
import 'models/printer_config_model.dart';
import 'printer_configs_remote_datasource.dart';
import 'printer_dispatcher.dart';

/// Tipo de documento a imprimir.
enum PrintJobKind { kitchen, receipt, qrTicket }

/// Resultado de un job de impresión.
enum PrintResult {
  /// Impreso OK (sin diálogo si era red, o usuario confirmó si era sistema).
  success,

  /// No hay impresora default configurada para ese propósito.
  noPrinterConfigured,

  /// La impresora respondió pero el envío falló (red caída, etc.).
  printerError,

  /// El usuario canceló el diálogo del SO.
  cancelled,
}

/// Orquestador profesional de impresión.
///
/// **Responsabilidades:**
///
/// 1. Encontrar la `PrinterConfig` adecuada según el propósito.
/// 2. Decidir si auto-imprimir o requerir click manual.
/// 3. Generar el contenido correcto según el tipo de impresora:
///    - **`system`** (CUPS / Windows / AirPrint) → PDF del backend.
///    - **`network`** (TCP raw 9100) → ESC/POS local generado del JSON.
/// 4. Despachar vía `PrinterDispatcher`.
/// 5. Feedback claro y discreto al usuario.
///
/// **Por qué dos formatos:**
/// Las térmicas POS en red **no entienden PDF** en el puerto 9100 — son
/// drivers en chip que solo hablan ESC/POS. Mandar PDF resulta en
/// caracteres random impresos y metros de papel desperdiciados.
/// Para impresoras del SO, en cambio, el driver del SO se encarga de
/// rasterizar el PDF y enviarlo en el formato que la impresora entienda.
///
/// **Stateless:** todas las llamadas pueden ser fire-and-forget.
class PrintingOrchestrator {
  PrintingOrchestrator._();

  // ── Cache liviano de info del tenant (para el recibo) ─────────────
  // El negocio cambia raramente; cacheamos por 10 min para evitar pedir
  // /tenants/me en cada impresión. El recibo solo se imprime ~1 vez por
  // mesa cobrada, pero el costo de fetch nulo importa cuando hay
  // turnos pico.
  static _TenantInfo? _tenantCache;
  static DateTime? _tenantCachedAt;

  static Future<_TenantInfo> _getTenantInfo() async {
    final now = DateTime.now();
    if (_tenantCache != null &&
        _tenantCachedAt != null &&
        now.difference(_tenantCachedAt!) < const Duration(minutes: 10)) {
      return _tenantCache!;
    }
    try {
      final dio = sl<Dio>();
      final response = await dio.get('/tenants/me');
      final tenant = ApiResponseUtils.object(response);
      final settings =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      final contact =
          (settings['contact'] as Map?)?.cast<String, dynamic>() ?? {};
      final info = _TenantInfo(
        businessName:
            (tenant['business_name'] as String?)?.trim().isNotEmpty == true
                ? tenant['business_name'] as String
                : 'Mi Restaurante',
        address: (contact['address'] as String?)?.trim(),
        phone: (contact['phone'] as String?)?.trim(),
        taxId: (contact['tax_id'] as String?)?.trim(),
      );
      _tenantCache = info;
      _tenantCachedAt = now;
      return info;
    } catch (_) {
      // Si falla, devolvemos defaults razonables para no abortar la
      // impresión completa.
      return const _TenantInfo(
        businessName: 'Mi Restaurante',
        address: null,
        phone: null,
        taxId: null,
      );
    }
  }

  /// Si el usuario actualiza la info del negocio, llamar a esto para
  /// que el próximo recibo refleje los cambios sin esperar el TTL.
  static void invalidateTenantCache() {
    _tenantCache = null;
    _tenantCachedAt = null;
  }

  // ── Resolución de impresora ───────────────────────────────────────

  static Future<List<PrinterConfigModel>> _getConfigs() async {
    final ctrl = SafeGet.find<PrinterConfigsController>();
    if (ctrl != null && ctrl.printers.isNotEmpty) {
      return ctrl.printers;
    }
    try {
      return await sl<PrinterConfigsRemoteDataSource>().list();
    } catch (_) {
      return [];
    }
  }

  static Future<PrinterConfigModel?> _resolveDefault(
    PrinterPurpose target,
  ) async {
    final configs = await _getConfigs();
    if (configs.isEmpty) return null;

    final exact = configs.where(
      (p) => p.isActive && p.isDefault && p.purpose == target,
    );
    if (exact.isNotEmpty) return exact.first;

    final both = configs.where(
      (p) =>
          p.isActive && p.isDefault && p.purpose == PrinterPurpose.both,
    );
    if (both.isNotEmpty) return both.first;

    final anyActive = configs.where(
      (p) =>
          p.isActive &&
          (p.purpose == target || p.purpose == PrinterPurpose.both),
    );
    return anyActive.isNotEmpty ? anyActive.first : null;
  }

  // ── KITCHEN ───────────────────────────────────────────────────────

  static Future<PrintResult> autoPrintKitchen({
    required String orderId,
    String? subtitle,
  }) async {
    final printer = await _resolveDefault(PrinterPurpose.kitchen);
    if (printer == null || !printer.autoPrint) {
      return PrintResult.noPrinterConfigured;
    }
    return _runPrintJob(
      kind: PrintJobKind.kitchen,
      orderId: orderId,
      printer: printer,
      silent: true,
      subtitle: subtitle,
    );
  }

  static Future<PrintResult> printKitchenManual({
    required String orderId,
    String? subtitle,
  }) async {
    final printer = await _resolveDefault(PrinterPurpose.kitchen);
    if (printer == null) {
      _snackNoDefault('comanda', PrinterPurpose.kitchen);
      return PrintResult.noPrinterConfigured;
    }
    return _runPrintJob(
      kind: PrintJobKind.kitchen,
      orderId: orderId,
      printer: printer,
      silent: false,
      subtitle: subtitle,
    );
  }

  // ── RECEIPT ───────────────────────────────────────────────────────

  static Future<PrintResult> autoPrintReceipt({
    required String orderId,
    String? subtitle,
  }) async {
    final printer = await _resolveDefault(PrinterPurpose.receipt);
    if (printer == null || !printer.autoPrint) {
      return PrintResult.noPrinterConfigured;
    }
    return _runPrintJob(
      kind: PrintJobKind.receipt,
      orderId: orderId,
      printer: printer,
      silent: true,
      subtitle: subtitle,
    );
  }

  static Future<PrintResult> printReceiptManual({
    required String orderId,
    String? subtitle,
  }) async {
    final printer = await _resolveDefault(PrinterPurpose.receipt);
    if (printer == null) {
      _snackNoDefault('recibo', PrinterPurpose.receipt);
      return PrintResult.noPrinterConfigured;
    }
    return _runPrintJob(
      kind: PrintJobKind.receipt,
      orderId: orderId,
      printer: printer,
      silent: false,
      subtitle: subtitle,
    );
  }

  // ── Implementación ────────────────────────────────────────────────

  static Future<PrintResult> _runPrintJob({
    required PrintJobKind kind,
    required String orderId,
    required PrinterConfigModel printer,
    required bool silent,
    String? subtitle,
  }) async {
    final docLabel =
        kind == PrintJobKind.receipt ? 'Recibo' : 'Comanda';
    try {
      final bool ok;
      switch (printer.connectionType) {
        case PrinterConnectionType.network:
          ok = await _printNetworkEscPos(
            kind: kind,
            orderId: orderId,
            printer: printer,
          );
          break;
        case PrinterConnectionType.system:
          ok = await _printSystemPdf(
            kind: kind,
            orderId: orderId,
            printer: printer,
            subtitle: subtitle,
          );
          break;
      }

      if (ok) {
        if (!silent) {
          _snackOk(docLabel, printer);
        } else {
          _snackOkSilent(docLabel, printer);
        }
        return PrintResult.success;
      } else {
        return PrintResult.cancelled;
      }
    } catch (e) {
      _snackError(docLabel, printer, e);
      return PrintResult.printerError;
    }
  }

  /// Para impresoras de red: pedimos JSON de la orden, generamos
  /// ESC/POS local y mandamos bytes al socket.
  static Future<bool> _printNetworkEscPos({
    required PrintJobKind kind,
    required String orderId,
    required PrinterConfigModel printer,
  }) async {
    final order = await _fetchOrder(orderId);
    final ticket = await _buildTicketData(order, kind);
    final Uint8List bytes;
    switch (kind) {
      case PrintJobKind.kitchen:
        bytes = await EscPosGenerator.buildKitchen(
          data: ticket,
          paperWidthMm: printer.paperWidth,
        );
        break;
      case PrintJobKind.receipt:
        bytes = await EscPosGenerator.buildReceipt(
          data: ticket,
          paperWidthMm: printer.paperWidth,
        );
        break;
      case PrintJobKind.qrTicket:
        // En el path de network no soportamos QR todavía — usamos PDF.
        // Caemos al sistema PDF como fallback aunque la impresora sea red
        // (mejor un dialog que un ticket roto).
        final tps = sl<ThermalPrintService>();
        final pdf = await tps.getQrPdfBytes(
          code: orderId,
          width: printer.paperWidth == 58
              ? ThermalPaperWidth.mm58
              : ThermalPaperWidth.mm80,
        );
        return PrinterDispatcher.printPdf(
          pdfBytes: pdf,
          jobName: 'QR ticket',
        );
    }
    return PrinterDispatcher.printRawBytes(
      bytes: bytes,
      printer: printer,
    );
  }

  /// Para impresoras del SO: pedimos el PDF al backend y dejamos que
  /// el driver del SO lo maneje.
  static Future<bool> _printSystemPdf({
    required PrintJobKind kind,
    required String orderId,
    required PrinterConfigModel printer,
    String? subtitle,
  }) async {
    final width = printer.paperWidth == 58
        ? ThermalPaperWidth.mm58
        : ThermalPaperWidth.mm80;
    final tps = sl<ThermalPrintService>();
    final Uint8List pdf;
    final String jobName;
    switch (kind) {
      case PrintJobKind.kitchen:
        pdf = await tps.getKitchenPdfBytes(orderId: orderId, width: width);
        jobName = 'Comanda${subtitle != null ? " · $subtitle" : ""}';
        break;
      case PrintJobKind.receipt:
        pdf = await tps.getReceiptPdfBytes(orderId: orderId, width: width);
        jobName = 'Recibo${subtitle != null ? " · $subtitle" : ""}';
        break;
      case PrintJobKind.qrTicket:
        pdf = await tps.getQrPdfBytes(code: orderId, width: width);
        jobName = 'QR ticket';
        break;
    }
    return PrinterDispatcher.printPdf(pdfBytes: pdf, jobName: jobName);
  }

  static Future<OrderModel> _fetchOrder(String orderId) async {
    final dio = sl<Dio>();
    final response = await dio.get('/orders/$orderId');
    final json = ApiResponseUtils.object(response);
    return OrderModel.fromJson(json);
  }

  static Future<TicketData> _buildTicketData(
    OrderModel order,
    PrintJobKind kind,
  ) async {
    final tenant = await _getTenantInfo();
    return TicketData(
      businessName: tenant.businessName,
      address: tenant.address,
      phone: tenant.phone,
      taxId: tenant.taxId,
      orderNumber: order.orderNumber,
      createdAt: DateTime.tryParse(order.createdAt) ?? DateTime.now(),
      tableLabel: order.tableLabel ?? order.tableName,
      orderType: order.orderType,
      orderSource: order.orderSource,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: order.items.map(_toTicketItem).toList(),
      subtotal: order.subtotal,
      taxAmount: order.taxAmount,
      discountAmount: order.discountAmount,
      tipAmount: order.tipAmount,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod,
      notes: order.specialInstructions,
    );
  }

  static TicketItem _toTicketItem(OrderItemModel item) {
    // Concatenamos los modifiers en `variantName` para que aparezcan
    // visibles aunque el item no tenga una variant explícita.
    final modifiersText = item.modifiers
        ?.map((m) => m.modifierName ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
    return TicketItem(
      quantity: item.quantity,
      name: item.productName,
      variantName: (modifiersText != null && modifiersText.isNotEmpty)
          ? modifiersText
          : null,
      unitPrice: item.unitPrice,
      subtotal: item.subtotal,
      specialInstructions: item.specialInstructions,
    );
  }

  // ── Snackbars (siempre via AppSnackbar) ───────────────────────────

  static void _snackOk(String document, PrinterConfigModel p) {
    AppSnackbar.show(
      '$document impreso',
      'Enviado a ${p.name}',
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle),
      duration: const Duration(seconds: 2),
    );
  }

  static void _snackOkSilent(String document, PrinterConfigModel p) {
    AppSnackbar.show(
      '$document → ${p.name}',
      '',
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      icon: const Icon(Icons.print),
      duration: const Duration(milliseconds: 1800),
    );
  }

  static void _snackError(
    String document,
    PrinterConfigModel p,
    Object err,
  ) {
    final isNetwork = p.connectionType == PrinterConnectionType.network;
    final reason = isNetwork
        ? 'Sin conexión con ${p.host}:${p.port}. Revisá la impresora.'
        : 'No se pudo enviar al SO.';
    AppSnackbar.show(
      'No se imprimió $document',
      reason,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline),
      duration: const Duration(seconds: 5),
    );
  }

  static void _snackNoDefault(String document, PrinterPurpose purpose) {
    final purposeLabel =
        purpose == PrinterPurpose.kitchen ? 'Cocina' : 'Caja';
    AppSnackbar.show(
      'Sin impresora para $document',
      'Configurá una en Settings → Impresoras → $purposeLabel.',
      backgroundColor: Colors.amber.shade800,
      colorText: Colors.white,
      icon: const Icon(Icons.warning_amber),
      duration: const Duration(seconds: 5),
    );
  }
}

class _TenantInfo {
  final String businessName;
  final String? address;
  final String? phone;
  final String? taxId;

  const _TenantInfo({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.taxId,
  });
}
