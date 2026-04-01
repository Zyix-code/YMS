import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class MoodOption {
  final String key;
  final String emoji;
  final String label;

  const MoodOption({
    required this.key,
    required this.emoji,
    required this.label,
  });
}

const List<MoodOption> kMoodOptions = [
  MoodOption(key: 'happy', emoji: '😊', label: 'Mutlu'),
  MoodOption(key: 'tired', emoji: '😴', label: 'Yorgun'),
  MoodOption(key: 'miss', emoji: '🥹', label: 'Özlemiş'),
  MoodOption(key: 'angry', emoji: '😠', label: 'Kızgın'),
  MoodOption(key: 'sad', emoji: '😔', label: 'Üzgün'),
  MoodOption(key: 'excited', emoji: '🤩', label: 'Heyecanlı'),
  MoodOption(key: 'love', emoji: '😍', label: 'Aşık'),
  MoodOption(key: 'worried', emoji: '😟', label: 'Endişeli'),
  MoodOption(key: 'calm', emoji: '😌', label: 'Sakin'),
];

class MoodCard extends StatelessWidget {
  final String title;
  final String? selectedMoodKey;
  final String? selectedMoodEmoji;
  final String? selectedMoodLabel;
  final Timestamp? updatedAt;
  final bool editable;
  final ValueChanged<MoodOption>? onMoodTap;

  const MoodCard({
    super.key,
    required this.title,
    required this.selectedMoodKey,
    required this.selectedMoodEmoji,
    required this.selectedMoodLabel,
    required this.updatedAt,
    required this.editable,
    this.onMoodTap,
  });

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';

    final now = DateTime.now();
    final dt = ts.toDate();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return '${diff.inSeconds} sn önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moodText = (selectedMoodLabel ?? '').trim().isEmpty
        ? 'Henüz seçilmedi'
        : selectedMoodLabel!.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: Stream<int>.periodic(
                const Duration(seconds: 1),
                (x) => x,
              ),
              builder: (context, _) {
                final agoText = _timeAgo(updatedAt);

                return Row(
                  children: [
                    Text(
                      selectedMoodEmoji ?? '🙂',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        agoText.isEmpty ? moodText : '$moodText • $agoText',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withAlpha(220),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kMoodOptions.map((mood) {
                final isSelected = selectedMoodKey == mood.key;

                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: editable && onMoodTap != null
                      ? () => onMoodTap!(mood)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withAlpha(30)
                          : (isDark
                              ? Colors.white.withAlpha(8)
                              : Colors.black.withAlpha(4)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Theme.of(context).dividerColor.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mood.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mood.label,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? AppTheme.primary : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
