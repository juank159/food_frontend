import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/models/printer_config_model.dart';
import '../../data/printer_configs_local_datasource.dart';
import '../../data/printer_configs_remote_datasource.dart';
import '../../data/printer_dispatcher.dart';

class PrinterConfigsController extends GetxController {
  PrinterConfigsController({
    PrinterConfigsRemoteDataSource? dataSource,
    PrinterConfigsLocalDataSource? localDataSource,
  })  : _ds = dataSource ?? sl<PrinterConfigsRemoteDataSource>(),
        _local = localDataSource ?? sl<PrinterConfigsLocalDataSource>();

  final PrinterConfigsRemoteDataSource _ds;
  final PrinterConfigsLocalDataSource _local;

  final RxList<PrinterConfigModel> printers = <PrinterConfigModel>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxSet<String> processingIds = <String>{}.obs;

  /// Default para cocina (puede ser una `kitchen` o una `both`).
  PrinterConfigModel? get defaultKitchen => _findDefault(PrinterPurpose.kitchen);

  /// Default para recibo (puede ser una `receipt` o una `both`).
  PrinterConfigModel? get defaultReceipt => _findDefault(PrinterPurpose.receipt);

  PrinterConfigModel? _findDefault(PrinterPurpose purpose) {
    final specific = printers.firstWhereOrNull(
      (p) => p.isActive && p.isDefault && p.purpose == purpose,
    );
    if (specific != null) return specific;
    return printers.firstWhereOrNull(
      (p) => p.isActive && p.isDefault && p.purpose == PrinterPurpose.both,
    );
  }

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  /// Local-first (mismo patrón que products/categories/employees/
  /// customers): si hay config cacheada, la pinta YA sin el loading
  /// grande — el pedido de red de siempre sigue atrás y, si responde,
  /// reemplaza la lista. Si la red falla y ya había algo pintado, se
  /// queda con eso en silencio en vez de tapar la pantalla con error.
  Future<void> fetch() async {
    error.value = null;

    final cached = await _local.peekCachedPrinterConfigs();
    final paintedFromCache = cached != null && cached.isNotEmpty;
    if (paintedFromCache) {
      printers.assignAll(cached);
    }

    loading.value = !paintedFromCache;
    try {
      final list = await _ds.list();
      printers.assignAll(list);
      // Persist to local cache so configs survive app restart when offline.
      await _local.cachePrinterConfigs(list.map((p) => p.toJson()).toList());
    } catch (e) {
      if (paintedFromCache) return; // ya hay algo en pantalla, no molestar
      // Network or server failure — try local cache before surfacing error.
      final fallback = await _local.getCachedPrinterConfigs();
      if (fallback != null && fallback.isNotEmpty) {
        printers.assignAll(fallback);
        // Don't expose an error to the UI; silent fallback.
      } else {
        error.value = e.toString();
      }
    } finally {
      loading.value = false;
    }
  }

  Future<void> create({
    required String name,
    required PrinterPurpose purpose,
    required PrinterConnectionType connectionType,
    String? host,
    int? port,
    required int paperWidth,
    bool isDefault = false,
    bool autoPrint = true,
    String? notes,
    List<String> allowedRoles = const [],
  }) async {
    try {
      final created = await _ds.create(
        name: name,
        purpose: purpose,
        connectionType: connectionType,
        host: host,
        port: port,
        paperWidth: paperWidth,
        isDefault: isDefault,
        autoPrint: autoPrint,
        notes: notes,
        allowedRoles: allowedRoles,
      );
      await fetch(); // refresca todos para reflejar despromote de otros default
      AppSnackbar.show('Impresora agregada', created.name);
    } catch (e) {
      AppSnackbar.show('Error al agregar', e.toString());
      rethrow;
    }
  }

  Future<void> edit(
    String id, {
    String? name,
    PrinterPurpose? purpose,
    PrinterConnectionType? connectionType,
    String? host,
    int? port,
    int? paperWidth,
    bool? isDefault,
    bool? autoPrint,
    bool? isActive,
    String? notes,
    List<String>? allowedRoles,
  }) async {
    if (processingIds.contains(id)) return;
    processingIds.add(id);
    try {
      await _ds.update(
        id,
        name: name,
        purpose: purpose,
        connectionType: connectionType,
        host: host,
        port: port,
        paperWidth: paperWidth,
        isDefault: isDefault,
        autoPrint: autoPrint,
        isActive: isActive,
        notes: notes,
        allowedRoles: allowedRoles,
      );
      await fetch();
    } catch (e) {
      AppSnackbar.show('Error al actualizar', e.toString());
    } finally {
      processingIds.remove(id);
    }
  }

  Future<void> setAsDefault(String id) async {
    if (processingIds.contains(id)) return;
    processingIds.add(id);
    try {
      await _ds.setAsDefault(id);
      await fetch();
      AppSnackbar.show('Default actualizada', 'Esta impresora ahora es la principal.');
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
    } finally {
      processingIds.remove(id);
    }
  }

  Future<void> remove(PrinterConfigModel printer) async {
    try {
      await _ds.remove(printer.id);
      printers.removeWhere((p) => p.id == printer.id);
      AppSnackbar.show('Impresora eliminada', printer.name);
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
    }
  }

  /// Test de conexión sin imprimir (solo para red).
  Future<bool> testNetworkPing({required String host, required int port}) {
    return PrinterDispatcher.testNetworkConnection(host: host, port: port);
  }
}
