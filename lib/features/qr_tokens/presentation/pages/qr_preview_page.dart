import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../thermal_print/data/thermal_print_service.dart';

/// Argumentos que recibe `QrPreviewPage` via `Get.toNamed(arguments: ...)`.
class QrPreviewArgs {
  /// Códigos a previsualizar (uno o varios).
  final List<String> codes;

  /// Título visible en el AppBar.
  final String title;

  /// Subtítulo opcional (ej. "Mesa 5 · Areas verdes").
  final String? subtitle;

  /// Tamaño inicial del layout: 1 = QR enorme por hoja, 4 = 4 por hoja, etc.
  final int initialPerPage;

  const QrPreviewArgs({
    required this.codes,
    required this.title,
    this.subtitle,
    this.initialPerPage = 1,
  });
}

/// Pantalla de vista previa del PDF del QR antes de imprimir.
///
/// Usa el widget `PdfPreview` del paquete `printing` que muestra el
/// PDF a pantalla completa con zoom, navegación entre páginas y
/// botones nativos de impresión / compartir / guardar.
///
/// **Por qué esta pantalla:** el usuario quería ver cómo va a salir
/// el QR antes de imprimir. Con preview en pantalla evitamos
/// imprimir-y-tirar-papel-mal-cortado.
class QrPreviewPage extends StatefulWidget {
  const QrPreviewPage({super.key});

  @override
  State<QrPreviewPage> createState() => _QrPreviewPageState();
}

class _QrPreviewPageState extends State<QrPreviewPage> {
  late QrPreviewArgs _args;
  late int _perPage;
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    // Argumentos requeridos — si llegamos sin nada, fallback razonable.
    final raw = Get.arguments;
    if (raw is QrPreviewArgs) {
      _args = raw;
    } else {
      _args = const QrPreviewArgs(
        codes: [],
        title: 'Vista previa',
        initialPerPage: 1,
      );
    }
    _perPage = _args.initialPerPage;
    _load();
  }

  Future<void> _load() async {
    if (_args.codes.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No hay códigos para mostrar.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await sl<ThermalPrintService>().getQrSheetBytes(
        codes: _args.codes,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _changeLayout(int perPage) {
    if (perPage == _perPage) return;
    setState(() => _perPage = perPage);
    _load();
  }

  /// Imprimir directo desde el AppBar (sin pasar por el botón interno
  /// del PdfPreview que en macOS desktop a veces no responde si los
  /// entitlements no están bien). Con un timeout para no colgar la UI.
  Future<void> _printNow() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => _pdfBytes!,
        name: 'QR ${_args.subtitle ?? ''}',
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          AppSnackbar.show(
            'Sin respuesta de la impresora',
            'El diálogo no se abrió. Revisá los permisos del SO o probá "Compartir PDF".',
            duration: const Duration(seconds: 6),
          );
          return false;
        },
      );
    } catch (e) {
      AppSnackbar.show(
        'No se pudo imprimir',
        '$e — probá "Compartir PDF" y abrilo en el visor del sistema.',
        duration: const Duration(seconds: 6),
      );
    }
  }

  /// Compartir / guardar el PDF (fallback robusto si imprimir directo falla).
  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: 'qr-${_args.codes.first}-x$_perPage.pdf',
      );
    } catch (e) {
      AppSnackbar.show('No se pudo compartir', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPrint = !_loading && _pdfBytes != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _args.title,
              style: const TextStyle(fontSize: 16),
            ),
            if (_args.subtitle != null)
              Text(
                _args.subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Compartir PDF',
            icon: const Icon(Icons.ios_share),
            onPressed: canPrint ? _sharePdf : null,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: canPrint ? _printNow : null,
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Imprimir'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _LayoutSelector(
            current: _perPage,
            totalCodes: _args.codes.length,
            onChanged: _changeLayout,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Generando vista previa…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber,
                  size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_pdfBytes == null) return const SizedBox.shrink();

    // PdfPreview — solo para visualizar y hacer zoom. Las acciones
    // de imprimir/compartir van en el AppBar (más confiable en macOS).
    return PdfPreview(
      build: (_) async => _pdfBytes!,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowSharing: false, // tenemos botón propio en AppBar
      allowPrinting: false, // tenemos botón propio en AppBar
      useActions: false, // oculta toolbar inferior del widget
      pdfFileName: 'qr-${_args.codes.first}-x$_perPage.pdf',
    );
  }
}

/// Selector visual del layout: 1 grande / 4 / 8 / 12 por hoja.
class _LayoutSelector extends StatelessWidget {
  final int current;
  final int totalCodes;
  final ValueChanged<int> onChanged;

  const _LayoutSelector({
    required this.current,
    required this.totalCodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Si solo hay 1 código, no tiene sentido ofrecer layouts múltiples.
    final options = totalCodes == 1
        ? <_LayoutOption>[
            const _LayoutOption(1, 'XL', '1 por hoja'),
            const _LayoutOption(4, 'M', '4 por hoja'),
          ]
        : <_LayoutOption>[
            const _LayoutOption(1, 'XL', '1 por hoja'),
            const _LayoutOption(4, 'M', '4 por hoja'),
            const _LayoutOption(8, 'S', '8 por hoja'),
            const _LayoutOption(12, 'XS', '12 por hoja'),
          ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.white,
      child: Row(
        children: [
          Icon(Icons.grid_view, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            'Tamaño:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final opt in options) ...[
                    _LayoutChip(
                      label: opt.label,
                      hint: opt.hint,
                      selected: opt.value == current,
                      onTap: () => onChanged(opt.value),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutOption {
  final int value;
  final String label;
  final String hint;
  const _LayoutOption(this.value, this.label, this.hint);
}

class _LayoutChip extends StatelessWidget {
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutChip({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: selected ? 1 : 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            Text(
              hint,
              style: TextStyle(
                fontSize: 9,
                color: selected
                    ? Colors.white70
                    : AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
