import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._();

  static const _kUserId = 'yms_user_id';
  static const _kLastSeenInteractionId = 'yms_last_seen_interaction_id';
  static const _kLastNotifiedIncomingMs = 'last_notified_incoming_ms';

  static Future<void> setUserId(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUserId, uid);
  }

  static Future<String?> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUserId);
  }

  static Future<String> getOrCreateUserId() async {
    final sp = await SharedPreferences.getInstance();
    final existing = sp.getString(_kUserId);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final rnd = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String gen(int n) =>
        List.generate(n, (_) => chars[rnd.nextInt(chars.length)]).join();

    final uid = 'web_${gen(20)}';
    await sp.setString(_kUserId, uid);
    return uid;
  }

  static Future<void> setLastSeenInteractionId(String id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastSeenInteractionId, id);
  }

  static Future<String?> getLastSeenInteractionId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLastSeenInteractionId);
  }

  static Future<int?> getLastNotifiedIncomingMs() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kLastNotifiedIncomingMs);
  }

  static Future<void> setLastNotifiedIncomingMs(int ms) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kLastNotifiedIncomingMs, ms);
  }
}
