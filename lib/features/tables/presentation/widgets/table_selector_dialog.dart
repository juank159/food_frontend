// lib/features/tables/presentation/widgets/table_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/enums/table_capacity.dart';

/// Diálogo responsive para seleccionar el tipo de mesa a colocar
class TableSelectorDialog extends StatelessWidget {
  const TableSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isSmallMobile = screenSize.width < 360;
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
          maxWidth: isMobile ? double.infinity : 500,
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
            // Header
            _buildHeader(context),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Elige la capacidad de la mesa:',
                      style: TextStyle(
                        fontSize: isSmallMobile ? 13 : 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    ...TableCapacity.values.map((capacity) {
                      return _buildTableOption(context, capacity);
                    }),
                  ],
                ),
              ),
            ),

            // Footer con botón cancelar
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: isMobile ? 12 : 16,
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                  ),
                ],
              ),
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
            Icons.table_restaurant,
            color: theme.colorScheme.onPrimary,
            size: isSmallMobile ? 24 : (isMobile ? 28 : 32),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Text(
              'Seleccionar Tipo de Mesa',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontSize: isSmallMobile ? 16 : (isMobile ? 18 : 20),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildTableOption(BuildContext context, TableCapacity capacity) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isSmallMobile = MediaQuery.of(context).size.width < 360;

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => Get.back(result: capacity),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              // Preview visual de la mesa
              Container(
                width: isSmallMobile ? 50 : (isMobile ? 55 : 60),
                height: isSmallMobile ? 50 : (isMobile ? 55 : 60),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: _getBorderRadius(capacity.shape),
                  shape: capacity.shape == TableShape.round
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                ),
                child: Center(
                  child: Text(
                    capacity.shortName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 16),
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      capacity.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: isSmallMobile ? 14 : (isMobile ? 15 : 16),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      'Capacidad: ${capacity.seats} personas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 14),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isSmallMobile) ...[
                      Text(
                        'Forma: ${_getShapeName(capacity.shape)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: isMobile ? 11 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: isMobile ? 14 : 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius? _getBorderRadius(TableShape shape) {
    switch (shape) {
      case TableShape.square:
        return BorderRadius.circular(4);
      case TableShape.rectangular:
        return BorderRadius.circular(8);
      case TableShape.oval:
        return BorderRadius.circular(30);
      case TableShape.round:
        return null;
    }
  }

  String _getShapeName(TableShape shape) {
    switch (shape) {
      case TableShape.square:
        return 'Cuadrada';
      case TableShape.round:
        return 'Redonda';
      case TableShape.rectangular:
        return 'Rectangular';
      case TableShape.oval:
        return 'Ovalada';
    }
  }
}
