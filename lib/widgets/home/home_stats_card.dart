import 'package:flutter/material.dart';

class HomeStatsCard extends StatelessWidget {
  final String title;
  final String gender;
  final int dailyHearts;
  final int dailyMsgs;
  final int totalHearts;
  final int totalMsgs;
  final bool winner;

  const HomeStatsCard({
    super.key,
    required this.title,
    required this.gender,
    required this.dailyHearts,
    required this.dailyMsgs,
    required this.totalHearts,
    required this.totalMsgs,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    final badge = winner ? ' 🏆' : '';
    final isFem = gender == 'kadin';
    final themeColor = isFem ? Colors.pink : Colors.blue;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor.withAlpha(20),
              Theme.of(context).cardColor,
            ],
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFem ? Icons.woman_rounded : Icons.man_rounded,
                  size: 22,
                  color: themeColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '$title$badge',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('💗 Kalp: $dailyHearts',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            _TotalLine(total: totalHearts),
            const SizedBox(height: 6),
            Text('💬 Mesaj: $dailyMsgs',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            _TotalLine(total: totalMsgs),
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final int total;

  const _TotalLine({required this.total});

  @override
  Widget build(BuildContext context) {
    return Text(
      ' (Toplam: $total)',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
      ),
    );
  }
}

