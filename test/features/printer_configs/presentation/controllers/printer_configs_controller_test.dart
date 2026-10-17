import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/features/printer_configs/data/models/printer_config_model.dart';
import 'package:menu_plat/features/printer_configs/data/printer_configs_local_datasource.dart';
import 'package:menu_plat/features/printer_configs/data/printer_configs_remote_datasource.dart';
import 'package:menu_plat/features/printer_configs/presentation/controllers/printer_configs_controller.dart';

PrinterConfigModel _printer(String id) => PrinterConfigModel(
      id: id,
      name: 'Impresora $id',
      purpose: PrinterPurpose.kitchen,
      connectionType: PrinterConnectionType.network,
      host: '192.168.0.1',
      port: 9100,
      paperWidth: 80,
      isDefault: true,
      autoPrint: true,
      isActive: true,
      notes: null,
    );

class _FakeRemote extends PrinterConfigsRemoteDataSource {
  _FakeRemote() : super(dio: Dio());

  List<PrinterConfigModel> result = [];
  Duration delay = Duration.zero;
  Object? throwError;

  @override
  Future<List<PrinterConfigModel>> list() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (throwError != null) throw throwError!;
    return result;
  }
}

class _FakeLocal implements PrinterConfigsLocalDataSource {
  List<PrinterConfigModel>? cached;
  List<PrinterConfigModel>? peeked;
  List<Map<String, dynamic>>? lastCachedJson;

  @override
  Future<List<PrinterConfigModel>?> getCachedPrinterConfigs() async => cached;

  @override
  Future<List<PrinterConfigModel>?> peekCachedPrinterConfigs() async => peeked;

  @override
  Future<void> cachePrinterConfigs(List<Map<String, dynamic>> rawJsonList) async {
    lastCachedJson = rawJsonList;
  }

  @override
  bool get hasFreshCache => cached != null;
}

void main() {
  late _FakeRemote remote;
  late _FakeLocal local;
  late PrinterConfigsController controller;

  setUp(() {
    remote = _FakeRemote();
    local = _FakeLocal();
    controller = PrinterConfigsController(dataSource: remote, localDataSource: local);
  });

  test(
    'local-first: pinta el caché de inmediato sin mostrar el loading grande',
    () async {
      local.peeked = [_printer('cached-1')];
      remote.result = [_printer('fresh-1')];
      remote.delay = const Duration(milliseconds: 20);

      final future = controller.fetch();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(controller.printers.map((p) => p.id), ['cached-1']);
      expect(controller.loading.value, isFalse);

      await future;
      expect(controller.printers.map((p) => p.id), ['fresh-1']);
    },
  );

  test('sin caché: muestra loading hasta que responda la red', () async {
    local.peeked = null;
    remote.result = [_printer('fresh-1')];

    await controller.fetch();

    expect(controller.printers.map((p) => p.id), ['fresh-1']);
  });

  test(
    'BUG a evitar: si ya pintó del caché y la red falla, no la tapa con un error',
    () async {
      local.peeked = [_printer('cached-1')];
      remote.throwError = Exception('sin conexión');

      await controller.fetch();

      expect(controller.printers.map((p) => p.id), ['cached-1']);
      expect(controller.error.value, isNull);
    },
  );

  test(
    'sin caché y la red falla: cae al fallback viejo (getCachedPrinterConfigs)',
    () async {
      local.peeked = null;
      local.cached = [_printer('old-fallback')];
      remote.throwError = Exception('sin conexión');

      await controller.fetch();

      expect(controller.printers.map((p) => p.id), ['old-fallback']);
      expect(controller.error.value, isNull);
    },
  );
}
