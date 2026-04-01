import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeHeaderCard extends StatelessWidget {
  final String myName;
  final String partnerName;
  final String myGender;
  final String partnerGender;
  final String kmText;
  final int days;
  final bool myIsWinner;
  final bool partnerIsWinner;
  final int myStreak;
  final int partnerStreak;
  final int myTotalWins;
  final int partnerTotalWins;
  final bool didTieYesterday;

  const HomeHeaderCard({
    super.key,
    required this.myName,
    required this.partnerName,
    required this.myGender,
    required this.partnerGender,
    required this.kmText,
    required this.days,
    required this.myIsWinner,
    required this.partnerIsWinner,
    required this.myStreak,
    required this.partnerStreak,
    required this.myTotalWins,
    required this.partnerTotalWins,
    required this.didTieYesterday,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _personCard(
          context: context,
          label: 'Sen',
          name: myName,
          gender: myGender,
          isWinnerToday: myIsWinner,
          streak: myStreak,
          totalWins: myTotalWins,
        ),
        if (didTieYesterday) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withAlpha(35)),
            ),
            child: Text(
              '🤝 Berabere bitti',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _personCard(
          context: context,
          label: 'Partner',
          name: partnerName,
          gender: partnerGender,
          isWinnerToday: partnerIsWinner,
          streak: partnerStreak,
          totalWins: partnerTotalWins,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _pill(context, 'Mesafe', '$kmText km')),
            const SizedBox(width: 10),
            Expanded(child: _pill(context, 'Birlikte', '$days gün')),
          ],
        ),
      ],
    );
  }

  Widget _personCard({
    required BuildContext context,
    required String label,
    required String name,
    required String gender,
    required bool isWinnerToday,
    required int streak,
    required int totalWins,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isFem = gender == 'kadin';
    final themeColor = isFem ? Colors.pink : Colors.blue;
    final icon = isFem ? Icons.woman_rounded : Icons.man_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: themeColor.withAlpha(40),
                radius: 18,
                child: Icon(icon, color: themeColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(210),
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(text: name.isEmpty ? '---' : name),
                    ],
                  ),
                ),
              ),
              if (isWinnerToday) ...[
                const SizedBox(width: 10),
                _crownBadge(context, streak),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 16,
                color: themeColor.withAlpha(230),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Toplam Kazanma: $totalWins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crownBadge(BuildContext context, int streak) {
    final cs = Theme.of(context).colorScheme;
    final suffix = streak > 0 ? ' x$streak' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Text(
        '🏆$suffix',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withAlpha(35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withAlpha(210),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
