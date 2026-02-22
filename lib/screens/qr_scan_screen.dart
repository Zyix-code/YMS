import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/app_error.dart';

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

  bool _handlingScan = false;

  @override
  void dispose() {
    // ✅ Kamera kilidini bırak
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finishWithCode(String code) async {
    await _controller.stop();
    if (!mounted) return;
    Navigator.pop(context, code);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingScan) return;
    _handlingScan = true;

    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    final barcode = (raw ?? '').trim();

    if (barcode.isEmpty) {
      _handlingScan = false;
      return;
    }

    await Future.delayed(const Duration(milliseconds: 120));
    await _finishWithCode(barcode);

    _handlingScan = false;
  }

  Widget _errorUi(MobileScannerException error) {
    final msg = trCameraError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 46, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                await _controller.stop();
                await _controller.start();
                if (!mounted) return;
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
            const SizedBox(height: 10),
            Text(
              'İpucu: Aynı anda iki YMS sekmesi açıksa kamera “kullanımda” hatası verebilir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withAlpha(140),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
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
              errorBuilder: (context, error) => _errorUi(error),
            ),
          ),
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
