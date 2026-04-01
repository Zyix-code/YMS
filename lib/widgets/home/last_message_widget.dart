import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LastMessageWidget extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String myUid;
  final bool showHistory;
  final bool isDisabled;
  final VoidCallback onToggleHistory;

  const LastMessageWidget({
    super.key,
    required this.stream,
    required this.myUid,
    required this.showHistory,
    required this.isDisabled,
    required this.onToggleHistory,
  });

  String _asStr(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(
            child: ListTile(
              title: const Text(
                'Son mesaj',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Mesajlar yüklenemedi.\n${snap.error}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              title: Text(
                'Son mesaj',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Yükleniyor…',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }

        String lastText = '';
        String lastWho = '';

        final docs = snap.data?.docs ?? const [];
        if (docs.isNotEmpty) {
          final d = docs.first.data();
          lastText = _asStr(d['message']);
          final fromUid = _asStr(d['fromUid']);
          final isMe = fromUid == myUid;
          lastWho = isMe ? 'Sen' : 'Partner';
        }

        final shown = lastText.isNotEmpty ? '$lastWho: $lastText' : '';

        return Card(
          child: ListTile(
            title: const Text(
              'Son mesaj',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              shown.isNotEmpty ? shown : 'Henüz bir mesaj yok 💗',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: isDisabled ? null : onToggleHistory,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(18),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withAlpha(60)),
                ),
                child: Icon(
                  showHistory ? Icons.remove_rounded : Icons.add_rounded,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
