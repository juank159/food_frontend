import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../thermal_print/data/thermal_print_service.dart';
import '../../data/models/qr_token_model.dart';
import '../../data/qr_tokens_remote_datasource.dart';

class QrTokensController extends GetxController {
  QrTokensController({
    QrTokensRemoteDataSource? dataSource,
    ThermalPrintService? printService,
  })  : _ds = dataSource ?? sl<QrTokensRemoteDataSource>(),
        _print = printService ?? sl<ThermalPrintService>();

  final QrTokensRemoteDataSource _ds;
  final ThermalPrintService _print;

  final RxList<QrTokenModel> tokens = <QrTokenModel>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxSet<String> printingIds = <String>{}.obs;

  /// Filtro UI — solo afecta lo que se muestra, no se trae del server.
  final RxBool showInactive = false.obs;

  List<QrTokenModel> get visible {
    if (showInactive.value) return tokens;
    return tokens.where((t) => t.isActive).toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    error.value = null;
    try {
      final result = await _ds.list();
      tokens.assignAll(result);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> bulkCreate({
    required QrTokenType type,
    required String labelPrefix,
    required int from,
    required int to,
    String? zoneLabel,
  }) async {
    try {
      final created = await _ds.bulkCreate(
        type: type,
        labelPrefix: labelPrefix,
        from: from,
        to: to,
        zoneLabel: zoneLabel,
      );
      // Insertamos al principio para que sean visibles inmediatamente.
      tokens.insertAll(0, created);
      AppSnackbar.show(
        '${created.length} QRs creados',
        '$labelPrefix $from a $labelPrefix $to',
      );
    } catch (e) {
      AppSnackbar.show('Error al crear bulk', e.toString());
      rethrow;
    }
  }

  /// Pide al backend el PDF A4 con varios QRs en grilla y lo imprime.
  Future<void> printSheet({
    required List<String> codes,
    int perPage = 4,
  }) async {
    if (codes.isEmpty) {
      AppSnackbar.show('Sin QRs', 'Seleccioná al menos un QR para imprimir.');
      return;
    }
    try {
      await _print.printQrSheet(codes: codes, perPage: perPage);
    } catch (e) {
      AppSnackbar.show('Error al imprimir', e.toString());
    }
  }

  Future<void> create({
    required QrTokenType type,
    required String displayLabel,
    String? tableElementId,
    String? zoneLabel,
  }) async {
    try {
      final created = await _ds.create(
        type: type,
        displayLabel: displayLabel,
        tableElementId: tableElementId,
        zoneLabel: zoneLabel,
      );
      tokens.insert(0, created);
      AppSnackbar.show('QR creado', 'Código: ${created.code}');
    } catch (e) {
      AppSnackbar.show('Error al crear QR', e.toString());
      rethrow;
    }
  }

  // Renombrado a `editToken` para no chocar con `GetxController.update`
  // (que toma `List<Object>?` y dispara repaint).
  Future<void> editToken(
    String id, {
    String? displayLabel,
    String? tableElementId,
    String? zoneLabel,
  }) async {
    try {
      final updated = await _ds.update(
        id,
        displayLabel: displayLabel,
        tableElementId: tableElementId,
        zoneLabel: zoneLabel,
      );
      _replace(updated);
      AppSnackbar.show('QR actualizado', updated.displayLabel);
    } catch (e) {
      AppSnackbar.show('Error al actualizar', e.toString());
      rethrow;
    }
  }

  Future<void> deactivate(QrTokenModel token) async {
    try {
      await _ds.deactivate(token.id);
      // Volvemos a fetch para que el campo isActive quede consistente.
      // Alternativa: armar QrTokenModel nuevo con isActive=false —
      // pero el modelo es inmutable y para una operación rara como
      // esta no compensa.
      await fetch();
      AppSnackbar.show('QR desactivado',
          'El sticker físico de "${token.displayLabel}" deja de funcionar.');
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
    }
  }

  Future<void> reactivate(QrTokenModel token) async {
    try {
      final updated = await _ds.reactivate(token.id);
      _replace(updated);
      AppSnackbar.show('QR reactivado', updated.displayLabel);
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
    }
  }

  /// Lanza el dialog del SO para imprimir el QR en papel térmico.
  Future<void> printThermal(
    QrTokenModel token, {
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) async {
    if (printingIds.contains(token.id)) return;
    printingIds.add(token.id);
    try {
      await _print.printQrToken(code: token.code, width: width);
    } catch (e) {
      AppSnackbar.show('Error al imprimir', e.toString());
    } finally {
      printingIds.remove(token.id);
    }
  }

  void _replace(QrTokenModel updated) {
    final i = tokens.indexWhere((t) => t.id == updated.id);
    if (i >= 0) {
      tokens[i] = updated;
    }
  }
}
