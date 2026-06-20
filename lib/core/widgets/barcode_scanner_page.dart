import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/theme/app_colors.dart';

/// Abre el escáner de cámara y devuelve el código leído (o null si el
/// usuario canceló). Uso:
/// ```dart
/// final code = await scanBarcode(context);
/// if (code != null) _skuCtrl.text = code;
/// ```
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
  );
}

/// Pantalla de escaneo de códigos de barras / QR con la cámara.
/// Hace `pop(code)` con el primer código válido detectado.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    // `noDuplicates` evita disparar el mismo código muchas veces seguidas.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.trim().isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Marco guía para apuntar.
          Container(
            width: 250,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Apuntá la cámara al código de barras',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: AppColors.textPrimary, blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
