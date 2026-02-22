import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _handlingScan = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingScan) return;
    _handlingScan = true;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) {
      _handlingScan = false;
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _handlingScan = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Tara')),
      body: Column(
        children: [
          Expanded(
              child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Kamera açılamadı.\n\n${error.toString()}\n\n'
                    'Not: Web’de kamera için HTTPS gerekir (localhost hariç).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'QR kodu kameraya göster.',
              style: TextStyle(
                color: Colors.black.withAlpha(160),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
