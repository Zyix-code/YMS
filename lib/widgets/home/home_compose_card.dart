import 'package:flutter/material.dart';

class HomeComposeCard extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSend;

  const HomeComposeCard({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled && onSend != null ? (_) => onSend!() : null,
                decoration: const InputDecoration(
                  labelText: 'Mesaj yaz',
                  hintText: 'Kısa bir şey yaz…',
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: enabled ? onSend : null,
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
