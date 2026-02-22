import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const String _base = 'https://yms-push.selcuksahin158.workers.dev';

  static const String _apiKey =
      'sizinsecretkeyiniz';
  Future<bool> sendToUid({
    required String toUid,
    required String title,
    required String body,
  }) async {
    final t = title.trim();
    final b = body.trim();
    final u = toUid.trim();

    if (u.isEmpty) return false;
    if (t.isEmpty && b.isEmpty) return false;

    try {
      final uri = Uri.parse('$_base/push');

      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _apiKey,
            },
            body: jsonEncode({
              'toUid': u,
              'title': t.isEmpty ? 'YMS 💗' : t,
              'body': b,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final text = res.body.trim();
      if (text.isEmpty) return true;

      try {
        final j = jsonDecode(text);
        if (j is Map) {
          final ok = j['ok'];
          if (ok == true) return true;
          if (ok is String && ok.toLowerCase() == 'true') return true;
        }
      } catch (_) {}

      return text.toLowerCase() == 'ok';
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
