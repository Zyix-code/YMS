import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatHistoryWidget extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String myUid;
  final String myGender;
  final String partnerGender;

  const ChatHistoryWidget({
    super.key,
    required this.stream,
    required this.myUid,
    required this.myGender,
    required this.partnerGender,
  });

  String _asStr(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Hata: ${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Text(
            'Mesaj yok.',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(
            color: Theme.of(context).dividerColor.withAlpha(30),
            height: 1,
          ),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final msg = _asStr(d['message']);
            final type = _asStr(d['type']);
            final fromUid = _asStr(d['fromUid']);

            final isMe = fromUid == myUid;
            final who = isMe ? 'Sen' : 'Partner';

            final senderGender = isMe ? myGender : partnerGender;
            final isFem = senderGender == 'kadin';
            final genderIcon = isFem ? Icons.woman_rounded : Icons.man_rounded;
            final genderColor = isFem ? Colors.pink : Colors.blue;

            final isHeart = type == 'heart';
            final typeIcon =
                isHeart ? Icons.favorite_rounded : Icons.chat_bubble_rounded;
            final typeColor = isHeart ? Colors.redAccent : Colors.blueGrey;

            final bubbleColor = isMe
                ? (isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(4))
                : genderColor.withAlpha(isDark ? 28 : 15);

            final bubbleTextColor = isHeart
                ? (isDark ? Colors.red.shade200 : Colors.red.shade900)
                : cs.onSurface;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: genderColor.withAlpha(30),
                    child: Icon(
                      genderIcon,
                      color: genderColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              who,
                              style: TextStyle(
                                color: genderColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              typeIcon,
                              size: 12,
                              color: typeColor.withAlpha(200),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            border: Border.all(
                              color:
                                  Theme.of(context).dividerColor.withAlpha(30),
                            ),
                          ),
                          child: Text(
                            msg.isEmpty
                                ? (isHeart ? 'Sana bir kalp gönderdi!' : '...')
                                : msg,
                            style: TextStyle(
                              color: bubbleTextColor,
                              fontWeight:
                                  isHeart ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
