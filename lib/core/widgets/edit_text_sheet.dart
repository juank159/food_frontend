import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';
import 'sheet_handle.dart';

/// Sheet genérico para editar un campo de texto (línea simple o multiline).
///
/// [title]: título visible en la cabecera del sheet.
/// [currentValue]: valor inicial del campo.
/// [hint]: placeholder del TextField.
/// [icon]: ícono a la izquierda del título.
/// [maxLines]: null = multiline expandible; 1 = línea única.
/// [onSave]: recibe el texto y devuelve `true` si el backend lo aceptó.
class EditTextSheet extends StatefulWidget {
  final String title;
  final String currentValue;
  final String hint;
  final IconData icon;
  final int? maxLines;
  final Future<bool> Function(String value) onSave;

  const EditTextSheet({
    super.key,
    required this.title,
    required this.currentValue,
    required this.hint,
    required this.icon,
    required this.onSave,
    this.maxLines = 1,
  });

  @override
  State<EditTextSheet> createState() => _EditTextSheetState();
}

class _EditTextSheetState extends State<EditTextSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentValue);
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
    final isMultiline = widget.maxLines != 1;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.65),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, mq.viewPadding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Row(
              children: [
                Icon(widget.icon, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
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
              maxLines: isMultiline ? 4 : 1,
              minLines: isMultiline ? 2 : 1,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: isMultiline
                  ? TextInputType.multiline
                  : TextInputType.text,
              onSubmitted: isMultiline ? null : (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.hint,
                border: const OutlineInputBorder(),
                prefixIcon: isMultiline ? null : Icon(widget.icon),
                alignLabelWithHint: isMultiline,
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
      ),
    );
  }
}
