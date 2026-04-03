import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrustedTamperSignal {
  final String reason;
  final int deviceDeltaMs;
  final int trustedDeltaMs;
  final bool isStrong;

  const TrustedTamperSignal({
    required this.reason,
    required this.deviceDeltaMs,
    required this.trustedDeltaMs,
    required this.isStrong,
  });

  String get signature => '$reason|$deviceDeltaMs|$trustedDeltaMs';
}

class TrustedTimeService {
  TrustedTimeService._();
  static final TrustedTimeService instance = TrustedTimeService._();

  static const String _kLastTrustedNowMs = 'yms_last_trusted_now_ms';
  static const String _kLastDeviceNowMs = 'yms_last_device_now_ms';
  static const String _kLastTimezoneOffsetMinutes =
      'yms_last_timezone_offset_minutes';

  DateTime? _baseServerNow;
  final Stopwatch _serverStopwatch = Stopwatch();
  final Stopwatch _deviceStopwatch = Stopwatch();

  Future<DateTime?>? _syncing;
  int _lastWallClockMs = 0;
  int _lastMonotonicMs = 0;
  int _lastTamperHandledMonoMs = -600000;
  bool _sessionStarted = false;
  int? _lastTimezoneOffsetMinutes;

  void startSession() {
    if (_sessionStarted) return;
    _sessionStarted = true;
    _deviceStopwatch.start();
    _lastWallClockMs = DateTime.now().millisecondsSinceEpoch;
    _lastMonotonicMs = _deviceStopwatch.elapsedMilliseconds;
    _lastTimezoneOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
  }

  DateTime? now() {
    final base = _baseServerNow;
    if (base == null) return null;
    return base.add(_serverStopwatch.elapsed);
  }

  Future<DateTime?> sync({bool force = false}) {
    startSession();

    final cached = now();
    if (!force &&
        cached != null &&
        _serverStopwatch.isRunning &&
        _serverStopwatch.elapsed < const Duration(seconds: 20)) {
      return Future.value(cached);
    }

    final running = _syncing;
    if (running != null) return running;

    final future = _syncImpl().whenComplete(() => _syncing = null);
    _syncing = future;
    return future;
  }

  Future<DateTime> nowOrSync({bool force = false}) async {
    final cached = now();
    if (cached != null && !force) return cached;
    final synced = await sync(force: force);
    return synced ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<DateTime?> _syncImpl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return now();

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      await ref.set(
        {'clockSyncAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      final snap = await ref.get(const GetOptions(source: Source.server));
      final ts = snap.data()?['clockSyncAt'];
      if (ts is Timestamp) {
        _baseServerNow = ts.toDate();
        _serverStopwatch
          ..reset()
          ..start();
      }
    } catch (_) {}

    return now();
  }

  DateTime toTR(DateTime dt) => dt.toUtc().add(const Duration(hours: 3));

  int hourTR(DateTime dt) => toTR(dt).hour;

  String dayKeyTR(DateTime dt) {
    final tr = toTR(dt);
    return '${tr.year}-${tr.month.toString().padLeft(2, '0')}-${tr.day.toString().padLeft(2, '0')}';
  }

  Duration penaltyDurationForViolation(int violationNumber) {
    if (violationNumber <= 1) return const Duration(hours: 24);
    if (violationNumber == 2) return const Duration(hours: 48);
    return const Duration(hours: 72);
  }

  Future<TrustedTamperSignal?> persistTrustedSnapshotAndDetectTamper(
    DateTime trustedNow, {
    Duration tolerance = const Duration(minutes: 2),
  }) async {
    final nowDeviceMs = DateTime.now().millisecondsSinceEpoch;
    final nowTrustedMs = trustedNow.millisecondsSinceEpoch;
    final currentOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    try {
      final sp = await SharedPreferences.getInstance();
      final lastTrustedMs = sp.getInt(_kLastTrustedNowMs);
      final lastDeviceMs = sp.getInt(_kLastDeviceNowMs);
      final lastOffsetMinutes =
          sp.getInt(_kLastTimezoneOffsetMinutes) ?? currentOffsetMinutes;

      TrustedTamperSignal? detected;
      if (lastTrustedMs != null &&
          lastTrustedMs > 0 &&
          lastDeviceMs != null &&
          lastDeviceMs > 0) {
        final trustedDelta = nowTrustedMs - lastTrustedMs;
        final deviceDelta = nowDeviceMs - lastDeviceMs;
        final drift = (deviceDelta - trustedDelta).abs();
        final timezoneChanged = lastOffsetMinutes != currentOffsetMinutes;

        if (!timezoneChanged &&
            trustedDelta > 0 &&
            drift > tolerance.inMilliseconds) {
          detected = TrustedTamperSignal(
            reason: 'persisted_clock_jump',
            deviceDeltaMs: deviceDelta,
            trustedDeltaMs: trustedDelta,
            isStrong: false,
          );
        }
      }

      await sp.setInt(_kLastTrustedNowMs, nowTrustedMs);
      await sp.setInt(_kLastDeviceNowMs, nowDeviceMs);
      await sp.setInt(_kLastTimezoneOffsetMinutes, currentOffsetMinutes);
      _lastTimezoneOffsetMinutes = currentOffsetMinutes;
      return detected;
    } catch (_) {
      return null;
    }
  }

  TrustedTamperSignal? detectLiveClockTamper({
    Duration tolerance = const Duration(minutes: 2),
    Duration debounce = const Duration(seconds: 10),
  }) {
    startSession();

    final wallNowMs = DateTime.now().millisecondsSinceEpoch;
    final monoNowMs = _deviceStopwatch.elapsedMilliseconds;
    final currentOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    if (_lastTimezoneOffsetMinutes != null &&
        _lastTimezoneOffsetMinutes != currentOffsetMinutes) {
      _lastTimezoneOffsetMinutes = currentOffsetMinutes;
      _lastWallClockMs = wallNowMs;
      _lastMonotonicMs = monoNowMs;
      return null;
    }

    _lastTimezoneOffsetMinutes = currentOffsetMinutes;

    final wallDelta = wallNowMs - _lastWallClockMs;
    final monoDelta = monoNowMs - _lastMonotonicMs;
    final drift = (wallDelta - monoDelta).abs();

    _lastWallClockMs = wallNowMs;
    _lastMonotonicMs = monoNowMs;

    if (drift <= tolerance.inMilliseconds) return null;
    if (monoNowMs - _lastTamperHandledMonoMs < debounce.inMilliseconds) {
      return null;
    }

    _lastTamperHandledMonoMs = monoNowMs;
    return TrustedTamperSignal(
      reason: 'live_clock_jump',
      deviceDeltaMs: wallDelta,
      trustedDeltaMs: monoDelta,
      isStrong: true,
    );
  }
}
