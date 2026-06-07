// lib/features/tables/presentation/widgets/icon_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/enums/floor_plan_icons.dart';

/// Diálogo profesional para seleccionar iconos de diferentes categorías
class IconSelectorDialog extends StatelessWidget {
  final String category;

  const IconSelectorDialog({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;

    // Padding seguro para notch/barra de estado
    final safePadding = MediaQuery.of(context).padding;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? safePadding.top + 20 : 60,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : (isTablet ? 500 : 600),
          maxHeight: screenSize.height - (isMobile ? safePadding.top + 40 : 120),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Expanded(
              child: _buildIconGrid(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isSmallMobile = MediaQuery.of(context).size.width < 360;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMobile ? 20 : 24),
          topRight: Radius.circular(isMobile ? 20 : 24),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(),
            color: theme.colorScheme.onPrimary,
            size: isSmallMobile ? 24 : (isMobile ? 28 : 32),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getCategoryTitle(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isSmallMobile) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona el estilo que prefieras',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                      fontSize: isMobile ? 12 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: theme.colorScheme.onPrimary,
              size: isMobile ? 20 : 24,
            ),
            onPressed: () => Get.back(),
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 360;

    // Determinar número de columnas según el tamaño de pantalla
    int crossAxisCount;
    double spacing;
    double iconSize;
    double fontSize;

    if (isSmallMobile) {
      crossAxisCount = 2; // 2 columnas en móviles pequeños
      spacing = 12;
      iconSize = 40;
      fontSize = 11;
    } else if (isMobile) {
      crossAxisCount = 3; // 3 columnas en móviles normales
      spacing = 14;
      iconSize = 44;
      fontSize = 12;
    } else {
      crossAxisCount = 3; // 3 columnas en tablet/desktop
      spacing = 16;
      iconSize = 48;
      fontSize = 12;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 1.0,
        ),
        itemCount: _getIconOptions().length,
        itemBuilder: (context, index) {
          final iconData = _getIconOptions()[index];
          return _buildIconOption(iconData, iconSize, fontSize, context);
        },
      ),
    );
  }

  Widget _buildIconOption(FloorPlanIconData iconData, double iconSize, double fontSize, BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Get.back(result: iconData),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 2,
          ),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData.icon,
              size: iconSize,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: fontSize < 12 ? 6 : 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                iconData.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (category) {
      case 'kitchen':
        return Icons.restaurant_menu;
      case 'decoration':
        return Icons.auto_awesome;
      case 'door':
        return Icons.door_sliding;
      case 'bar':
        return Icons.local_bar;
      case 'bathroom':
        return Icons.wc;
      default:
        return Icons.category;
    }
  }

  String _getCategoryTitle() {
    switch (category) {
      case 'kitchen':
        return 'Tipos de Cocina/Comida';
      case 'decoration':
        return 'Elementos Decorativos';
      case 'door':
        return 'Estilos de Puertas';
      case 'bar':
        return 'Tipos de Bar';
      case 'bathroom':
        return 'Tipos de Baño';
      default:
        return 'Seleccionar Icono';
    }
  }

  List<FloorPlanIconData> _getIconOptions() {
    switch (category) {
      case 'kitchen':
        return KitchenIconType.values
            .map((type) => FloorPlanIconData(
                  category: 'kitchen',
                  subType: type.value,
                  icon: type.icon,
                  displayName: type.displayName,
                ))
            .toList();

      case 'decoration':
        return DecorationIconType.values
            .map((type) => FloorPlanIconData(
                  category: 'decoration',
                  subType: type.value,
                  icon: type.icon,
                  displayName: type.displayName,
                ))
            .toList();

      case 'door':
        return DoorIconType.values
            .map((type) => FloorPlanIconData(
                  category: 'door',
                  subType: type.value,
                  icon: type.icon,
                  displayName: type.displayName,
                ))
            .toList();

      case 'bar':
        return BarIconType.values
            .map((type) => FloorPlanIconData(
                  category: 'bar',
                  subType: type.value,
                  icon: type.icon,
                  displayName: type.displayName,
                ))
            .toList();

      case 'bathroom':
        return BathroomIconType.values
            .map((type) => FloorPlanIconData(
                  category: 'bathroom',
                  subType: type.value,
                  icon: type.icon,
                  displayName: type.displayName,
                ))
            .toList();

      default:
        return [];
    }
  }
}
