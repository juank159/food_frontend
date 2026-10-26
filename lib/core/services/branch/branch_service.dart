import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/api_response_utils.dart';

/// Una sede (sucursal) del negocio.
class BranchInfo {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final bool isDefault;

  const BranchInfo({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
    this.isDefault = false,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> json) => BranchInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Sede',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'is_active': isActive,
        'is_default': isDefault,
      };
}

/// Sede de ESTE dispositivo (multi-sucursal).
///
/// - El dispositivo recuerda su sede (por negocio, en `SharedPreferences`):
///   una caja de la Sede Centro sigue siendo de Centro aunque cambie el
///   empleado o se reinicie la app, con o sin internet.
/// - Toda petición lleva `x-branch-id` (ver interceptor en
///   `injection_container.dart`). Lo encolado sin internet guarda la sede
///   del momento y se sincroniza con ESA sede ([zoneKey]).
/// - Negocios de una sola sede no ven nada nuevo: [isMulti] es false.
/// - Admin/gerente pueden "ver todas" en listados y reportes ([viewAll]);
///   lo que se crea sigue quedando en la sede del dispositivo.
class BranchService extends GetxService {
  BranchService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  /// Clave de `Zone` con la sede de una operación de la cola offline.
  static const Symbol zoneKey = #branchId;

  static BranchService? get maybe =>
      Get.isRegistered<BranchService>() ? Get.find<BranchService>() : null;

  /// Sede a mandar en `x-branch-id`: la de la operación encolada que se
  /// está sincronizando, o la del dispositivo.
  static String? headerBranchId() =>
      (Zone.current[zoneKey] as String?) ?? maybe?.current.value?.id;

  final Rxn<BranchInfo> current = Rxn<BranchInfo>();

  /// Sedes activas en las que puede trabajar el usuario de la sesión.
  final RxList<BranchInfo> mine = <BranchInfo>[].obs;

  /// Admin/gerente viendo todas las sedes (solo lectura de listados).
  final RxBool viewAll = false.obs;

  /// Se puso una sede sin que nadie la eligiera (dispositivo nuevo en un
  /// negocio con varias sedes): el inicio pide confirmarla una vez.
  final RxBool needsChoice = false.obs;

  /// Aviso pendiente para mostrar en el inicio (p. ej. el empleado no
  /// está asignado a la sede del dispositivo y se cambió a la suya).
  final RxnString notice = RxnString();

  String? _tenantId;

  bool get isMulti => mine.length > 1;

  String _k(String name) => 'branch.${_tenantId ?? '-'}.$name';

  /// Carga lo guardado en el dispositivo para este negocio (sin red).
  void restore(String tenantId) {
    _tenantId = tenantId;
    try {
      final rawList = _prefs.getString(_k('mine'));
      mine.assignAll(rawList == null
          ? const []
          : (jsonDecode(rawList) as List)
              .map((e) => BranchInfo.fromJson(Map<String, dynamic>.from(e as Map))));
      final rawCurrent = _prefs.getString(_k('current'));
      current.value = rawCurrent == null
          ? null
          : BranchInfo.fromJson(Map<String, dynamic>.from(jsonDecode(rawCurrent) as Map));
      viewAll.value = _prefs.getBool(_k('view_all')) ?? false;
    } catch (_) {
      mine.clear();
      current.value = null;
      viewAll.value = false;
    }
  }

  /// Trae las sedes del usuario (`/branches/mine`) y concilia la del
  /// dispositivo. Sin red se queda con lo guardado: nunca bloquea.
  Future<void> refresh(Dio dio, {String? roleCode}) async {
    try {
      final res = await dio.get('/branches/mine');
      final list = ApiResponseUtils.list(res)
          .whereType<Map>()
          .map((e) => BranchInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isEmpty) return;
      mine.assignAll(list);
      await _prefs.setString(_k('mine'), jsonEncode(list.map((b) => b.toJson()).toList()));
    } catch (_) {
      // Sin red o backend viejo sin sedes → seguimos con lo guardado.
    }
    if (mine.isEmpty) return;

    final cur = current.value;
    final stillMine = cur == null ? null : mine.firstWhereOrNull((b) => b.id == cur.id);
    if (stillMine != null) {
      // Refresca nombre/datos por si el admin los editó.
      await _setCurrent(stillMine);
    } else if (cur == null) {
      final pick = mine.firstWhereOrNull((b) => b.isDefault) ?? mine.first;
      await _setCurrent(pick);
      needsChoice.value = isMulti;
    } else {
      // El usuario no trabaja en la sede del dispositivo → la suya.
      final pick = mine.first;
      notice.value =
          'Este dispositivo estaba en "${cur.name}", pero no estás asignado a esa sede. '
          'Ahora trabajás en "${pick.name}".';
      await _setCurrent(pick);
    }

    final canViewAll = roleCode == 'admin' || roleCode == 'manager';
    if (!canViewAll || !isMulti) await setViewAll(false);
  }

  Future<void> _setCurrent(BranchInfo b) async {
    current.value = b;
    await _prefs.setString(_k('current'), jsonEncode(b.toJson()));
  }

  /// Cambia la sede del dispositivo. El caller recarga la app (los datos
  /// en pantalla son de la sede anterior).
  Future<void> select(BranchInfo b) async {
    needsChoice.value = false;
    await _setCurrent(b);
    await setViewAll(false);
  }

  Future<void> setViewAll(bool value) async {
    viewAll.value = value;
    await _prefs.setBool(_k('view_all'), value);
  }

  /// Reemplaza la lista local (tras crear/editar sedes desde Ajustes).
  Future<void> updateList(List<BranchInfo> active) async {
    mine.assignAll(active);
    await _prefs.setString(_k('mine'), jsonEncode(active.map((b) => b.toJson()).toList()));
    final cur = current.value;
    if (cur != null) {
      final same = active.firstWhereOrNull((b) => b.id == cur.id);
      if (same != null) await _setCurrent(same);
    }
  }
}
