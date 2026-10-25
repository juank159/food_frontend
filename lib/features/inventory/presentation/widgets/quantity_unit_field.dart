import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/ingredient.dart';
import 'inventory_format.dart';

/// Campo de cantidad + selector de unidad compatible con la del insumo.
/// El valor que entrega [onChanged] SIEMPRE está en la unidad base del
/// insumo ([baseUnit]) — el usuario puede escribir "2 kg" de un insumo
/// que se lleva en gramos y llega 2000.
class QuantityUnitField extends StatefulWidget {
  final IngredientUnit baseUnit;
  final double? initialBaseValue;
  final String label;
  final ValueChanged<double?> onChanged;
  final bool allowNegative;
  final bool autofocus;

  const QuantityUnitField({
    super.key,
    required this.baseUnit,
    required this.onChanged,
    this.initialBaseValue,
    this.label = 'Cantidad',
    this.allowNegative = false,
    this.autofocus = false,
  });

  @override
  State<QuantityUnitField> createState() => _QuantityUnitFieldState();
}

class _QuantityUnitFieldState extends State<QuantityUnitField> {
  late IngredientUnit _unit;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _unit = widget.baseUnit;
    final v = widget.initialBaseValue;
    _ctrl = TextEditingController(text: v == null ? '' : fmtNumber(v).replaceAll('.', ''));
  }

  @override
  void didUpdateWidget(covariant QuantityUnitField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUnit != widget.baseUnit) {
      _unit = widget.baseUnit;
      _emit();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _emit() {
    final v = parseQty(_ctrl.text);
    widget.onChanged(v == null ? null : widget.baseUnit.convertFrom(v, _unit));
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.baseUnit.compatible;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: widget.allowNegative,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(widget.allowNegative ? r'[-0-9.,]' : r'[0-9.,]'),
              ),
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _emit(),
          ),
        ),
        const SizedBox(width: 8),
        if (units.length > 1)
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<IngredientUnit>(
                value: _unit,
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u, child: Text(u.short)),
                ],
                onChanged: (u) {
                  if (u == null) return;
                  setState(() => _unit = u);
                  _emit();
                },
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              widget.baseUnit.short,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
