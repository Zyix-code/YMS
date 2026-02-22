import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  StreamSubscription<RemoteMessage>? _sub;
  StreamSubscription<String>? _tokenSub;

  static const String vapidKey =
      'BMto9kGa1iEVQ-uCNA7h-YarCAIGD0obZ4To583PLsEMEdKxjJ7oYgkPnYd-9ZlmVy_z_3jU9RrnG6y7ZPe-v2s';

  static const String workerBaseUrl =
      'https://yms-push.selcuksahin158.workers.dev';

  static const String workerApiKey =
      'Sizinsecretkeyiniz';

  String? _lastRegisteredToken;
  String? _lastRegisteredUid;

  String? _lastShownKey;
  int _lastShownAtMs = 0;

  bool get hasPermission {
    try {
      return html.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  Future<void> initAndAutoRegister({required String uid}) async {
    _lastRegisteredUid = uid;

    await _sub?.cancel();
    _sub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      if (msg.notification != null) return;

      final title = (msg.data['title']?.toString() ?? 'YMS 💗').trim();
      final body = (msg.data['body']?.toString() ??
              msg.data['message']?.toString() ??
              '')
          .trim();

      if (body.isEmpty) return;
      await showLocal(title: title, body: body);
    });

    await _tokenSub?.cancel();
    _tokenSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      final u = _lastRegisteredUid;
      if (u == null) return;
      await _registerToWorkerIfNeeded(uid: u, token: newToken);
    });

    await _autoRegisterIfPermitted(uid);
  }

  Future<bool> requestPermissionAndRegisterToken({required String uid}) async {
    _lastRegisteredUid = uid;

    final perm = await html.Notification.requestPermission();
    if (perm != 'granted') return false;

    return _autoRegisterIfPermitted(uid);
  }

  Future<bool> _autoRegisterIfPermitted(String uid) async {
    if (!hasPermission) return false;

    try {
      final token =
          await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      if (token == null || token.isEmpty) return false;

      return _registerToWorkerIfNeeded(uid: uid, token: token);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _registerToWorkerIfNeeded({
    required String uid,
    required String token,
  }) async {
    if (_lastRegisteredUid == uid && _lastRegisteredToken == token) return true;

    final ok = await _registerToWorker(uid: uid, token: token);
    if (ok) {
      _lastRegisteredUid = uid;
      _lastRegisteredToken = token;
    }
    return ok;
  }

  Future<bool> _registerToWorker({
    required String uid,
    required String token,
  }) async {
    final uri = Uri.parse('$workerBaseUrl/register');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': workerApiKey,
      },
      body: jsonEncode({'uid': uid, 'token': token}),
    );

    if (res.statusCode != 200) return false;

    try {
      final j = jsonDecode(res.body);
      return j is Map && j['ok'] == true;
    } catch (_) {
      return res.body.trim() == 'ok';
    }
  }

  Future<void> showLocal({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!hasPermission) return;

    final key = '${title.trim()}|${body.trim()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_lastShownKey == key && (now - _lastShownAtMs) < 2500) {
      return;
    }
    _lastShownKey = key;
    _lastShownAtMs = now;

    html.Notification(title, body: body);
  }

  void dispose() {
    _sub?.cancel();
    _tokenSub?.cancel();
  }
}
