import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/services/branch/branch_service.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/sheet_handle.dart';

/// Sedes en las que trabaja un empleado (solo con varias sedes). Sin
/// ninguna marcada = puede trabajar en todas. Lo valida la app al elegir
/// sede; las ventas hechas sin internet nunca se rechazan por esto.
class EmployeeBranchesCard extends StatefulWidget {
  final String userId;
  const EmployeeBranchesCard({super.key, required this.userId});

  @override
  State<EmployeeBranchesCard> createState() => _EmployeeBranchesCardState();
}

class _EmployeeBranchesCardState extends State<EmployeeBranchesCard> {
  final Dio _dio = GetIt.I<Dio>();
  List<String>? _assigned; // null = cargando / error
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final map = ApiResponseUtils.object(await _dio.get('/branches/assignments'));
      final ids = (map[widget.userId] as List?)?.cast<String>() ?? <String>[];
      if (mounted) setState(() => _assigned = ids);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _edit() async {
    final service = BranchService.maybe;
    if (service == null || _assigned == null) return;
    final selected = {..._assigned!};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const Text('Sedes donde trabaja',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Sin ninguna marcada puede trabajar en todas.',
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                for (final b in service.mine)
                  CheckboxListTile(
                    value: selected.contains(b.id),
                    title: Text(b.name),
                    onChanged: (v) => setSheet(() {
                      if (v == true) {
                        selected.add(b.id);
                      } else {
                        selected.remove(b.id);
                      }
                    }),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      await _dio.put('/branches/assignments/${widget.userId}',
          data: {'branch_ids': result.toList()});
      setState(() => _assigned = result.toList());
      AppSnackbar.show('Sedes', 'Sedes del empleado actualizadas');
    } on DioException catch (e) {
      AppSnackbar.show('Sedes', ApiResponseUtils.errorMessage(e) ?? 'No se pudo guardar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = BranchService.maybe;
    if (service == null) return const SizedBox.shrink();
    return Obx(() {
      if (!service.isMulti) return const SizedBox.shrink();
      final names = {for (final b in service.mine) b.id: b.name};
      final label = _error
          ? 'No se pudo cargar (sin conexión)'
          : _assigned == null
              ? 'Cargando…'
              : _assigned!.isEmpty
                  ? 'Todas las sedes'
                  : _assigned!.map((id) => names[id] ?? 'Sede inactiva').join(', ');
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            leading: Icon(Icons.storefront, color: AppColors.primary),
            title: const Text('Sedes donde trabaja',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(label),
            trailing: _assigned == null ? null : const Icon(Icons.edit_outlined),
            onTap: _assigned == null ? null : _edit,
          ),
        ),
      );
    });
  }
}
