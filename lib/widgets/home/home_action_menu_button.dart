import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeActionMenuButton extends StatelessWidget {
  final bool notifEnabled;
  final bool unpairing;
  final ValueChanged<String> onSelected;

  const HomeActionMenuButton({
    super.key,
    required this.notifEnabled,
    required this.unpairing,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'Menü',
      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.primary),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'gps',
            child: Row(
              children: [
                Icon(Icons.my_location_rounded, color: AppTheme.primary),
                SizedBox(width: 10),
                Text('GPS Güncelle',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'notif',
            enabled: !unpairing,
            child: Row(
              children: [
                Icon(
                  notifEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Bildirimleri Aç',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          if (isDark)
            const PopupMenuItem<String>(
              value: 'theme_light',
              child: Row(
                children: [
                  Icon(Icons.light_mode_rounded, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Text('Açık Tema',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            const PopupMenuItem<String>(
              value: 'theme_dark',
              child: Row(
                children: [
                  Icon(Icons.dark_mode_rounded, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Text('Koyu Tema',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'unpair',
            enabled: !unpairing,
            child: const Row(
              children: [
                Icon(Icons.link_off_rounded, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  'Eşleşmeyi Kaldır',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
