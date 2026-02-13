import 'dart:math';

class PairingService {
  static final _rand = Random.secure();
  static const String _prefix = 'YMS-';
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateCode({int length = 6}) {
    final b = StringBuffer(_prefix);
    for (int i = 0; i < length; i++) {
      b.write(_chars[_rand.nextInt(_chars.length)]);
    }
    return b.toString();
  }

  static String normalize(String input) {
    var s = input.trim().toUpperCase();
    s = s.replaceAll(' ', '');
    if (s.startsWith('YMS')) {
      s = s.replaceAll('YMS', '');
      s = s.replaceAll('-', '');
    }
    if (s.startsWith('-')) s = s.substring(1);
    return 'YMS-$s';
  }

  static bool isValid(String normalized) {
    final s = normalized.trim().toUpperCase();
    if (!s.startsWith(_prefix)) return false;
    final body = s.substring(_prefix.length);
    if (body.length < 4) return false;
    return RegExp(r'^[A-Z0-9]+$').hasMatch(body);
  }
}
