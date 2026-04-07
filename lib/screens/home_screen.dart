// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_screen.dart';
import 'pairing_screen.dart';

import '../services/firestore_service.dart';
import '../services/love_messages_service.dart';
import '../services/notification_service.dart';
import '../services/pairing_service.dart';
import '../services/push_service.dart';
import '../services/trusted_time_service.dart';

import '../theme/theme_controller.dart';

import '../utils/app_error.dart';

import '../widgets/home/chat_history_widget.dart';
import '../widgets/home/flying_hearts_overlay.dart';
import '../widgets/home/home_action_menu_button.dart';
import '../widgets/home/home_compose_card.dart';
import '../widgets/home/home_header_card.dart';
import '../widgets/home/home_heart_button.dart';
import '../widgets/home/home_stats_card.dart';
import '../widgets/home/last_message_widget.dart';
import '../widgets/home/mood_card.dart';

enum LocationUpdateResult {
  updated,
  unchanged,
  serviceDisabled,
  permissionDenied,
  timeout,
  error,
}

class _BlockedSendException implements Exception {
  final DateTime until;
  final bool isPenalty;

  const _BlockedSendException({
    required this.until,
    required this.isPenalty,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _HomeBody(),
    JourneyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Aşk Paneli',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_motion),
            label: 'Yolculuk',
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String? _uid;
  bool _showHistory = false;
  bool _sending = false;
  bool _unpairing = false;
  bool _notifEnabled = false;
  bool _didNavigateToPairing = false;
  bool _heartTapLocked = false;
  bool _messageTapLocked = false;
  bool _clockTamperInFlight = false;
  bool _cooldownTickInFlight = false;
  String? _error;

  static const int cooldownSeconds = 300;
  static const String _kLastLocationLat = 'yms_last_location_lat';
  static const String _kLastLocationLng = 'yms_last_location_lng';

  static const double _minDistanceMeters = 200;
  static const Duration _clockDriftTolerance = Duration(minutes: 2);

  Timer? _cooldownTicker;
  final Stopwatch _snackStopwatch = Stopwatch();
  int _lastSnackAtMs = -5000;
  StreamSubscription<Position>? _positionSub;
  bool _locationStreamStarted = false;

  bool _hasSyncedInitialLocation = false;
  bool _isAutoLocationWriting = false;

  final TextEditingController _manual = TextEditingController();
  final Random _rand = Random();
  final List<HomeFlyingHeart> _hearts = [];
  int _nextHeartId = 1;
  final ValueNotifier<int> _cooldownNotifier = ValueNotifier<int>(0);
  final ValueNotifier<DateTime> _trustedNowNotifier = ValueNotifier<DateTime>(
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

  String? _lastSeenDayKey;
  bool _rolloverRunning = false;
  bool _didInitialAutoRollover = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _me$;
  String? _partnerUidCached;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _partner$;

  String? _interactionKey;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _chatAll$;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _incomingLastAll$;

  Future<void>? _rolloverGate;
  Position? _lastPosition;

  Timestamp? _cooldownUntilTs;
  Timestamp? _penaltyUntilTs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TrustedTimeService.instance.startSession();
    _snackStopwatch.start();
    _init();
    _startCooldownTicker();
    _refreshNotifState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTicker?.cancel();
    _positionSub?.cancel();
    _cooldownNotifier.dispose();
    _trustedNowNotifier.dispose();
    _manual.dispose();
    for (final h in _hearts) {
      h.controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    Future<void>(() async {
      await _syncTrustedNow(force: true);
      await _detectLiveClockTamper();
      final myUid = _uid;
      final partnerUid = _partnerUidCached;
      if (myUid != null && partnerUid != null) {
        await _ensureDailyRollOverIfNeeded(
            myUid: myUid, partnerUid: partnerUid);
      }
    });
  }

  Future<void> _init() async {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (!mounted) return;

    setState(() {
      _uid = id;
      _me$ = id != null
          ? FirestoreService.instance.users.doc(id).snapshots()
          : null;
    });

    if (id == null) return;

    await TrustedTimeService.instance.bootstrap();
    await _syncTrustedNow(force: true);
    final trustedNow = _trustedNow();
    if (trustedNow != null) {
      _lastSeenDayKey = _dayKeyFromTrusted(trustedNow);
    }

    Future<void>(() async {
      await _updateLocationOnce(
        silent: true,
        forceRemoteWrite: true,
      );
      await _startAutoLocationUpdates();
    });
  }

  Future<DateTime?> _syncTrustedNow({bool force = false}) async {
    final trustedNow = await TrustedTimeService.instance.sync(force: force);
    if (trustedNow == null) return _trustedNow();

    final signal =
        await TrustedTimeService.instance.persistTrustedSnapshotAndDetectTamper(
      trustedNow,
      tolerance: _clockDriftTolerance,
    );
    if (signal != null) {
      await _registerClockTamper(signal: signal, trustedNow: trustedNow);
    }

    final today = _dayKeyFromTrusted(trustedNow);
    if (_trustedNowNotifier.value != trustedNow) {
      _trustedNowNotifier.value = trustedNow;
    }
    _lastSeenDayKey ??= today;
    return trustedNow;
  }

  DateTime? _trustedNow() => TrustedTimeService.instance.now();

  String _dayKeyFromTrusted(DateTime dt) =>
      TrustedTimeService.instance.dayKeyTR(dt);

  Future<void> _detectLiveClockTamper() async {
    final signal = TrustedTimeService.instance.detectLiveClockTamper(
      tolerance: _clockDriftTolerance,
    );
    if (signal == null) return;

    final trustedNow = await TrustedTimeService.instance.nowOrSync(force: true);
    await _registerClockTamper(signal: signal, trustedNow: trustedNow);
  }

  Future<void> _registerClockTamper({
    required TrustedTamperSignal signal,
    required DateTime trustedNow,
  }) async {
    final uid = _uid;
    if (uid == null || _clockTamperInFlight) return;

    _clockTamperInFlight = true;

    try {
      final userRef = FirestoreService.instance.users.doc(uid);
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final currentCount = _asInt(data['clockTamperCount']);

      DateTime? existingPenaltyUntil;
      final existingPenaltyTs = data['penaltyUntil'];
      if (existingPenaltyTs is Timestamp) {
        existingPenaltyUntil = existingPenaltyTs.toDate();
      }

      final lastSignature = _asStr(data['lastClockTamperSignature']);
      DateTime? lastTamperAt;
      final lastTamperTs = data['clockTamperedAt'];
      if (lastTamperTs is Timestamp) {
        lastTamperAt = lastTamperTs.toDate();
      }

      final isSameEvent = lastSignature == signal.signature &&
          lastTamperAt != null &&
          trustedNow.difference(lastTamperAt).inSeconds < 20;

      Map<String, dynamic> result;

      if (isSameEvent) {
        result = <String, dynamic>{
          'count': currentCount,
          'penaltyUntil': existingPenaltyUntil,
          'deduped': true,
          'penalized': false,
        };
      } else if (!signal.isStrong) {
        await userRef.set(
          {
            'clockTamperLastObservedReason': signal.reason,
            'clockTamperLastObservedDeviceDeltaMs': signal.deviceDeltaMs,
            'clockTamperLastObservedTrustedDeltaMs': signal.trustedDeltaMs,
          },
          SetOptions(merge: true),
        );

        result = <String, dynamic>{
          'count': currentCount,
          'penaltyUntil': existingPenaltyUntil,
          'deduped': false,
          'penalized': false,
        };
      } else {
        final nextCount = currentCount + 1;
        final penaltyDuration =
            TrustedTimeService.instance.penaltyDurationForViolation(nextCount);
        final penaltyBase = existingPenaltyUntil != null &&
                existingPenaltyUntil.isAfter(trustedNow)
            ? existingPenaltyUntil
            : trustedNow;
        final nextPenaltyUntil = penaltyBase.add(penaltyDuration);

        await userRef.set(
          {
            'clockTamperCount': nextCount,
            'clockTamperedAt': FieldValue.serverTimestamp(),
            'clockTamperReason': signal.reason,
            'lastClockTamperSignature': signal.signature,
            'lastClockTamperDeviceDeltaMs': signal.deviceDeltaMs,
            'lastClockTamperTrustedDeltaMs': signal.trustedDeltaMs,
            'penaltyUntil': Timestamp.fromDate(nextPenaltyUntil),
            'cooldownUntil': Timestamp.fromDate(nextPenaltyUntil),
          },
          SetOptions(merge: true),
        );

        result = <String, dynamic>{
          'count': nextCount,
          'penaltyUntil': nextPenaltyUntil,
          'deduped': false,
          'penalized': true,
        };
      }

      final count = _asInt(result['count']);
      final penaltyUntil = result['penaltyUntil'] as DateTime?;
      final deduped = result['deduped'] == true;
      final penalized = result['penalized'] == true;

      if (penaltyUntil != null && penalized) {
        _penaltyUntilTs = Timestamp.fromDate(penaltyUntil);
        _cooldownUntilTs = Timestamp.fromDate(penaltyUntil);
      }

      if (penaltyUntil != null && penalized && !deduped) {
        late final String levelText;
        if (count <= 1) {
          levelText = '1. ihlal • 24 saat';
        } else if (count == 2) {
          levelText = '2. ihlal • 48 saat';
        } else {
          levelText = '3. ihlal+ • 72 saat';
        }

        _setErrorIfChanged(
          '⛔ Saat değişikliği tespit edildi. $levelText ceza uygulandı.',
        );
      }
    } catch (_) {
    } finally {
      _clockTamperInFlight = false;
    }
  }

  Future<void> _startAutoLocationUpdates() async {
    if (_locationStreamStarted) return;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    _locationStreamStarted = true;

    await _positionSub?.cancel();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((pos) async {
      final uid = _uid;
      if (uid == null || _isAutoLocationWriting) return;

      _isAutoLocationWriting = true;

      try {
        Position? basePosition = _lastPosition;
        basePosition ??= await _loadLastSavedPosition();

        if (!_hasSyncedInitialLocation) {
          _lastPosition = pos;
          await _saveLastPosition(pos);
          await _writeLocationToFirestore(uid: uid, pos: pos);
          _hasSyncedInitialLocation = true;
          return;
        }

        if (basePosition != null) {
          final distance = Geolocator.distanceBetween(
            basePosition.latitude,
            basePosition.longitude,
            pos.latitude,
            pos.longitude,
          );

          if (distance < _minDistanceMeters) return;
        }

        _lastPosition = pos;
        await _saveLastPosition(pos);
        await _writeLocationToFirestore(uid: uid, pos: pos);
      } catch (_) {
      } finally {
        _isAutoLocationWriting = false;
      }
    });
  }

  String _pairId(String a, String b) {
    final xs = [a, b]..sort();
    return '${xs[0]}_${xs[1]}';
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _asStr(dynamic v) => (v ?? '').toString().trim();

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  void _setErrorIfChanged(String? next) {
    if (!mounted || _error == next) return;
    setState(() => _error = next);
  }

  Future<DateTime?> _getFreshTrustedNow({bool force = false}) async {
    final cached = _trustedNow();
    if (cached != null && !force) return cached;

    final synced = await _syncTrustedNow(force: force);
    if (synced != null) return synced;

    if (!force) {
      return _syncTrustedNow(force: true);
    }
    return _trustedNow();
  }

  Future<Position?> _loadLastSavedPosition() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final lat = sp.getDouble(_kLastLocationLat);
      final lng = sp.getDouble(_kLastLocationLng);
      if (lat == null || lng == null) return null;
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: _trustedNow() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastPosition(Position pos) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_kLastLocationLat, pos.latitude);
      await sp.setDouble(_kLastLocationLng, pos.longitude);
    } catch (_) {}
  }

  Future<void> _writeLocationToFirestore({
    required String uid,
    required Position pos,
  }) async {
    await FirestoreService.instance.users.doc(uid).set({
      'lastLocation': {
        'lat': pos.latitude,
        'lng': pos.longitude,
      },
      'lastLocationAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_cooldownTickInFlight) return;
      _cooldownTickInFlight = true;

      try {
        await _detectLiveClockTamper();

        final trustedNow = _trustedNow();
        if (trustedNow != null && _trustedNowNotifier.value != trustedNow) {
          _trustedNowNotifier.value = trustedNow;
        }

        final left = _cooldownLeft();
        if (_cooldownNotifier.value != left) {
          _cooldownNotifier.value = left;
        }

        final today =
            trustedNow != null ? _dayKeyFromTrusted(trustedNow) : null;
        final myUid = _uid;
        final partnerUid = _partnerUidCached;
        if (today != null &&
            myUid != null &&
            partnerUid != null &&
            _lastSeenDayKey != today &&
            !_rolloverRunning) {
          _lastSeenDayKey = today;
          _rolloverRunning = true;
          Future<void>(() async {
            try {
              await _ensureDailyRollOverIfNeeded(
                myUid: myUid,
                partnerUid: partnerUid,
              );
            } finally {
              _rolloverRunning = false;
            }
          });
        }
      } finally {
        _cooldownTickInFlight = false;
      }
    });
  }

  bool _isCoolingDown() {
    return _cooldownLeft() > 0;
  }

  Timestamp? _effectiveBlockUntil() {
    final cooldown = _cooldownUntilTs;
    final penalty = _penaltyUntilTs;

    if (cooldown == null) return penalty;
    if (penalty == null) return cooldown;

    return cooldown.toDate().isAfter(penalty.toDate()) ? cooldown : penalty;
  }

  int _cooldownLeft() {
    final trustedNow = _trustedNow();
    final blockUntil = _effectiveBlockUntil();

    if (trustedNow == null || blockUntil == null) return 0;

    final diff = blockUntil.toDate().difference(trustedNow).inSeconds;
    return diff > 0 ? diff : 0;
  }

  String _cooldownText() {
    final trustedNow = _trustedNow();
    final blockUntil = _effectiveBlockUntil();
    if (blockUntil != null && trustedNow == null) {
      return 'Süre hesaplanıyor…';
    }

    final left = _cooldownLeft();

    if (left <= 0) {
      return 'Hazır 💗 Gönderebilirsin.';
    }

    final effective = _effectiveBlockUntil();
    final isPenalty = _penaltyUntilTs != null &&
        effective != null &&
        _penaltyUntilTs!.toDate().isAtSameMomentAs(effective.toDate());

    final hours = left ~/ 3600;
    final minutes = (left % 3600) ~/ 60;
    final seconds = left % 60;

    if (hours > 0) {
      return isPenalty
          ? 'Ceza aktif ⛔ $hours sa $minutes dk $seconds sn sonra tekrar gönderebilirsin.'
          : 'Minik bir mola 💗 $hours sa $minutes dk $seconds sn sonra tekrar gönderebilirsin.';
    }

    if (minutes > 0) {
      return isPenalty
          ? 'Ceza aktif ⛔ $minutes dk $seconds sn sonra tekrar gönderebilirsin.'
          : 'Minik bir mola 💗 $minutes dk $seconds sn sonra tekrar gönderebilirsin.';
    }

    return isPenalty
        ? 'Ceza aktif ⛔ $seconds sn sonra tekrar gönderebilirsin.'
        : 'Minik bir mola 💗 $seconds sn sonra tekrar gönderebilirsin.';
  }

  void _showCooldownSnack() {
    final now = _snackStopwatch.elapsedMilliseconds;
    if (now - _lastSnackAtMs < 2000) return;
    _lastSnackAtMs = now;

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_cooldownText()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _refreshNotifState() {
    final next = NotificationService.instance.hasPermission;
    if (!mounted || _notifEnabled == next) return;
    setState(() => _notifEnabled = next);
  }

  Future<LocationUpdateResult> _updateLocationOnce({
    bool silent = false,
    bool forceRemoteWrite = false,
  }) async {
    final uid = _uid;
    if (uid == null) return LocationUpdateResult.error;

    try {
      if (mounted) {
        _setErrorIfChanged(null);
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent && mounted) {
          setState(() => _error = '📍 Konum servisleri kapalı.');
        }
        return LocationUpdateResult.serviceDisabled;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          _setErrorIfChanged(
            '🙈 Konum izni yok. İzin verirsen mesafeyi gösterebilirim.',
          );
        }
        return LocationUpdateResult.permissionDenied;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));

      Position? basePosition = _lastPosition;
      basePosition ??= await _loadLastSavedPosition();

      if (basePosition != null) {
        final distance = Geolocator.distanceBetween(
          basePosition.latitude,
          basePosition.longitude,
          pos.latitude,
          pos.longitude,
        );

        if (distance < _minDistanceMeters) {
          _lastPosition = pos;

          if (forceRemoteWrite) {
            await _saveLastPosition(pos);
            await _writeLocationToFirestore(uid: uid, pos: pos);
            _hasSyncedInitialLocation = true;

            if (mounted) {
              _setErrorIfChanged(null);
            }

            return LocationUpdateResult.updated;
          }

          return LocationUpdateResult.unchanged;
        }
      }

      _lastPosition = pos;
      await _saveLastPosition(pos);
      await _writeLocationToFirestore(uid: uid, pos: pos);
      _hasSyncedInitialLocation = true;

      if (mounted) {
        _setErrorIfChanged(null);
      }

      return LocationUpdateResult.updated;
    } on TimeoutException {
      if (!silent && mounted) {
        _setErrorIfChanged('⏳ Konum alınamadı. Birazdan tekrar dener misin?');
      }
      return LocationUpdateResult.timeout;
    } catch (e) {
      if (!silent && mounted) {
        _setErrorIfChanged(trError(e));
      }
      return LocationUpdateResult.error;
    }
  }

  double? _calcKm(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return null;
    final lat1 = (a['lat'] as num?)?.toDouble();
    final lng1 = (a['lng'] as num?)?.toDouble();
    final lat2 = (b['lat'] as num?)?.toDouble();
    final lng2 = (b['lng'] as num?)?.toDouble();

    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }

    final meters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return meters / 1000.0;
  }

  int _daysTogether(Timestamp? pairedAt) {
    if (pairedAt == null) return 0;
    final trustedNow =
        _trustedNow() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final start = pairedAt.toDate();
    final diff = trustedNow
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatAllStream({
    required String myUid,
    required String partnerUid,
    int limit = 200,
  }) {
    final pid = _pairId(myUid, partnerUid);
    return FirestoreService.instance.interactions
        .where('pairId', isEqualTo: pid)
        .orderBy('createdAtMs', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _incomingLastAllStream({
    required String myUid,
    required String partnerUid,
  }) {
    return _chatAllStream(myUid: myUid, partnerUid: partnerUid, limit: 1);
  }

  void _ensurePartnerAndInteractionStreams({
    required String myUid,
    required String partnerUid,
  }) {
    if (_unpairing) return;

    final trustedNow = _trustedNow();
    final dk = trustedNow != null ? _dayKeyFromTrusted(trustedNow) : '';
    final key = '$partnerUid|$dk';

    final shouldUpdatePartner =
        _partnerUidCached != partnerUid || _partner$ == null;

    final shouldUpdateInteractions = _interactionKey != key ||
        _chatAll$ == null ||
        _incomingLastAll$ == null;

    if (!shouldUpdatePartner && !shouldUpdateInteractions) {
      return;
    }

    if (shouldUpdatePartner) {
      _partnerUidCached = partnerUid;
      _partner$ = FirestoreService.instance.users.doc(partnerUid).snapshots();
    }

    if (shouldUpdateInteractions) {
      _interactionKey = key;
      _chatAll$ = _chatAllStream(myUid: myUid, partnerUid: partnerUid);
      _incomingLastAll$ =
          _incomingLastAllStream(myUid: myUid, partnerUid: partnerUid);
    }
  }

  Future<void> _ensureDailyRollOverIfNeeded({
    required String myUid,
    required String partnerUid,
  }) async {
    final running = _rolloverGate;
    if (running != null) return running;

    final trustedNow = await _getFreshTrustedNow();
    if (trustedNow == null) return;

    final f = _ensureDailyRollOverIfNeededImpl(
      myUid: myUid,
      partnerUid: partnerUid,
      trustedNow: trustedNow,
    ).whenComplete(() => _rolloverGate = null);

    _rolloverGate = f;
    return f;
  }

  bool _isIgnorableCommitRace(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('failed-precondition') ||
        s.contains('aborted') ||
        s.contains('already-exists');
  }

  void _queueSafeRefresh() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _ensureDailyRollOverIfNeededImpl({
    required String myUid,
    required String partnerUid,
    required DateTime trustedNow,
  }) async {
    final users = FirestoreService.instance.users;
    final db = FirestoreService.instance.db;
    final today = _dayKeyFromTrusted(trustedNow);
    final myRef = users.doc(myUid);
    final partnerRef = users.doc(partnerUid);

    try {
      final mySnap = await myRef.get();
      final partnerSnap = await partnerRef.get();

      final me = mySnap.data() ?? <String, dynamic>{};
      final partner = partnerSnap.data() ?? <String, dynamic>{};

      final currentKey = _asStr(me['dailyKey']);
      if (currentKey == today) {
        _lastSeenDayKey = today;
        return;
      }

      final batch = db.batch();

      if (currentKey.isEmpty) {
        batch.set(
          myRef,
          {
            'dailyKey': today,
            'dailyHearts': 0,
            'dailyMessages': 0,
          },
          SetOptions(merge: true),
        );
        await batch.commit();
        _lastSeenDayKey = today;
        return;
      }

      final myScore = _asInt(me['dailyHearts']) + _asInt(me['dailyMessages']);
      final pScore =
          _asInt(partner['dailyHearts']) + _asInt(partner['dailyMessages']);

      final myIsWinner = myScore > pScore;
      final pIsWinner = pScore > myScore;
      final didTie = myScore == pScore;

      final currentMyStreak = _asInt(me['winnerStreak']);
      final currentPartnerStreak = _asInt(partner['winnerStreak']);

      final nextMyStreak = didTie ? 0 : (myIsWinner ? currentMyStreak + 1 : 0);
      final nextPartnerStreak =
          didTie ? 0 : (pIsWinner ? currentPartnerStreak + 1 : 0);

      batch.set(
        myRef,
        {
          'lastResultDayKey': currentKey,
          'winnerToday': myIsWinner,
          'winnerStreak': nextMyStreak,
          'totalWins': myIsWinner
              ? (_asInt(me['totalWins']) + 1)
              : _asInt(me['totalWins']),
          'dailyKey': today,
          'dailyHearts': 0,
          'dailyMessages': 0,
        },
        SetOptions(merge: true),
      );

      batch.set(
        partnerRef,
        {
          'lastResultDayKey': currentKey,
          'winnerToday': pIsWinner,
          'winnerStreak': nextPartnerStreak,
          'totalWins': pIsWinner
              ? (_asInt(partner['totalWins']) + 1)
              : _asInt(partner['totalWins']),
          'dailyKey': today,
          'dailyHearts': 0,
          'dailyMessages': 0,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      _lastSeenDayKey = today;
    } catch (e) {
      if (!_isIgnorableCommitRace(e)) rethrow;
    }
  }

  void _spawnHearts() {
    if (_hearts.length > 20) return;
    final newHearts = <HomeFlyingHeart>[];

    for (int i = 0; i < 10; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 900 + _rand.nextInt(500)),
      );

      final heart = HomeFlyingHeart(
        id: _nextHeartId++,
        x: 0.20 + _rand.nextDouble() * 0.60,
        controller: controller,
      );

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller.dispose();
          if (mounted) {
            setState(() => _hearts.removeWhere((x) => x.id == heart.id));
          }
        }
      });

      newHearts.add(heart);
      controller.forward();
    }

    setState(() {
      _hearts.addAll(newHearts);
    });
  }

  Future<void> _setMood({required MoodOption mood}) async {
    final myUid = _uid;
    if (myUid == null || _unpairing) return;

    try {
      await FirestoreService.instance.users.doc(myUid).set({
        'mood': {
          'key': mood.key,
          'emoji': mood.emoji,
          'label': mood.label,
        },
        'moodUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _setErrorIfChanged(trError(e));
    }
  }

  Future<void> _sendHeart({
    required Map<String, dynamic> me,
    required Map<String, dynamic> partner,
    required String partnerUid,
  }) async {
    if (_heartTapLocked || _sending || _unpairing) return;

    _heartTapLocked = true;

    try {
      final partnerFirst = _asStr(partner['firstName']);
      final name = partnerFirst.isEmpty ? 'Aşkım' : partnerFirst;
      final msg = await LoveMessages.randomFor(name);

      await _sendInteraction(
        me: me,
        partnerUid: partnerUid,
        type: 'heart',
        message: msg,
      );
    } finally {
      _heartTapLocked = false;
    }
  }

  Future<void> _sendManual({
    required Map<String, dynamic> me,
    required Map<String, dynamic> partner,
    required String partnerUid,
  }) async {
    if (_messageTapLocked || _sending || _unpairing) return;

    final text = _manual.text.trim();
    if (text.isEmpty) return;

    if (_isCoolingDown()) {
      _showCooldownSnack();
      return;
    }

    _messageTapLocked = true;

    try {
      _manual.clear();

      await _sendInteraction(
        me: me,
        partnerUid: partnerUid,
        type: 'message',
        message: text,
      );
    } finally {
      _messageTapLocked = false;
    }
  }

  Future<void> _sendInteraction({
    required Map<String, dynamic> me,
    required String partnerUid,
    required String type,
    required String message,
  }) async {
    final myUid = _uid;
    if (myUid == null || _unpairing) return;

    if (_isCoolingDown()) {
      _showCooldownSnack();
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _detectLiveClockTamper();

      final trustedNow = await _getFreshTrustedNow();
      if (trustedNow == null) {
        throw Exception('Sunucu saati doğrulanamadı.');
      }

      final users = FirestoreService.instance.users;
      final meRef = users.doc(myUid);
      final partnerRef = users.doc(partnerUid);
      final interactions = FirestoreService.instance.interactions;
      final pid = _pairId(myUid, partnerUid);
      final today = _dayKeyFromTrusted(trustedNow);
      final cooldownUntil = Timestamp.fromDate(
          trustedNow.add(const Duration(seconds: cooldownSeconds)));

      if (_isCoolingDown()) {
        _showCooldownSnack();
        return;
      }

      final mySnap = await meRef.get();
      final partnerSnap = await partnerRef.get();

      final myData = mySnap.data() ?? <String, dynamic>{};
      final partnerData = partnerSnap.data() ?? <String, dynamic>{};

      final penaltyTs = myData['penaltyUntil'];
      if (penaltyTs is Timestamp && penaltyTs.toDate().isAfter(trustedNow)) {
        throw _BlockedSendException(
          until: penaltyTs.toDate(),
          isPenalty: true,
        );
      }

      final currentCooldownTs = myData['cooldownUntil'];
      if (currentCooldownTs is Timestamp &&
          currentCooldownTs.toDate().isAfter(trustedNow)) {
        throw _BlockedSendException(
          until: currentCooldownTs.toDate(),
          isPenalty: false,
        );
      }

      final batch = FirestoreService.instance.db.batch();
      final currentKey = _asStr(myData['dailyKey']);
      if (currentKey != today) {
        if (currentKey.isEmpty) {
          batch.set(meRef, {
            'dailyKey': today,
            'dailyHearts': 0,
            'dailyMessages': 0,
          }, SetOptions(merge: true));
        } else {
          final myScore =
              _asInt(myData['dailyHearts']) + _asInt(myData['dailyMessages']);
          final pScore = _asInt(partnerData['dailyHearts']) +
              _asInt(partnerData['dailyMessages']);

          final myIsWinner = myScore > pScore;
          final pIsWinner = pScore > myScore;
          final didTie = myScore == pScore;

          final currentMyStreak = _asInt(myData['winnerStreak']);
          final currentPartnerStreak = _asInt(partnerData['winnerStreak']);

          final nextMyStreak =
              didTie ? 0 : (myIsWinner ? currentMyStreak + 1 : 0);
          final nextPartnerStreak =
              didTie ? 0 : (pIsWinner ? currentPartnerStreak + 1 : 0);

          batch.set(meRef, {
            'lastResultDayKey': currentKey,
            'winnerToday': myIsWinner,
            'winnerStreak': nextMyStreak,
            'totalWins': myIsWinner
                ? (_asInt(myData['totalWins']) + 1)
                : _asInt(myData['totalWins']),
            'dailyKey': today,
            'dailyHearts': 0,
            'dailyMessages': 0,
          }, SetOptions(merge: true));

          batch.set(partnerRef, {
            'lastResultDayKey': currentKey,
            'winnerToday': pIsWinner,
            'winnerStreak': nextPartnerStreak,
            'totalWins': pIsWinner
                ? (_asInt(partnerData['totalWins']) + 1)
                : _asInt(partnerData['totalWins']),
            'dailyKey': today,
            'dailyHearts': 0,
            'dailyMessages': 0,
          }, SetOptions(merge: true));
        }
      }

      batch.set(meRef, {
        'dailyKey': today,
        if (type == 'heart') 'dailyHearts': FieldValue.increment(1),
        if (type == 'message') 'dailyMessages': FieldValue.increment(1),
        if (type == 'heart') 'totalHearts': FieldValue.increment(1),
        if (type == 'message') 'totalMessages': FieldValue.increment(1),
        'cooldownUntil': cooldownUntil,
        'lastTrustedInteractionAt': Timestamp.fromDate(trustedNow),
      }, SetOptions(merge: true));

      batch.set(interactions.doc(), {
        'pairId': pid,
        'dayKey': today,
        'createdAtMs': trustedNow.millisecondsSinceEpoch,
        'type': type,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'fromUid': myUid,
        'toUid': partnerUid,
        'members': [myUid, partnerUid],
      });

      await batch.commit();

      _cooldownUntilTs = cooldownUntil;
      _cooldownNotifier.value = _cooldownLeft();
      _lastSeenDayKey = today;

      final senderFirst = _asStr(me['firstName']);
      final pushTitle = senderFirst.isEmpty ? 'YMS 💗' : '$senderFirst 💗';
      final pushBody =
          message.isNotEmpty ? message : 'Sana bir şey gönderdi 💗';

      await PushService.instance.sendToUid(
        toUid: partnerUid,
        title: pushTitle,
        body: pushBody,
      );

      _spawnHearts();
    } on _BlockedSendException catch (e) {
      final untilTs = Timestamp.fromDate(e.until);
      if (e.isPenalty) {
        _penaltyUntilTs = untilTs;
      } else {
        _cooldownUntilTs = untilTs;
      }
      _cooldownNotifier.value = _cooldownLeft();
      _showCooldownSnack();
    } catch (e) {
      _setErrorIfChanged(trError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _unpair({
    required String myUid,
    required String partnerUid,
  }) async {
    if (_unpairing) return;

    setState(() {
      _error = null;
      _unpairing = true;
      _showHistory = false;
    });

    final db = FirestoreService.instance.db;
    final users = FirestoreService.instance.users;
    final pairCodes = db.collection('pairCodes');
    final interactions = FirestoreService.instance.interactions;
    final pid = _pairId(myUid, partnerUid);

    final newMyCode = PairingService.generateCode(length: 6);
    final newPartnerCode = PairingService.generateCode(length: 6);

    try {
      final mySnap = await users.doc(myUid).get();
      final pSnap = await users.doc(partnerUid).get();
      final myData = mySnap.data() ?? {};
      final pData = pSnap.data() ?? {};

      final oldMyCode = _asStr(myData['pairCode']);
      final oldPartnerCode = _asStr(pData['pairCode']);

      while (true) {
        final q =
            await interactions.where('pairId', isEqualTo: pid).limit(450).get();
        if (q.docs.isEmpty) break;

        final b = db.batch();
        for (final d in q.docs) {
          b.delete(d.reference);
        }
        await b.commit();
      }

      Future<void> deactivateCode(String code) async {
        if (code.isEmpty) return;
        final ref = pairCodes.doc(code);
        final snap = await ref.get();
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final ownerUid = _asStr(data['uid']);

        await ref.set({
          'uid': ownerUid,
          'active': false,
          'pairedAt': FieldValue.serverTimestamp(),
          'pairedBy': myUid,
        }, SetOptions(merge: true));
      }

      await deactivateCode(oldMyCode);
      await deactivateCode(oldPartnerCode);

      Future<void> deleteIfInactive(String code) async {
        if (code.isEmpty) return;
        try {
          final ref = pairCodes.doc(code);
          final snap = await ref.get();
          if (!snap.exists) return;
          final data = snap.data() ?? <String, dynamic>{};
          final active = data['active'] == true;
          if (!active) await ref.delete();
        } catch (_) {}
      }

      await deleteIfInactive(oldMyCode);
      await deleteIfInactive(oldPartnerCode);

      Future<void> createNewCode(String code, String owner) async {
        if (code.isEmpty) return;
        await pairCodes.doc(code).set({
          'uid': owner,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await createNewCode(newMyCode, myUid);
      await createNewCode(newPartnerCode, partnerUid);

      final reset = <String, dynamic>{
        'isPaired': false,
        'pairedUserId': null,
        'pairedAt': null,
        'dailyHearts': 0,
        'dailyMessages': 0,
        'totalHearts': 0,
        'totalMessages': 0,
        'lastLocation': null,
        'winnerStreak': 0,
        'lastResultDayKey': null,
        'winnerToday': false,
        'dailyKey': '',
        'totalWins': 0,
        'cooldownUntil': null,
        'penaltyUntil': null,
        'clockTamperCount': 0,
        'clockTamperedAt': null,
      };

      final b2 = db.batch();
      b2.set(
        users.doc(myUid),
        {...reset, 'pairCode': newMyCode},
        SetOptions(merge: true),
      );
      b2.set(
        users.doc(partnerUid),
        {...reset, 'pairCode': newPartnerCode},
        SetOptions(merge: true),
      );
      await b2.commit();

      if (!mounted) return;

      Future.microtask(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PairingScreen()),
          (_) => false,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = trError(e);
          _unpairing = false;
        });
      }
    }
  }

  void _applyServerTimingState(Map<String, dynamic> me) {
    final cooldown = me['cooldownUntil'];
    final penalty = me['penaltyUntil'];

    _cooldownUntilTs = cooldown is Timestamp ? cooldown : null;
    _penaltyUntilTs = penalty is Timestamp ? penalty : null;

    final left = _cooldownLeft();
    if (_cooldownNotifier.value != left) {
      _cooldownNotifier.value = left;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _uid;
    final meStream = _me$;

    if (myUid == null || meStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: meStream,
      builder: (context, mySnap) {
        if (mySnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Kullanıcı verisi okunamadı:\n${mySnap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!mySnap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final me = mySnap.data!.data() ?? {};
        _applyServerTimingState(me);

        final partnerUid = _asStr(me['pairedUserId']);

        if (me['isPaired'] != true || partnerUid.isEmpty) {
          if (!_didNavigateToPairing && !mySnap.data!.metadata.isFromCache) {
            _didNavigateToPairing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const PairingScreen()),
                (_) => false,
              );
            });
          }

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _ensurePartnerAndInteractionStreams(
            myUid: myUid, partnerUid: partnerUid);

        final partnerStream = _partner$;
        if (partnerStream == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: partnerStream,
          builder: (context, pSnap) {
            if (pSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Partner verisi okunamadı:\n${pSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!pSnap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final partner = pSnap.data!.data() ?? {};
            final myGender = _asStr(me['gender']);
            final partnerGender = _asStr(partner['gender']);

            final myMood = me['mood'] is Map
                ? Map<String, dynamic>.from(me['mood'] as Map)
                : <String, dynamic>{};

            final partnerMood = partner['mood'] is Map
                ? Map<String, dynamic>.from(partner['mood'] as Map)
                : <String, dynamic>{};

            final myMoodKey = _asStr(myMood['key']);
            final myMoodEmoji = _asStr(myMood['emoji']);
            final myMoodLabel = _asStr(myMood['label']);
            final partnerMoodKey = _asStr(partnerMood['key']);
            final partnerMoodEmoji = _asStr(partnerMood['emoji']);
            final partnerMoodLabel = _asStr(partnerMood['label']);
            final myMoodUpdatedAt = me['moodUpdatedAt'] is Timestamp
                ? me['moodUpdatedAt'] as Timestamp
                : (myMood['updatedAt'] is Timestamp
                    ? myMood['updatedAt'] as Timestamp
                    : null);
            final partnerMoodUpdatedAt = partner['moodUpdatedAt'] is Timestamp
                ? partner['moodUpdatedAt'] as Timestamp
                : (partnerMood['updatedAt'] is Timestamp
                    ? partnerMood['updatedAt'] as Timestamp
                    : null);

            if (!_didInitialAutoRollover && !_rolloverRunning) {
              _didInitialAutoRollover = true;
              _rolloverRunning = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await _ensureDailyRollOverIfNeeded(
                      myUid: myUid, partnerUid: partnerUid);
                  _queueSafeRefresh();
                } finally {
                  _rolloverRunning = false;
                }
              });
            }

            final trustedNow = _trustedNow();
            final dkNow =
                trustedNow != null ? _dayKeyFromTrusted(trustedNow) : null;
            if (dkNow != null &&
                _lastSeenDayKey != dkNow &&
                !_rolloverRunning) {
              _lastSeenDayKey = dkNow;
              _rolloverRunning = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await _ensureDailyRollOverIfNeeded(
                      myUid: myUid, partnerUid: partnerUid);
                  _ensurePartnerAndInteractionStreams(
                      myUid: myUid, partnerUid: partnerUid);
                  _queueSafeRefresh();
                } finally {
                  _rolloverRunning = false;
                }
              });
            }

            final myName =
                '${_asStr(me['firstName'])} ${_asStr(me['lastName'])}'.trim();
            final partnerName =
                '${_asStr(partner['firstName'])} ${_asStr(partner['lastName'])}'
                    .trim();

            final myLoc = me['lastLocation'] as Map<String, dynamic>?;
            final partnerLoc = partner['lastLocation'] as Map<String, dynamic>?;
            final km = _calcKm(myLoc, partnerLoc);
            final kmText = km == null ? '---' : km.toStringAsFixed(1);

            final days = _daysTogether(me['pairedAt'] as Timestamp?);

            final myDailyHearts = _asInt(me['dailyHearts']);
            final myDailyMsgs = _asInt(me['dailyMessages']);
            final myTotalHearts = _asInt(me['totalHearts']);
            final myTotalMsgs = _asInt(me['totalMessages']);

            final pDailyHearts = _asInt(partner['dailyHearts']);
            final pDailyMsgs = _asInt(partner['dailyMessages']);
            final pTotalHearts = _asInt(partner['totalHearts']);
            final pTotalMsgs = _asInt(partner['totalMessages']);

            final myTotalWins = _asInt(me['totalWins']);
            final partnerTotalWins = _asInt(partner['totalWins']);
            final myStreak = _asInt(me['winnerStreak']);
            final partnerStreak = _asInt(partner['winnerStreak']);

            final meResKey = _asStr(me['lastResultDayKey']);
            final partnerResKey = _asStr(partner['lastResultDayKey']);
            final resultKey = (meResKey.isNotEmpty && meResKey == partnerResKey)
                ? meResKey
                : '';

            final myWinnerToday = _asBool(me['winnerToday']);
            final partnerWinnerToday = _asBool(partner['winnerToday']);
            final myIsWinner = resultKey.isNotEmpty && myWinnerToday;
            final partnerIsWinner = resultKey.isNotEmpty && partnerWinnerToday;
            final didTie =
                resultKey.isNotEmpty && !myWinnerToday && !partnerWinnerToday;

            final incoming$ = _incomingLastAll$;
            final chat$ = _chatAll$;

            return Stack(
              children: [
                Scaffold(
                  appBar: AppBar(
                    title: const Text('Aşk Paneli'),
                    centerTitle: true,
                    actions: [
                      HomeActionMenuButton(
                        notifEnabled: _notifEnabled,
                        unpairing: _unpairing,
                        onSelected: (value) async {
                          if (value == 'gps' && !_sending && !_unpairing) {
                            final result = await _updateLocationOnce(
                              silent: false,
                              forceRemoteWrite: true,
                            );

                            if (result == LocationUpdateResult.updated ||
                                result == LocationUpdateResult.unchanged) {
                              await _startAutoLocationUpdates();
                            }

                            if (!mounted) return;

                            String message;
                            switch (result) {
                              case LocationUpdateResult.updated:
                                message = 'Konum güncellendi ✅';
                                break;
                              case LocationUpdateResult.unchanged:
                                message = 'Konum zaten güncel görünüyor. 📍';
                                break;
                              case LocationUpdateResult.serviceDisabled:
                              case LocationUpdateResult.permissionDenied:
                              case LocationUpdateResult.timeout:
                              case LocationUpdateResult.error:
                                message = _error?.isNotEmpty == true
                                    ? _error!
                                    : 'Konum güncellenemedi ❌';
                                break;
                            }

                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );

                            if (mounted) {
                              _setErrorIfChanged(null);
                            }
                          } else if (value == 'notif' && !_unpairing) {
                            final uid = _uid;
                            if (uid == null) return;
                            final ok = await NotificationService.instance
                                .requestPermissionAndRegisterToken(
                              uid: uid,
                            );
                            if (!mounted) return;
                            _refreshNotifState();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(ok
                                      ? 'Bildirimler açıldı ✅'
                                      : 'Token alınamadı.')),
                            );
                          } else if (value == 'theme_light') {
                            await ThemeController.instance
                                .setMode(AppThemeMode.light);
                          } else if (value == 'theme_dark') {
                            await ThemeController.instance
                                .setMode(AppThemeMode.dark);
                          } else if (value == 'unpair' && !_unpairing) {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Eşleşmeyi kaldır?'),
                                content: const Text(
                                  'İki tarafta da her şey sıfırlanır.\nMesajlar silinir, eski kodlar pasife çekilir.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Vazgeç'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Kaldır'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true &&
                                _uid != null &&
                                _partnerUidCached != null) {
                              await _unpair(
                                  myUid: _uid!, partnerUid: _partnerUidCached!);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: HomeHeaderCard(
                            myName: myName,
                            partnerName: partnerName,
                            myGender: myGender,
                            partnerGender: partnerGender,
                            kmText: kmText,
                            days: days,
                            myIsWinner: myIsWinner,
                            partnerIsWinner: partnerIsWinner,
                            myStreak: myStreak,
                            partnerStreak: partnerStreak,
                            myTotalWins: myTotalWins,
                            partnerTotalWins: partnerTotalWins,
                            didTieYesterday: didTie,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: HomeStatsCard(
                              title: 'Sen',
                              gender: myGender,
                              dailyHearts: myDailyHearts,
                              dailyMsgs: myDailyMsgs,
                              totalHearts: myTotalHearts,
                              totalMsgs: myTotalMsgs,
                              winner: myIsWinner,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: HomeStatsCard(
                              title: 'Partner',
                              gender: partnerGender,
                              dailyHearts: pDailyHearts,
                              dailyMsgs: pDailyMsgs,
                              totalHearts: pTotalHearts,
                              totalMsgs: pTotalMsgs,
                              winner: partnerIsWinner,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MoodCard(
                        title: 'Senin Ruh Halin',
                        selectedMoodKey: myMoodKey.isEmpty ? null : myMoodKey,
                        selectedMoodEmoji:
                            myMoodEmoji.isEmpty ? null : myMoodEmoji,
                        selectedMoodLabel:
                            myMoodLabel.isEmpty ? null : myMoodLabel,
                        updatedAt: myMoodUpdatedAt,
                        editable: true,
                        nowListenable: _trustedNowNotifier,
                        onMoodTap: (mood) => _setMood(mood: mood),
                      ),
                      const SizedBox(height: 10),
                      MoodCard(
                        title: 'Partnerinin Ruh Hali',
                        selectedMoodKey:
                            partnerMoodKey.isEmpty ? null : partnerMoodKey,
                        selectedMoodEmoji:
                            partnerMoodEmoji.isEmpty ? null : partnerMoodEmoji,
                        selectedMoodLabel:
                            partnerMoodLabel.isEmpty ? null : partnerMoodLabel,
                        updatedAt: partnerMoodUpdatedAt,
                        editable: false,
                        nowListenable: _trustedNowNotifier,
                      ),
                      const SizedBox(height: 18),
                      HomeHeartButton(
                        busy: _sending || _unpairing,
                        onTap: (_sending || _unpairing || _heartTapLocked)
                            ? null
                            : () => _sendHeart(
                                  me: me,
                                  partner: partner,
                                  partnerUid: partnerUid,
                                ),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: _cooldownNotifier,
                        builder: (_, __, ___) {
                          return Text(
                            _unpairing
                                ? 'Eşleşme kaldırılıyor… 🧹'
                                : _cooldownText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(180),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (incoming$ == null)
                        const Card(
                          child: ListTile(
                            title: Text('Son mesaj',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('Yükleniyor…',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        )
                      else
                        LastMessageWidget(
                          stream: incoming$,
                          myUid: myUid,
                          showHistory: _showHistory,
                          isDisabled: _unpairing,
                          onToggleHistory: () {
                            if (_unpairing) return;
                            setState(() => _showHistory = !_showHistory);
                          },
                        ),
                      if (_showHistory) ...[
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              height: 280,
                              child: chat$ == null
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : ChatHistoryWidget(
                                      stream: chat$,
                                      myUid: myUid,
                                      myGender: myGender,
                                      partnerGender: partnerGender,
                                    ),
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w900),
                        ),
                      ],
                      const SizedBox(height: 16),
                      HomeComposeCard(
                        controller: _manual,
                        enabled: !_sending && !_unpairing,
                        onSend: (_sending || _unpairing || _messageTapLocked)
                            ? null
                            : () => _sendManual(
                                  me: me,
                                  partner: partner,
                                  partnerUid: partnerUid,
                                ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                FlyingHeartsOverlay(hearts: _hearts),
              ],
            );
          },
        );
      },
    );
  }

}
