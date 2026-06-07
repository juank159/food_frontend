import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../products/domain/entities/modifier.dart';
import '../../../products/domain/entities/modifier_group.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/selected_modifier.dart';

/// Modifier Selector Widget
/// Widget profesional para seleccionar modificadores de un producto
/// Soporta validaciones, selección única/múltiple y experiencia mejorada
class ModifierSelectorWidget extends StatefulWidget {
  final Product product;
  final List<SelectedModifier>? initialModifiers;
  final VoidCallback? onChanged;

  const ModifierSelectorWidget({
    super.key,
    required this.product,
    this.initialModifiers,
    this.onChanged,
  });

  @override
  State<ModifierSelectorWidget> createState() => ModifierSelectorWidgetState();
}

class ModifierSelectorWidgetState extends State<ModifierSelectorWidget> {
  // Map<groupId, Map<modifierId, quantity>>
  final Map<String, Map<String, int>> _selectedModifiers = {};
  final Map<String, String?> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _initializeSelections();
  }

  void _initializeSelections() {
    if (widget.initialModifiers != null && widget.initialModifiers!.isNotEmpty) {
      for (final selected in widget.initialModifiers!) {
        // Find which group this modifier belongs to
        for (final group in widget.product.modifierGroups) {
          final modifier = group.modifiers.firstWhereOrNull(
            (m) => m.id == selected.modifierId,
          );
          if (modifier != null) {
            _selectedModifiers[group.id] ??= {};
            _selectedModifiers[group.id]![modifier.id] = selected.quantity;
            break;
          }
        }
      }
    }
  }

  List<SelectedModifier> getSelectedModifiers() {
    final List<SelectedModifier> result = [];

    for (final group in widget.product.modifierGroups) {
      final groupSelections = _selectedModifiers[group.id];
      if (groupSelections == null) continue;

      for (final modifierId in groupSelections.keys) {
        final quantity = groupSelections[modifierId]!;
        if (quantity <= 0) continue;

        final modifier = group.modifiers.firstWhereOrNull(
          (m) => m.id == modifierId,
        );
        if (modifier == null) continue;

        result.add(SelectedModifier.fromModifier(
          modifierId: modifier.id,
          name: modifier.name,
          price: modifier.price,
          quantity: quantity,
        ));
      }
    }

    return result;
  }

  bool validateAllGroups() {
    _validationErrors.clear();
    bool isValid = true;

    for (final group in widget.product.modifierGroups.where((g) => g.isActive)) {
      final selectedCount = _getSelectedCount(group.id);

      if (group.isRequired && selectedCount < group.minSelections) {
        _validationErrors[group.id] =
            'Debes seleccionar al menos ${group.minSelections}';
        isValid = false;
      } else if (group.maxSelections != null &&
          selectedCount > group.maxSelections!) {
        _validationErrors[group.id] =
            'Puedes seleccionar máximo ${group.maxSelections}';
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  int _getSelectedCount(String groupId) {
    final groupSelections = _selectedModifiers[groupId];
    if (groupSelections == null) return 0;
    return groupSelections.values.where((qty) => qty > 0).length;
  }

  void _toggleModifier(ModifierGroup group, Modifier modifier) {
    setState(() {
      _selectedModifiers[group.id] ??= {};

      if (group.allowsSingleOnly) {
        // Single selection: clear all others and set this one
        final isCurrentlySelected =
            _selectedModifiers[group.id]![modifier.id] == 1;
        _selectedModifiers[group.id]!.clear();
        if (!isCurrentlySelected) {
          _selectedModifiers[group.id]![modifier.id] = 1;
        }
      } else {
        // Multiple selection: toggle this one
        final currentQty = _selectedModifiers[group.id]![modifier.id] ?? 0;
        if (currentQty > 0) {
          _selectedModifiers[group.id]![modifier.id] = 0;
        } else {
          _selectedModifiers[group.id]![modifier.id] = 1;
        }
      }

      // Clear validation error for this group
      _validationErrors.remove(group.id);

      // Notify parent
      widget.onChanged?.call();
    });
  }

  void _updateQuantity(ModifierGroup group, Modifier modifier, int delta) {
    setState(() {
      _selectedModifiers[group.id] ??= {};
      final currentQty = _selectedModifiers[group.id]![modifier.id] ?? 0;
      int newQty = currentQty + delta;

      // Clamp to valid range
      if (newQty < 0) newQty = 0;
      if (modifier.maxQuantity != null && newQty > modifier.maxQuantity!) {
        newQty = modifier.maxQuantity!;
      }

      _selectedModifiers[group.id]![modifier.id] = newQty;

      // Clear validation error for this group
      _validationErrors.remove(group.id);

      // Notify parent
      widget.onChanged?.call();
    });
  }

  bool _isModifierSelected(String groupId, String modifierId) {
    return (_selectedModifiers[groupId]?[modifierId] ?? 0) > 0;
  }

  int _getModifierQuantity(String groupId, String modifierId) {
    return _selectedModifiers[groupId]?[modifierId] ?? 0;
  }

  double _calculateModifiersTotal() {
    double total = 0.0;

    for (final group in widget.product.modifierGroups) {
      final groupSelections = _selectedModifiers[group.id];
      if (groupSelections == null) continue;

      for (final modifierId in groupSelections.keys) {
        final quantity = groupSelections[modifierId]!;
        if (quantity <= 0) continue;

        final modifier = group.modifiers.firstWhereOrNull(
          (m) => m.id == modifierId,
        );
        if (modifier != null) {
          total += modifier.price * quantity;
        }
      }
    }

    return total;
  }

  // Helper para obtener icono según tipo de modificador
  IconData _getModifierTypeIcon(Modifier modifier) {
    switch (modifier.type.value) {
      case 'addition':
        return Icons.add_circle_outline;
      case 'removal':
        return Icons.remove_circle_outline;
      case 'substitution':
        return Icons.swap_horiz;
      default:
        return Icons.circle_outlined;
    }
  }

  // Helper para obtener color según tipo de modificador
  Color _getModifierTypeColor(Modifier modifier, ThemeData theme) {
    switch (modifier.type.value) {
      case 'addition':
        return theme.colorScheme.primary;
      case 'removal':
        return theme.colorScheme.error;
      case 'substitution':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = ResponsiveConfig(context);
    final activeGroups =
        widget.product.modifierGroups.where((g) => g.isActive).toList();

    if (activeGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header mejorado
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: responsive.padding,
            vertical: responsive.padding * 0.75,
          ),
          padding: EdgeInsets.all(responsive.padding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.padding * 0.75),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: responsive.isMobile ? 24.0 : 28.0,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: responsive.spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personaliza tu orden',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Selecciona tus preferencias',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Modifier Groups con mejor separación
        ...activeGroups.asMap().entries.map((entry) {
          final index = entry.key;
          final group = entry.value;
          return Column(
            children: [
              if (index > 0)
                Divider(
                  height: responsive.padding * 2,
                  thickness: 1,
                  indent: responsive.padding,
                  endIndent: responsive.padding,
                ),
              _buildModifierGroup(
                context,
                group,
                responsive,
                theme,
              ),
            ],
          );
        }),

        // Total con diseño mejorado
        if (_calculateModifiersTotal() > 0) ...[
          SizedBox(height: responsive.spacing * 1.5),
          _buildModifiersTotal(context, responsive, theme),
          SizedBox(height: responsive.spacing),
        ],
      ],
    );
  }

  Widget _buildModifierGroup(
    BuildContext context,
    ModifierGroup group,
    ResponsiveConfig responsive,
    ThemeData theme,
  ) {
    final hasError = _validationErrors.containsKey(group.id);
    final selectedCount = _getSelectedCount(group.id);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.padding,
        vertical: responsive.padding * 0.5,
      ),
      child: ModernCard(
        padding: EdgeInsets.all(responsive.padding * 1.25),
        elevation: hasError ? 4 : 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Header mejorado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: responsive.isMobile ? 16 : 18,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (group.isRequired)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 12,
                                    color: theme.colorScheme.error,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Requerido',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Opcional',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (group.description != null) ...[
                        SizedBox(height: responsive.spacing * 0.5),
                        Text(
                          group.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      SizedBox(height: responsive.spacing * 0.5),
                      Row(
                        children: [
                          Icon(
                            group.allowsSingleOnly ? Icons.radio_button_checked : Icons.check_box,
                            size: 16,
                            color: hasError
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              group.selectionHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: hasError
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (selectedCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$selectedCount seleccionado${selectedCount > 1 ? 's' : ''}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (hasError) ...[
                        SizedBox(height: responsive.spacing * 0.5),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _validationErrors[group.id]!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: responsive.spacing * 1.25),

            // Modifiers List con mejor diseño
            ...group.modifiers
                .where((m) => m.isAvailable)
                .map((modifier) => _buildModifierItem(
                      context,
                      group,
                      modifier,
                      responsive,
                      theme,
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierItem(
    BuildContext context,
    ModifierGroup group,
    Modifier modifier,
    ResponsiveConfig responsive,
    ThemeData theme,
  ) {
    final isSelected = _isModifierSelected(group.id, modifier.id);
    final quantity = _getModifierQuantity(group.id, modifier.id);
    final showQuantityControls =
        group.allowsMultiple && modifier.maxQuantity != null && modifier.maxQuantity! > 1;
    final typeColor = _getModifierTypeColor(modifier, theme);
    final typeIcon = _getModifierTypeIcon(modifier);

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.spacing),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleModifier(group, modifier),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(responsive.padding),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Checkbox/Radio mejorado
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: group.allowsSingleOnly ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: group.allowsSingleOnly ? null : BorderRadius.circular(6),
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          group.allowsSingleOnly ? Icons.circle : Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),

                SizedBox(width: responsive.spacing),

                // Modifier Icon (tipo)
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    typeIcon,
                    size: 20,
                    color: typeColor,
                  ),
                ),

                SizedBox(width: responsive.spacing),

                // Modifier Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modifier.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: responsive.isMobile ? 15 : 16,
                        ),
                      ),
                      if (modifier.description != null) ...[
                        SizedBox(height: 4),
                        Text(
                          modifier.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      // Modifier Type Label mejorado
                      if (modifier.type.value != 'addition') ...[
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                typeIcon,
                                size: 12,
                                color: typeColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                modifier.type.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(width: responsive.spacing),

                // Price or Quantity Controls
                if (showQuantityControls && isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: quantity > 1
                                ? () => _updateQuantity(group, modifier, -1)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.remove,
                                size: 18,
                                color: quantity > 1
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            quantity.toString(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: quantity < modifier.maxQuantity!
                                ? () => _updateQuantity(group, modifier, 1)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.add,
                                size: 18,
                                color: quantity < modifier.maxQuantity!
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (modifier.hasAdditionalCost)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${CurrencyFormatter.format(modifier.price)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green.shade700,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Gratis',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // NOTA: este branch solo se renderiza cuando NO se
                      // muestran los controles de cantidad (la condición
                      // espejo está más arriba). No hay `x$quantity` acá
                      // porque sería código muerto: cuando hay quantity
                      // controls, este `else` ni se evalúa.
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModifiersTotal(
    BuildContext context,
    ResponsiveConfig responsive,
    ThemeData theme,
  ) {
    final modifiersTotal = _calculateModifiersTotal();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.padding),
      child: Container(
        padding: EdgeInsets.all(responsive.padding * 1.25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.secondary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add_circle,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            SizedBox(width: responsive.spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total modificadores',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    'Costo adicional',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${CurrencyFormatter.format(modifiersTotal)}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
