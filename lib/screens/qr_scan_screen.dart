import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  String? _clip;
  @override
  void initState() {
    super.initState();
    _readClipboard();
  }

  Future<void> _readClipboard() async {
    final d = await Clipboard.getData('text/plain');
    setState(() => _clip = d?.text?.trim());
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    return Scaffold(
      appBar: AppBar(title: const Text('QR / Kopyadan Al')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'QR tarama paketi kaldırıldı (derleme hatası yapıyordu).\n'
                  'Partnerin kodunu kopyalayıp buradan yapıştırabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (clip == null || clip.isEmpty)
                  const Text('Panoda kod yok.')
                else
                  Text('Panodaki: $clip',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _readClipboard,
                        child: const Text('Panoyu Yenile'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (clip == null || clip.isEmpty)
                            ? null
                            : () => Navigator.pop(context, clip),
                        child: const Text('Kodu Kullan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
