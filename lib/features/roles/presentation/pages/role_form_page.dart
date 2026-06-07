import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/role.dart';
import '../controllers/role_controller.dart';

/// Form unificado crear/editar. Si recibe `role` arranca en modo edit.
///
/// El usuario marca permisos por categoría con checkboxes. Roles del
/// sistema (admin, manager, cashier, etc.) bloquean la edición del
/// `code` para no romper el seed ni la lógica del backend que busca
/// por código.
class RoleFormPage extends StatefulWidget {
  final Role? role;
  const RoleFormPage({super.key, this.role});

  bool get isEdit => role != null;

  @override
  State<RoleFormPage> createState() => _RoleFormPageState();
}

class _RoleFormPageState extends State<RoleFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _descCtrl;

  /// Estado mutable del checklist: `{resource: Set<action>}`.
  /// Set se compara por igualdad de contenido — más simple que List
  /// para add/remove.
  late final Map<String, Set<String>> _selected;

  late final RoleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<RoleController>();
    _nameCtrl = TextEditingController(text: widget.role?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.role?.code ?? '');
    _descCtrl = TextEditingController(text: widget.role?.description ?? '');

    _selected = {
      for (final r in PermissionCatalog.resources)
        r.key: <String>{
          ...(widget.role?.permissions[r.key] ?? const <String>[]),
        },
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isSystem => widget.role?.isSystem == true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final permissions = <String, List<String>>{};
    _selected.forEach((resource, actions) {
      if (actions.isNotEmpty) {
        permissions[resource] = actions.toList()..sort();
      }
    });

    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (widget.isEdit) {
      final updated = await _controller.updateRole(
        widget.role!.id,
        name: name,
        description: desc.isEmpty ? null : desc,
        permissions: permissions,
      );
      if (updated != null && mounted) Navigator.pop(context);
    } else {
      final created = await _controller.create(
        name: name,
        code: code,
        permissions: permissions,
        description: desc.isEmpty ? null : desc,
      );
      if (created != null && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Editar rol' : 'Nuevo rol'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _section(
                'Información básica',
                [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del rol',
                      hintText: 'Ej. Mesero senior',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Mínimo 2 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeCtrl,
                    enabled: !widget.isEdit && !_isSystem,
                    decoration: InputDecoration(
                      labelText: 'Código (id único)',
                      hintText: 'mesero_senior',
                      helperText: widget.isEdit
                          ? 'El código no se puede cambiar después de crear'
                          : 'Solo minúsculas, números y guión bajo',
                      border: const OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                    ],
                    validator: (v) {
                      if (widget.isEdit) return null;
                      if (v == null || v.trim().length < 2) {
                        return 'Mínimo 2 caracteres';
                      }
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                        return 'Solo minúsculas, números y _';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Qué hace este rol',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _section(
                'Permisos',
                [
                  const Text(
                    'Marcá qué puede hacer este rol en cada sección de la app.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  for (final res in PermissionCatalog.resources)
                    _ResourceCard(
                      resource: res,
                      selectedActions: _selected[res.key]!,
                      onToggle: (action, value) {
                        setState(() {
                          if (value) {
                            _selected[res.key]!.add(action);
                          } else {
                            _selected[res.key]!.remove(action);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final loading = _controller.isMutating.value;
            return FilledButton.icon(
              onPressed: loading ? null : _submit,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                loading
                    ? 'Guardando...'
                    : (widget.isEdit ? 'Guardar cambios' : 'Crear rol'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final PermissionResource resource;
  final Set<String> selectedActions;
  final void Function(String action, bool value) onToggle;

  const _ResourceCard({
    required this.resource,
    required this.selectedActions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final allOn = selectedActions.length == resource.actions.length;
    final noneOn = selectedActions.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(resource.icon),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  resource.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (allOn) {
                    for (final a in resource.actions) {
                      onToggle(a.key, false);
                    }
                  } else {
                    for (final a in resource.actions) {
                      onToggle(a.key, true);
                    }
                  }
                },
                child: Text(
                  allOn ? 'Quitar todo' : (noneOn ? 'Marcar todo' : 'Marcar todo'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final a in resource.actions)
                FilterChip(
                  selected: selectedActions.contains(a.key),
                  label: Text(a.label),
                  onSelected: (v) => onToggle(a.key, v),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selectedActions.contains(a.key)
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: selectedActions.contains(a.key)
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'receipt_long':
        return Icons.receipt_long;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'payments':
        return Icons.payments;
      case 'insights':
        return Icons.insights;
      case 'table_restaurant':
        return Icons.table_restaurant;
      case 'people':
        return Icons.people;
      case 'badge':
        return Icons.badge;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.shield_outlined;
    }
  }
}
