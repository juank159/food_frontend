import 'dart:async';
import '../../../core/services/branch/branch_service.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/theme/app_colors.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/utils/api_response_utils.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/safe_get.dart';
import '../../../core/services/local_cache_service.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../cash_sessions/data/models/cash_session_model.dart';
import '../../orders/data/datasources/order_local_datasource.dart';
import '../../orders/data/models/order_item_model.dart';
import '../../orders/data/models/order_model.dart';
import '../../tab_sessions/data/models/tab_session_model.dart';
import '../../tab_sessions/domain/entities/tab_session.dart';
import '../../thermal_print/data/thermal_print_service.dart';
import '../presentation/controllers/printer_configs_controller.dart';
import 'esc_pos_generator.dart';
import 'models/printer_config_model.dart';
import 'printer_configs_remote_datasource.dart';
import 'printer_dispatcher.dart';
import 'windows_raw_printer.dart';

/// Tipo de documento a imprimir.
enum PrintJobKind { kitchen, receipt, qrTicket }

/// Resultado de un job de impresión.
enum PrintResult {
  /// Impreso OK (sin diálogo si era red, o usuario confirmó si era sistema).
  success,

  /// No hay impresora default configurada para ese propósito.
  noPrinterConfigured,

  /// La impresora está configurada pero el rol del usuario no tiene permiso.
  roleNotAllowed,

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

  /// Datos del encabezado del ticket. Con varias sedes, dirección y
  /// teléfono son los de la sede del dispositivo (si los tiene cargados)
  /// y el nombre lleva la sede: el cliente ve DÓNDE compró.
  static Future<_TenantInfo> _getTenantInfo() async {
    final info = await _getTenantInfoRaw();
    final branches = BranchService.maybe;
    final branch = branches?.current.value;
    if (branches == null || branch == null || !branches.isMulti) return info;
    String? pick(String? own, String? fallback) =>
        own != null && own.trim().isNotEmpty ? own.trim() : fallback;
    return _TenantInfo(
      businessName: '${info.businessName} - ${branch.name}',
      address: pick(branch.address, info.address),
      phone: pick(branch.phone, info.phone),
      taxId: info.taxId,
      logoUrl: info.logoUrl,
      kitchenTicketGroups: info.kitchenTicketGroups,
    );
  }

  static Future<_TenantInfo> _getTenantInfoRaw() async {
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
      final receipt =
          (settings['receipt'] as Map?)?.cast<String, dynamic>() ?? {};
      final printing =
          (settings['printing'] as Map?)?.cast<String, dynamic>() ?? {};
      final logoUrl = (receipt['logo_url'] as String?)?.trim();
      final info = _TenantInfo(
        businessName:
            (tenant['business_name'] as String?)?.trim().isNotEmpty == true
            ? tenant['business_name'] as String
            : 'Mi Restaurante',
        address: (contact['address'] as String?)?.trim(),
        phone: (contact['phone'] as String?)?.trim(),
        taxId: (contact['tax_id'] as String?)?.trim(),
        logoUrl: (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null,
        kitchenTicketGroups:
            _parseKitchenTicketGroups(printing['kitchen_ticket_groups']),
      );
      _tenantCache = info;
      _tenantCachedAt = now;
      try {
        await sl<LocalCacheService>().saveObject(_tenantCacheKey, {
          'business_name': info.businessName,
          'address': info.address,
          'phone': info.phone,
          'tax_id': info.taxId,
          'logo_url': info.logoUrl,
          'kitchen_ticket_groups': info.kitchenTicketGroups,
        });
      } catch (_) {}
      return info;
    } catch (_) {
      // Sin red Y sin caché en memoria (ej. recién arrancó la app sin
      // internet) — última chance antes de caer al default genérico:
      // la última versión persistida (`LocalCacheService`, sobrevive
      // un restart). Bug real reportado: antes esto iba directo a
      // "Mi Restaurante" apenas fallaba la red, aunque la app ya
      // conociera el nombre real del negocio de una sesión anterior.
      try {
        final cached = sl<LocalCacheService>().getObject(_tenantCacheKey);
        if (cached != null) {
          return _TenantInfo(
            businessName:
                (cached['business_name'] as String?)?.trim().isNotEmpty == true
                ? cached['business_name'] as String
                : 'Mi Restaurante',
            address: cached['address'] as String?,
            phone: cached['phone'] as String?,
            taxId: cached['tax_id'] as String?,
            logoUrl: cached['logo_url'] as String?,
            kitchenTicketGroups:
                _parseKitchenTicketGroups(cached['kitchen_ticket_groups']),
          );
        }
      } catch (_) {}
      return const _TenantInfo(
        businessName: 'Mi Restaurante',
        address: null,
        phone: null,
        taxId: null,
      );
    }
  }

  /// Parsea `settings.printing.kitchen_ticket_groups` (o la copia
  /// cacheada) tolerando cualquier forma rara del JSON — nunca lanza,
  /// peor caso devuelve `[]` (= sin agrupar, comportamiento de siempre).
  static List<List<String>> _parseKitchenTicketGroups(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .map((g) => g.whereType<String>().toList())
        .where((g) => g.isNotEmpty)
        .toList();
  }

  static const _tenantCacheKey = 'printing_tenant_info';

  /// Si el usuario actualiza la info del negocio, llamar a esto para
  /// que el próximo recibo refleje los cambios sin esperar el TTL.
  static void invalidateTenantCache() {
    _tenantCache = null;
    _tenantCachedAt = null;
    _logoBytesCache = null;
    _logoUrlCache = null;
  }

  // ── Cache del logo (bytes descargados) ────────────────────────────
  static Uint8List? _logoBytesCache;
  static String? _logoUrlCache;

  /// Descarga (una sola vez por URL) los bytes del logo del negocio y
  /// los cachea, para no re-descargar en cada recibo. Usa un Dio LIMPIO
  /// (sin baseUrl ni interceptors de la API) porque el logo vive en un
  /// host externo — así no le filtramos el token ni el x-tenant-id.
  /// Devuelve null si no hay URL o si la descarga falla: el recibo
  /// simplemente sale sin logo, nunca se rompe.
  static Future<Uint8List?> _getLogoBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (_logoUrlCache == url && _logoBytesCache != null) {
      return _logoBytesCache;
    }
    try {
      final res = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final data = res.data;
      if (data == null || data.isEmpty) return null;
      _logoBytesCache = Uint8List.fromList(data);
      _logoUrlCache = url;
      return _logoBytesCache;
    } catch (_) {
      return null;
    }
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
      (p) => p.isActive && p.isDefault && p.purpose == PrinterPurpose.both,
    );
    if (both.isNotEmpty) return both.first;

    final anyActive = configs.where(
      (p) =>
          p.isActive &&
          (p.purpose == target || p.purpose == PrinterPurpose.both),
    );
    return anyActive.isNotEmpty ? anyActive.first : null;
  }

  // ── Rol check ─────────────────────────────────────────────────────

  /// True si el usuario logueado puede usar esta impresora.
  /// Lista vacía = todos los roles están permitidos.
  static bool _userCanPrint(PrinterConfigModel printer) {
    if (printer.allowedRoles.isEmpty) return true;
    final auth = SafeGet.find<AuthController>();
    final roleCode = auth?.currentUser?.roleCode;
    if (roleCode == null) return true;
    return printer.allowedRoles.contains(roleCode);
  }

  // ── Dialog de confirmación ─────────────────────────────────────────

  /// Muestra un dialog compacto "¿Imprimir [label]?" y devuelve
  /// true si el usuario confirmó. Usa el contexto activo de GetX.
  static Future<bool> _askUser(String label) async {
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return false;
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.print_outlined, size: 32),
        title: Text('¿Imprimir $label?'),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Omitir'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Imprimir'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── KITCHEN ───────────────────────────────────────────────────────

  static Future<PrintResult> autoPrintKitchen({
    required String orderId,
    String? subtitle,
  }) async {
    final printer = await _resolveDefault(PrinterPurpose.kitchen);
    if (printer == null) return PrintResult.noPrinterConfigured;
    if (!_userCanPrint(printer)) return PrintResult.roleNotAllowed;

    if (!printer.autoPrint) {
      // Preguntar antes de imprimir
      final should = await _askUser('comanda de cocina');
      if (!should) return PrintResult.cancelled;
    }

    return _runPrintJob(
      kind: PrintJobKind.kitchen,
      orderId: orderId,
      printer: printer,
      silent: printer.autoPrint,
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
    if (!_userCanPrint(printer)) {
      AppSnackbar.show('Sin permiso', 'Tu rol no tiene permiso para imprimir.');
      return PrintResult.roleNotAllowed;
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
    if (printer == null) return PrintResult.noPrinterConfigured;
    if (!_userCanPrint(printer)) return PrintResult.roleNotAllowed;

    if (!printer.autoPrint) {
      // Preguntar antes de imprimir la factura
      final should = await _askUser('factura / recibo');
      if (!should) return PrintResult.cancelled;
    }

    return _runPrintJob(
      kind: PrintJobKind.receipt,
      orderId: orderId,
      printer: printer,
      silent: printer.autoPrint,
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
    if (!_userCanPrint(printer)) {
      AppSnackbar.show('Sin permiso', 'Tu rol no tiene permiso para imprimir.');
      return PrintResult.roleNotAllowed;
    }
    return _runPrintJob(
      kind: PrintJobKind.receipt,
      orderId: orderId,
      printer: printer,
      silent: false,
      subtitle: subtitle,
    );
  }

  // ── CIERRE DE CAJA ───────────────────────────────────────────────
  //
  // No encaja en `_runPrintJob` (pensado para `OrderModel`) porque el
  // ticket de cierre de caja no es una orden — sale de
  // `CashSessionsService.getReport()`. Implementación propia, mismo
  // patrón de resolución de impresora / permisos / feedback.

  /// Reusa el propósito `receipt` (misma impresora de caja) — no hay
  /// un `PrinterPurpose` dedicado y no hace falta uno: el cierre de
  /// caja se imprime desde el mismo punto físico que los recibos.
  static Future<PrintResult> printCashSessionReport({
    required String sessionId,
  }) async {
    final printer = await _resolveDefault(PrinterPurpose.receipt);
    if (printer == null) {
      _snackNoDefault('cierre de caja', PrinterPurpose.receipt);
      return PrintResult.noPrinterConfigured;
    }
    if (!_userCanPrint(printer)) {
      AppSnackbar.show('Sin permiso', 'Tu rol no tiene permiso para imprimir.');
      return PrintResult.roleNotAllowed;
    }
    const docLabel = 'Cierre de caja';
    try {
      final bool ok;
      switch (printer.connectionType) {
        case PrinterConnectionType.network:
          ok = await _printCashSessionReportNetwork(
            sessionId: sessionId,
            printer: printer,
          );
          break;
        case PrinterConnectionType.system:
          ok = await _printCashSessionReportSystem(
            sessionId: sessionId,
            printer: printer,
          );
          break;
      }
      if (ok) {
        _snackOk(docLabel, printer);
        return PrintResult.success;
      }
      return PrintResult.cancelled;
    } catch (e) {
      _snackError(docLabel, printer, e);
      return PrintResult.printerError;
    }
  }

  static Future<bool> _printCashSessionReportSystem({
    required String sessionId,
    required PrinterConfigModel printer,
  }) async {
    // Mismo criterio que `_runPrintJob`: con una impresora Windows
    // elegida, ESC/POS local + RAW directo al hardware — nada de PDF
    // ni backend de por medio más que el JSON que ya hacía falta.
    final printerName = printer.host;
    if (printerName != null &&
        printerName.isNotEmpty &&
        WindowsRawPrinter.isSupported) {
      final data = await _buildCashSessionReportData(sessionId);
      final bytes = await EscPosGenerator.buildCashSessionReport(
        data: data,
        paperWidthMm: printer.paperWidth,
      );
      final okRaw = PrinterDispatcher.printRawBytesToWindowsPrinter(
        bytes: bytes,
        printerName: printerName,
      );
      if (okRaw) return true;
    }

    final width = printer.paperWidth == 58
        ? ThermalPaperWidth.mm58
        : ThermalPaperWidth.mm80;
    final tps = sl<ThermalPrintService>();
    final pdf = await tps.getCashSessionReportPdfBytes(
      sessionId: sessionId,
      width: width,
    );
    if (pdf.isEmpty) return true;
    return PrinterDispatcher.printPdf(
      pdfBytes: pdf,
      jobName: 'Cierre de caja',
      printerUrl: printer.host,
    );
  }

  static Future<bool> _printCashSessionReportNetwork({
    required String sessionId,
    required PrinterConfigModel printer,
  }) async {
    final data = await _buildCashSessionReportData(sessionId);
    final bytes = await EscPosGenerator.buildCashSessionReport(
      data: data,
      paperWidthMm: printer.paperWidth,
    );
    return PrinterDispatcher.printRawBytes(bytes: bytes, printer: printer);
  }

  /// Bug real reportado (mismo pedido: imprimir debe andar con o sin
  /// internet): este reporte lo calcula el backend (agrupado por
  /// método de pago + llave Bre-B) — no es un dato simple que viva en
  /// la caché de alguna otra pantalla, así que acá SÍ hace falta una
  /// caché propia. Se guarda el JSON crudo cada vez que la red
  /// responde bien (`LocalCacheService.saveObject`, misma clase que
  /// usa el resto de la app) — si una reimpresión posterior del mismo
  /// cierre de caja ocurre sin conexión, se usa esa última versión en
  /// vez de fallar. Igual que `_fetchOrder`: solo cae a caché si la
  /// falla es de CONECTIVIDAD (sin `response`), nunca para un error
  /// real del servidor.
  static Future<Map<String, dynamic>> _fetchCashSessionReportJson(
    String sessionId,
  ) async {
    final cacheKey = 'cash_session_report_$sessionId';
    try {
      final dio = sl<Dio>();
      final response = await dio.get('/cash-sessions/$sessionId/report');
      final data = ApiResponseUtils.object(response);
      try {
        await sl<LocalCacheService>().saveObject(cacheKey, data);
      } catch (_) {} // cache es best-effort, nunca debe tumbar la impresión
      return data;
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final cached = sl<LocalCacheService>().getObject(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Arma `CashSessionReportData` desde el JSON crudo de
  /// `GET /cash-sessions/:id/report` — 100% dinámico: la lista de
  /// "otros métodos" y de llaves Bre-B sale directo de `by_method` /
  /// `breb_by_llave`, nunca hardcodea qué métodos o llaves existen.
  /// Misma regla que el backend (`ThermalPrintService.
  /// generateCashSessionReportPdf`): si Bre-B tiene llave(s)
  /// identificada(s), se muestra desglosado por llave y NO además
  /// como línea agregada (evitaría duplicar el total en el ticket).
  static Future<CashSessionReportData> _buildCashSessionReportData(
    String sessionId,
  ) async {
    final data = await _fetchCashSessionReportJson(sessionId);
    final session = CashSessionModel.fromJson(
      (data['session'] as Map).cast<String, dynamic>(),
    );
    final tenant = await _getTenantInfo();

    final byMethod = (data['by_method'] as Map?)?.cast<String, dynamic>() ?? {};
    final brebByLlave =
        (data['breb_by_llave'] as Map?)?.cast<String, dynamic>() ?? {};

    double numOf(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int intOf(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    final llaves = brebByLlave.entries.map((e) {
      final m = (e.value as Map).cast<String, dynamic>();
      final label = (m['label'] as String?)?.trim();
      return CashSessionLlaveLine(
        label: (label != null && label.isNotEmpty) ? label : e.key,
        count: intOf(m['count']),
        total: numOf(m['total']),
      );
    }).toList();

    final otherMethods = byMethod.entries
        .where(
          (e) => e.key != 'cash' && !(e.key == 'breb' && llaves.isNotEmpty),
        )
        .map((e) {
          final m = (e.value as Map).cast<String, dynamic>();
          return CashSessionMethodLine(
            method: e.key,
            count: intOf(m['count']),
            total: numOf(m['total']),
          );
        })
        .toList();

    return CashSessionReportData(
      businessName: tenant.businessName,
      address: tenant.address,
      phone: tenant.phone,
      cashierName: session.closedByName ?? session.openedByName,
      openedAt: DateTime.parse(session.openedAt),
      closedAt: session.closedAt != null
          ? DateTime.parse(session.closedAt!)
          : null,
      isOpen: session.status == 'open',
      openingAmount: session.openingAmount,
      cashCollected: numOf((byMethod['cash'] as Map?)?['total']),
      cashExpenses: session.totalCashExpenses,
      expectedAmount: session.expectedAmount ?? 0,
      countedAmount: session.closingAmountCounted,
      difference: session.difference,
      otherMethods: otherMethods,
      llaves: llaves,
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
    final docLabel = kind == PrintJobKind.receipt ? 'Recibo' : 'Comanda';
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
          // Bug real reportado: "system" dependía 100% del backend
          // (que renderizaba el PDF) — sin internet no imprimía
          // nada, a diferencia de "network" que arma el ticket
          // local. Con una impresora Windows elegida (`printer.host`
          // viene seteado — ver `printer_settings_screen.dart`),
          // hacemos lo mismo que "network": armar el ESC/POS local
          // y mandarlo directo al hardware. `null` = este kind no
          // tiene generador ESC/POS (QR ticket) o no hay impresora
          // elegida/no es Windows — cae al PDF de siempre.
          final viaRaw = await _printSystemEscPosRaw(
            kind: kind,
            orderId: orderId,
            printer: printer,
          );
          ok =
              viaRaw ??
              await _printSystemPdf(
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

  /// Mismo contenido que `_printNetworkEscPos` (ESC/POS armado local
  /// desde el JSON de la orden) pero el transporte es RAW directo al
  /// spooler de Windows (`WindowsRawPrinter`) en vez de un socket TCP
  /// — para impresoras `system` con una impresora instalada elegida.
  ///
  /// Devuelve `null` (no `false`) cuando no aplica: no hay impresora
  /// elegida, no es Windows, o el kind no tiene generador ESC/POS (QR
  /// ticket, igual que en `_printNetworkEscPos`) — en cualquiera de
  /// esos casos el llamador cae al PDF existente, nunca se queda sin
  /// intentar imprimir.
  static Future<bool?> _printSystemEscPosRaw({
    required PrintJobKind kind,
    required String orderId,
    required PrinterConfigModel printer,
  }) async {
    final printerName = printer.host;
    if (printerName == null || printerName.isEmpty) return null;
    if (!WindowsRawPrinter.isSupported) return null;
    if (kind == PrintJobKind.qrTicket) return null;

    final order = await _fetchOrder(orderId);
    if (kind == PrintJobKind.kitchen && !_hasKitchenItems(order)) {
      return true;
    }
    final ticket = await _buildTicketData(order, kind);
    final Uint8List bytes;
    switch (kind) {
      case PrintJobKind.kitchen:
        final tenant = await _getTenantInfo();
        bytes = await EscPosGenerator.buildKitchen(
          data: ticket,
          paperWidthMm: printer.paperWidth,
          printGroups: tenant.kitchenTicketGroups,
        );
        break;
      case PrintJobKind.receipt:
        bytes = await EscPosGenerator.buildReceipt(
          data: ticket,
          paperWidthMm: printer.paperWidth,
        );
        break;
      case PrintJobKind.qrTicket:
        return null; // ya cubierto arriba — inalcanzable
    }
    return PrinterDispatcher.printRawBytesToWindowsPrinter(
      bytes: bytes,
      printerName: printerName,
    );
  }

  /// Para impresoras de red: pedimos JSON de la orden, generamos
  /// ESC/POS local y mandamos bytes al socket.
  static Future<bool> _printNetworkEscPos({
    required PrintJobKind kind,
    required String orderId,
    required PrinterConfigModel printer,
  }) async {
    final order = await _fetchOrder(orderId);
    // Si es comanda y NINGÚN item requiere preparación, no imprimimos
    // nada — sería un papel con header + 0 items (ej. ticket que solo
    // tiene una botella de agua). Retornamos `true` para que el
    // orquestador muestre "OK" sin marcar error.
    if (kind == PrintJobKind.kitchen && !_hasKitchenItems(order)) {
      return true;
    }
    final ticket = await _buildTicketData(order, kind);
    final Uint8List bytes;
    switch (kind) {
      case PrintJobKind.kitchen:
        final tenant = await _getTenantInfo();
        bytes = await EscPosGenerator.buildKitchen(
          data: ticket,
          paperWidthMm: printer.paperWidth,
          printGroups: tenant.kitchenTicketGroups,
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
        return PrinterDispatcher.printPdf(pdfBytes: pdf, jobName: 'QR ticket');
    }
    return PrinterDispatcher.printRawBytes(bytes: bytes, printer: printer);
  }

  /// Para impresoras del SO: pedimos el PDF al backend y dejamos que
  /// el driver del SO lo maneje.
  static Future<bool> _printSystemPdf({
    required PrintJobKind kind,
    required String orderId,
    required PrinterConfigModel printer,
    String? subtitle,
  }) async {
    // Mismo check que en `_printNetworkEscPos`: si es comanda y NINGÚN
    // item requiere preparación, no pedimos el PDF al backend (round-
    // trip inútil) y devolvemos success silencioso. El backend también
    // tiene defensa en profundidad — si por algún motivo llaman al
    // endpoint con orden 100% directa, responde 204 y este path lo
    // maneja con un short-circuit.
    if (kind == PrintJobKind.kitchen) {
      final order = await _fetchOrder(orderId);
      if (!_hasKitchenItems(order)) {
        return true;
      }
    }

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
    // PDF vacío del backend (skip) → no abrir diálogo de impresión.
    if (pdf.isEmpty) return true;
    return PrinterDispatcher.printPdf(
      pdfBytes: pdf,
      jobName: jobName,
      printerUrl: printer.host,
    );
  }

  /// Bug real reportado (pedido explícito: imprimir debe funcionar
  /// con o sin internet, la única excepción real es validar un pago
  /// Bre-B contra el banco): esto SIEMPRE pedía la orden en vivo al
  /// backend, sin ningún fallback — a diferencia del resto de la app,
  /// que ya tiene un patrón "local-first" para listas (ver
  /// `OrderLocalDataSource`/`ProductLocalDataSource`/etc.). Sin
  /// conexión, imprimir (recibo o comanda) fallaba en seco aunque la
  /// orden ya estuviera guardada localmente — la MISMA orden que la
  /// pantalla de Órdenes sí podía mostrar offline, porque esa pantalla
  /// ya usa esa caché y esta ruta de impresión nunca la consultaba.
  ///
  /// Fix: se sigue intentando la red primero SIEMPRE (datos más
  /// frescos) — el fallback a la caché de `OrderLocalDataSource`
  /// (`peekCachedOrders`, sin importar qué tan vieja esté: sin
  /// conexión, lo que haya es mejor que nada) solo entra cuando la
  /// red realmente falla por conectividad (`DioException` sin
  /// `response` — timeout/sin conexión/DNS), nunca para un error real
  /// del servidor (404/500 con response, esos SÍ deben reportarse).
  static Future<OrderModel> _fetchOrder(String orderId) async {
    try {
      final dio = sl<Dio>();
      final response = await dio.get('/orders/$orderId');
      final json = ApiResponseUtils.object(response);
      return OrderModel.fromJson(json);
    } on DioException catch (e) {
      if (e.response != null) rethrow; // error real del servidor, no de red
      final cached = await _findCachedOrder(orderId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<OrderModel?> _findCachedOrder(String orderId) async {
    try {
      final local = sl<OrderLocalDataSource>();
      final cached = await local.peekCachedOrders();
      return cached?.firstWhereOrNull((o) => o.id == orderId);
    } catch (_) {
      return null;
    }
  }

  static Future<List<OrderModel>> _findCachedOrdersByTabSession(
    String tabSessionId,
  ) async {
    try {
      final local = sl<OrderLocalDataSource>();
      final cached = await local.peekCachedOrders();
      return cached?.where((o) => o.tabSessionId == tabSessionId).toList() ??
          const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<TicketData> _buildTicketData(
    OrderModel order,
    PrintJobKind kind,
  ) async {
    final tenant = await _getTenantInfo();
    // El logo solo se imprime en el RECIBO (la comanda de cocina es
    // funcional, sin branding — ahorra papel y tiempo de impresión).
    final logoBytes = kind == PrintJobKind.receipt
        ? await _getLogoBytes(tenant.logoUrl)
        : null;

    // Si la orden no tiene cliente pero pertenece a una cuenta abierta,
    // heredamos el nombre del cliente de la cuenta. Esto cubre el caso
    // donde el mesero agrega un ticket manual a una cuenta QR existente:
    // ese ticket no tiene customer_id propio pero la cuenta sí lo tiene.
    String? customerName = order.customerName;
    if ((customerName == null || customerName.trim().isEmpty) &&
        order.tabSessionId != null) {
      customerName = await _fetchTabCustomerName(order.tabSessionId!);
    }

    return TicketData(
      businessName: tenant.businessName,
      address: tenant.address,
      phone: tenant.phone,
      taxId: tenant.taxId,
      logoBytes: logoBytes,
      orderNumber: order.orderNumber,
      // Se imprime siempre que la orden tenga turno asignado — no hay
      // preferencia aparte que apagarlo: si el negocio pidió turno al
      // crear la orden (ver OrderFormController.submitOrder), es obvio
      // que quiere verlo en la comanda/recibo.
      ticketNumber: order.ticketNumber,
      createdAt: DateTime.tryParse(order.createdAt) ?? DateTime.now(),
      // Para dine-in, cualquier fallback vale (snapshot o nombre crudo
      // de la mesa). Para takeaway/delivery NO hay que caer a
      // `tableName` solo porque el ticket quedó atado a un
      // `table_element_id` (pasa cuando el ticket es "para
      // llevar"/"domicilio" dentro de una cuenta que SÍ está en una
      // mesa, ej. SellMode.tabSession(...).withOrderType(delivery)) —
      // si eso pasara, el destino mostraría "Mesa 5" en vez de
      // "DOMICILIO" aunque el ticket puntual no sea en mesa. Bug real
      // reportado por el usuario.
      tableLabel: order.orderType == 'dine_in'
          ? (order.tableLabel ?? order.tableName)
          : order.tableLabel,
      orderType: order.orderType,
      orderSource: order.orderSource,
      deliveryAddress: order.orderType == 'delivery'
          ? _formatDeliveryAddress(order.deliveryAddress)
          : null,
      customerName: customerName,
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

  /// Devuelve el nombre del cliente de una cuenta abierta, o `null` si
  /// no se puede obtener. Nunca lanza excepción — la impresión no debe
  /// abortar por un fallo en esta consulta secundaria.
  static Future<String?> _fetchTabCustomerName(String tabSessionId) async {
    try {
      final dio = sl<Dio>();
      final response = await dio.get('/tab-sessions/$tabSessionId');
      final json = ApiResponseUtils.object(response);
      final tab = TabSessionModel.fromJson(json);
      final name = tab.customerName?.trim();
      return (name != null && name.isNotEmpty) ? name : null;
    } catch (_) {
      return null;
    }
  }

  /// Junta `street` / `city` / `notes` de `order.delivery_address`
  /// (armado por `OrderFormController._composedDeliveryAddress`) en una
  /// sola línea legible para el recibo. `null` si no hay nada cargado
  /// — pasa en pedidos de delivery viejos o cuando el mesero no la
  /// pidió al crear la orden.
  static String? _formatDeliveryAddress(Map<String, dynamic>? address) {
    if (address == null) return null;
    final parts = <String>[];
    final street = (address['street'] as String?)?.trim();
    final city = (address['city'] as String?)?.trim();
    final notes = (address['notes'] as String?)?.trim();
    if (street != null && street.isNotEmpty) parts.add(street);
    if (city != null && city.isNotEmpty) parts.add(city);
    var text = parts.join(', ');
    if (notes != null && notes.isNotEmpty) {
      text = text.isEmpty ? notes : '$text — $notes';
    }
    return text.isEmpty ? null : text;
  }

  static TicketItem _toTicketItem(OrderItemModel item) {
    // El JSON del backend trae el nombre del extra en el objeto anidado
    // `modifier.name`, NO en el campo plano `modifier_name` (ese nunca
    // llega). Antes esto leía `m.modifierName` directo y siempre salía
    // vacío, así que el extra jamás aparecía en el ticket impreso —
    // aunque sí se veía bien en pantalla (esa parte usa `toEntity()`,
    // que ya tenía el fallback correcto).
    final modifiers = (item.modifiers ?? [])
        .map(
          (m) => TicketModifierLine(
            name: m.modifier?.name ?? m.modifierName ?? 'Extra',
            quantity: m.quantity,
            subtotal: m.subtotal,
          ),
        )
        .toList();
    return TicketItem(
      quantity: item.quantity,
      name: item.productName,
      variantName: item.variantName,
      unitPrice: item.unitPrice,
      subtotal: item.subtotal,
      specialInstructions: item.specialInstructions,
      requiresPreparation: item.requiresPreparation,
      categoryName: item.categoryName,
      categoryId: item.categoryId,
      categoryPrintsKitchen: item.categoryPrintsKitchen,
      selectedFlavors: item.selectedFlavors,
      modifiers: modifiers,
    );
  }

  /// `true` si la orden tiene al menos un item que debe ir a cocina:
  /// requiere preparación Y su categoría imprime comanda.
  static bool _hasKitchenItems(OrderModel order) =>
      order.items.any((i) => i.requiresPreparation && i.categoryPrintsKitchen);

  /// Imprime el recibo combinado de una cuenta abierta respetando
  /// la configuración `auto_print`. Si está desactivado, pregunta al
  /// usuario antes de imprimir.
  static Future<PrintResult> autoPrintTabSessionReceipt(
    TabSession session,
  ) async {
    final printer = await _resolveDefault(PrinterPurpose.receipt);
    if (printer == null) return PrintResult.noPrinterConfigured;
    if (!_userCanPrint(printer)) return PrintResult.roleNotAllowed;

    if (!printer.autoPrint) {
      final should = await _askUser('factura');
      if (!should) return PrintResult.cancelled;
    }

    return _runTabSessionPrint(session, printer, silent: printer.autoPrint);
  }

  /// Imprime un recibo unificado de una cuenta abierta (tab session).
  /// Combina TODOS los tickets no-cancelados en un solo recibo.
  static Future<PrintResult> printTabSessionReceiptManual(
    TabSession session,
  ) async {
    final printer = await _resolveDefault(PrinterPurpose.receipt);
    if (printer == null) {
      _snackNoDefault('cuenta', PrinterPurpose.receipt);
      return PrintResult.noPrinterConfigured;
    }
    if (!_userCanPrint(printer)) {
      AppSnackbar.show('Sin permiso', 'Tu rol no tiene permiso para imprimir.');
      return PrintResult.roleNotAllowed;
    }

    return _runTabSessionPrint(session, printer, silent: false);
  }

  static Future<PrintResult> _runTabSessionPrint(
    TabSession session,
    PrinterConfigModel printer, {
    required bool silent,
  }) async {
    // Bug real reportado (repetido varias veces): el recibo consolidado
    // de la cuenta salía SIN ítems al imprimir apenas se entraba a la
    // pantalla de detalle. Causa real: esa pantalla pinta primero con
    // la caché liviana de "Cuentas abiertas" (sin items/payments
    // anidados — ver `TabSessionDetailController.load`) y la reemplaza
    // por la versión completa (`findOne`) cuando esa segunda carga
    // responde — pero el cajero entra e imprime de una, antes de que
    // eso llegue, así que `session` acá todavía es la liviana. Pedimos
    // la cuenta COMPLETA en vivo primero (mismo endpoint que usa esa
    // pantalla), igual que ya se hace para un ticket individual
    // (`_fetchOrder`) — así el recibo SIEMPRE tiene los items reales,
    // sin importar qué tan rápido se imprima. Solo si de verdad no hay
    // conexión seguimos con la `session` que ya nos pasaron.
    try {
      final dio = sl<Dio>();
      final response = await dio.get('/tab-sessions/${session.id}');
      final json = ApiResponseUtils.object(response);
      session = TabSessionModel.fromJson(json).toEntity();
    } on DioException catch (e) {
      if (e.response != null) rethrow; // error real del servidor, no de red
      // Sin conexión: seguimos con la `session` que ya teníamos.
    }

    // Parsear órdenes crudas del tab, excluir canceladas
    var orders = session.orders
        .whereType<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .where((o) => o.status != 'cancelled')
        .toList();

    // Respaldo adicional (offline o algún ticket que de todas formas
    // llegó sin items): completamos con la caché de Órdenes, igual que
    // antes.
    if (orders.any((o) => o.items.isEmpty)) {
      final cachedOrders = await _findCachedOrdersByTabSession(session.id);
      if (cachedOrders.isNotEmpty) {
        orders = orders.map((o) {
          if (o.items.isNotEmpty) return o;
          return cachedOrders.firstWhereOrNull((c) => c.id == o.id) ?? o;
        }).toList();
      }
    }

    if (orders.isEmpty) {
      AppSnackbar.show('Sin ítems', 'Todos los tickets están cancelados');
      return PrintResult.success;
    }

    final tenant = await _getTenantInfo();
    final logoBytes = await _getLogoBytes(tenant.logoUrl);

    // Bug real corregido: esto hardcodeaba `orderType: 'dine_in'` y
    // `customerPhone: null` sin mirar las órdenes reales de la cuenta
    // — una cuenta de domicilio sin mesa (auto-abierta por
    // `ensureSessionForOrder` en el backend) terminaba imprimiendo
    // "Cuenta · Sin mesa" / "Atención: EN EL SALON", mientras que
    // imprimir la MISMA información desde el detalle de una orden
    // puntual (que sí lee `order.orderType`/`customerPhone`/
    // `deliveryAddress` reales) mostraba domicilio correctamente — dos
    // resultados distintos para el mismo pedido según qué botón se
    // tocara. Derivamos acá el mismo contexto (destino/cliente/
    // dirección) que usa `_buildTicketData` para UN order, a partir de
    // la primera orden activa que no sea dine-in — así ambos caminos
    // de impresión quedan consistentes.
    final deliveryOrTakeaway = orders.firstWhere(
      (o) => o.orderType == 'delivery' || o.orderType == 'takeaway',
      orElse: () => orders.first,
    );
    final effectiveOrderType = deliveryOrTakeaway.orderType;
    // Bug real reportado: para una cuenta SIN mesa (mostrador/turno/
    // para llevar/domicilio sueltos) esto quedaba siempre null,
    // ignorando el `table_label` real de la orden ("Mostrador" o
    // "Turno" — ver `OrderFormController.submitOrder`) — mismo
    // criterio que ya se usa abajo para `customerName`/`customerPhone`
    // (preferir el dato de la orden real sobre un default genérico).
    final effectiveTableLabel = session.tableName != null
        ? 'Mesa ${session.tableName}'
        : deliveryOrTakeaway.tableLabel;

    // Unir ítems de todos los tickets activos
    final allItems = orders.expand((o) => o.items.map(_toTicketItem)).toList();

    // Bug real reportado: acá el campo "Orden:" mostraba "Cuenta ·
    // Ingrid" (mezclando la etiqueta de la cuenta con el identificador),
    // mientras que imprimir el MISMO ticket desde su propio detalle
    // mostraba el número real ("ORD-20261017-0004") — dos formatos
    // distintos del mismo recibo según qué botón se tocara. El nombre
    // del cliente YA se muestra aparte, en "Cliente:" (ver
    // `customerName` más abajo) — "Orden:" debe ser un identificador,
    // igual que en el recibo de un ticket individual. Una cuenta
    // agrupa N tickets sin un order_number único propio, así que
    // usamos el del ticket más antiguo (orden cronológico) como
    // identificador principal, con el conteo de los demás si hay más.
    DateTime parseCreatedAt(String s) => DateTime.tryParse(s) ?? DateTime.now();
    final sortedOrders = [...orders]
      ..sort(
        (a, b) =>
            parseCreatedAt(a.createdAt).compareTo(parseCreatedAt(b.createdAt)),
      );
    final primaryOrderNumber = sortedOrders.first.orderNumber;
    final orderNumberLabel = sortedOrders.length > 1
        ? '$primaryOrderNumber (+${sortedOrders.length - 1})'
        : primaryOrderNumber;

    final ticket = TicketData(
      businessName: tenant.businessName,
      address: tenant.address,
      phone: tenant.phone,
      taxId: tenant.taxId,
      logoBytes: logoBytes,
      orderNumber: orderNumberLabel,
      // Mismo criterio que `_buildTicketData` para un ticket puntual:
      // si el ticket que define el destino de esta cuenta tiene turno
      // asignado, se imprime siempre (bug real reportado: esta
      // consolidada de cuenta nunca lo pasaba, así que una cuenta de
      // Mostrador/Turno nunca mostraba la línea grande "TURNO: N").
      ticketNumber: deliveryOrTakeaway.ticketNumber,
      createdAt: session.openedAt,
      tableLabel: effectiveTableLabel,
      orderType: effectiveOrderType,
      orderSource: 'pos',
      customerName: deliveryOrTakeaway.customerName ?? session.customerName,
      customerPhone: deliveryOrTakeaway.customerPhone,
      deliveryAddress: effectiveOrderType == 'delivery'
          ? _formatDeliveryAddress(deliveryOrTakeaway.deliveryAddress)
          : null,
      // Totales del backend: ya excluyen canceladas (recomputeRollups)
      items: allItems,
      subtotal: session.subtotal,
      taxAmount: session.taxAmount,
      discountAmount: session.discountAmount,
      tipAmount: session.tipAmount,
      totalAmount: session.totalAmount,
      paymentMethod: !session.hasPendingBalance ? 'Pagado' : null,
      notes: '${orders.length} ticket${orders.length > 1 ? "s" : ""}',
    );

    try {
      switch (printer.connectionType) {
        case PrinterConnectionType.network:
          final bytes = await EscPosGenerator.buildReceipt(
            data: ticket,
            paperWidthMm: printer.paperWidth,
          );
          final ok = await PrinterDispatcher.printRawBytes(
            bytes: bytes,
            printer: printer,
          );
          if (ok) {
            if (silent) {
              _snackOkSilent('Cuenta', printer);
            } else {
              _snackOk('Cuenta', printer);
            }
            return PrintResult.success;
          }
          _snackError('cuenta', printer, 'Sin conexión');
          return PrintResult.printerError;

        case PrinterConnectionType.system:
          // Bug real reportado: esto mostraba "no compatible" y nunca
          // imprimía nada por USB — el recibo consolidado de la cuenta
          // solo existía para impresoras de red.
          //
          // Con una impresora Windows elegida, mismo ESC/POS local ya
          // armado arriba (`ticket`) para el camino de red — solo
          // cambia el transporte (RAW al spooler, no socket TCP). Sin
          // esto, el fallback es el PDF renderizado por el backend
          // (`generateTabSessionReceiptPdf`), que sí necesita internet.
          final printerName = printer.host;
          if (printerName != null &&
              printerName.isNotEmpty &&
              WindowsRawPrinter.isSupported) {
            final rawBytes = await EscPosGenerator.buildReceipt(
              data: ticket,
              paperWidthMm: printer.paperWidth,
            );
            final okRaw = PrinterDispatcher.printRawBytesToWindowsPrinter(
              bytes: rawBytes,
              printerName: printerName,
            );
            if (okRaw) {
              if (silent) {
                _snackOkSilent('Cuenta', printer);
              } else {
                _snackOk('Cuenta', printer);
              }
              return PrintResult.success;
            }
          }
          final tps = sl<ThermalPrintService>();
          final pdf = await tps.getTabSessionReceiptPdfBytes(
            tabSessionId: session.id,
            width: printer.paperWidth == 58
                ? ThermalPaperWidth.mm58
                : ThermalPaperWidth.mm80,
          );
          if (pdf.isEmpty) return PrintResult.success;
          final okSystem = await PrinterDispatcher.printPdf(
            pdfBytes: pdf,
            jobName: 'Cuenta',
            printerUrl: printer.host,
          );
          if (okSystem) {
            if (silent) {
              _snackOkSilent('Cuenta', printer);
            } else {
              _snackOk('Cuenta', printer);
            }
            return PrintResult.success;
          }
          _snackError('cuenta', printer, 'No se pudo imprimir');
          return PrintResult.printerError;
      }
    } catch (err) {
      _snackError('cuenta', printer, err);
      return PrintResult.printerError;
    }
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

  static void _snackError(String document, PrinterConfigModel p, Object err) {
    final isNetwork = p.connectionType == PrinterConnectionType.network;
    // Distinguir error de red (socket) de error en generación del ticket
    // (ej. emoji en notas que el encoder ESC/POS no puede representar).
    final errStr = err.toString().toLowerCase();
    final isConnErr =
        errStr.contains('socket') ||
        errStr.contains('connection') ||
        errStr.contains('timeout') ||
        errStr.contains('refused');
    final String reason;
    if (isNetwork && isConnErr) {
      reason = 'Sin conexión con ${p.host}:${p.port}. Revisá la impresora.';
    } else if (isNetwork) {
      // Error en generación de ticket — mostrar causa para depuración.
      final short = err.toString();
      reason =
          'Error al generar ticket: ${short.length > 80 ? short.substring(0, 80) : short}';
    } else {
      reason = 'No se pudo enviar al SO.';
    }
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
    final purposeLabel = purpose == PrinterPurpose.kitchen ? 'Cocina' : 'Caja';
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

  /// URL del logo del negocio (settings.receipt.logo_url). Se descarga
  /// aparte y se cachea como bytes para imprimirlo en el recibo.
  final String? logoUrl;

  /// `settings.printing.kitchen_ticket_groups` — bloques de impresión
  /// configurados por el tenant: cada entrada es una lista de IDs de
  /// categoría que deben salir juntas en UN SOLO documento (un único
  /// corte, sin repetir título/orden/pie por categoría). Una categoría
  /// que no aparece en ningún bloque sigue saliendo SOLA, en su propio
  /// documento — comportamiento de siempre. Default `[]` (sin tocar
  /// negocios existentes). Configurable en Ajustes → Impresoras, ver
  /// `PrinterSettingsScreen`.
  final List<List<String>> kitchenTicketGroups;

  const _TenantInfo({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.taxId,
    this.logoUrl,
    this.kitchenTicketGroups = const [],
  });
}
