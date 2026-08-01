import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';
import 'sheet_handle.dart';

/// Sheet reutilizable para editar / asignar el nombre del cliente.
/// Usado desde order_detail_page y tab_session_detail_page.
///
/// [currentName]: nombre actual (vacío = sin cliente).
/// [onSave]: recibe el nombre y devuelve `true` si el backend lo aceptó.
class EditCustomerSheet extends StatefulWidget {
  final String currentName;
  final Future<bool> Function(String name) onSave;

  const EditCustomerSheet({
    super.key,
    required this.currentName,
    required this.onSave,
  });

  @override
  State<EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends State<EditCustomerSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final ok = await widget.onSave(_ctrl.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final safeBottom = mq.viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom + 20 + kb),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                'Nombre del cliente',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Juan García',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48)),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Guardar'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
