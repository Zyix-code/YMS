import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';
import '../services/love_messages.dart';
import '../services/notification_service.dart';
import '../services/pairing_service.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_error.dart';
import '../utils/local_storage.dart';
import 'pairing_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String? _uid;

  bool _showHistory = false;
  bool _sending = false;
  String? _error;

  bool _notifEnabled = false;

  DateTime? _lastSendAt;
  static const int cooldownSeconds = 300;

  Timer? _cooldownTicker;
  int _lastSnackAtMs = 0;

  final _manual = TextEditingController();
  final _rand = Random();
  final List<_FlyingHeart> _hearts = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _meSub;

  static const String _kLastSendAtMs = 'yms_last_send_at_ms';

  String? _lastSeenDayKey;
  bool _rolloverRunning = false;

  String _todayKeyLocal() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
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

  @override
  void initState() {
    super.initState();
    _lastSeenDayKey = _todayKeyLocal();
    _init();
    _startCooldownTicker();
    _refreshNotifState();
    _loadLastSendAt();
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _meSub?.cancel();
    _manual.dispose();
    for (final h in _hearts) {
      h.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLastSendAt() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final ms = sp.getInt(_kLastSendAtMs);
      if (ms == null || ms <= 0) return;

      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      if (DateTime.now().difference(dt).inSeconds > cooldownSeconds + 5) {
        await sp.remove(_kLastSendAtMs);
        return;
      }

      _lastSendAt = dt;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveLastSendAt(DateTime dt) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kLastSendAtMs, dt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _clearLastSendAt() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kLastSendAtMs);
    } catch (_) {}
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_lastSendAt == null) return;

      final left = _cooldownLeft();
      if (left <= 0) {
        _lastSendAt = null;
        await _clearLastSendAt();
        if (mounted) setState(() {});
        return;
      }
      setState(() {});
    });
  }

  bool _isCoolingDown() {
    if (_lastSendAt == null) return false;
    return DateTime.now().difference(_lastSendAt!).inSeconds < cooldownSeconds;
  }

  int _cooldownLeft() {
    if (_lastSendAt == null) return 0;
    final left =
        cooldownSeconds - DateTime.now().difference(_lastSendAt!).inSeconds;
    return left < 0 ? 0 : left;
  }

  String _cooldownText() {
    final left = _cooldownLeft();
    if (left <= 0) return 'Hazır 💗 Gönderebilirsin.';

    final minutes = left ~/ 60;
    final seconds = left % 60;

    if (minutes > 0) {
      return 'Minik bir mola 💗 $minutes dk $seconds sn sonra tekrar gönderebilirsin.';
    } else {
      return 'Minik bir mola 💗 $seconds sn sonra tekrar gönderebilirsin.';
    }
  }

  void _showCooldownSnack() {
    final now = DateTime.now().millisecondsSinceEpoch;
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
    if (!mounted) return;
    setState(() => _notifEnabled = NotificationService.instance.hasPermission);
  }

  Future<void> _init() async {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (!mounted) return;

    setState(() => _uid = id);
    if (id == null) return;

    Future(() async {
      await _updateLocationOnce(silent: true);
    });

    _meSub?.cancel();
    _meSub = FirestoreService.instance.users.doc(id).snapshots().listen(
      (snap) async {
        final me = snap.data() ?? {};
        final ts = me['lastIncomingAt'];
        final msg = (me['lastIncomingText'] ?? '').toString().trim();

        if (ts is! Timestamp) return;
        if (msg.isEmpty) return;

        final ms = ts.millisecondsSinceEpoch;
        final lastMs = await LocalStorage.getLastNotifiedIncomingMs();
        if (lastMs != null && lastMs == ms) return;
        await LocalStorage.setLastNotifiedIncomingMs(ms);
      },
    );
  }

  Future<bool> _updateLocationOnce({bool silent = false}) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent && mounted)
          setState(() => _error = 'Konum servisleri kapalı.');
        return false;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          setState(() => _error =
              'Konum izni yok. İzin verirsen mesafeyi gösterebilirim.');
        }
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      await FirestoreService.instance.users.doc(uid).set({
        'lastLocation': {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      return true;
    } on TimeoutException {
      if (!silent && mounted) {
        setState(
            () => _error = 'Konum alınamadı. Birazdan tekrar dener misin?');
      }
      return false;
    } catch (e) {
      if (!silent && mounted) setState(() => _error = trError(e));
      return false;
    }
  }

  double? _calcKm(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return null;
    final lat1 = (a['lat'] as num?)?.toDouble();
    final lng1 = (a['lng'] as num?)?.toDouble();
    final lat2 = (b['lat'] as num?)?.toDouble();
    final lng2 = (b['lng'] as num?)?.toDouble();
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null)
      return null;
    final meters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return meters / 1000.0;
  }

  int _daysTogether(Timestamp? pairedAt) {
    if (pairedAt == null) return 0;
    final start = pairedAt.toDate();
    final now = DateTime.now();
    final diff =
        now.difference(DateTime(start.year, start.month, start.day)).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _todayChatStream({
    required String myUid,
    required String partnerUid,
  }) {
    final pid = _pairId(myUid, partnerUid);
    final dk = _todayKeyLocal();

    return FirestoreService.instance.interactions
        .where('pairId', isEqualTo: pid)
        .where('dayKey', isEqualTo: dk)
        .orderBy('createdAtMs', descending: true)
        .limit(200)
        .snapshots();
  }

  Future<void> _ensureDailyRollOverIfNeeded({
    required String myUid,
    required String partnerUid,
  }) async {
    final users = FirestoreService.instance.users;

    await FirestoreService.instance.db.runTransaction((tx) async {
      final myRef = users.doc(myUid);
      final partnerRef = users.doc(partnerUid);

      final mySnap = await tx.get(myRef);
      final partnerSnap = await tx.get(partnerRef);

      final me = mySnap.data() ?? <String, dynamic>{};
      final partner = partnerSnap.data() ?? <String, dynamic>{};

      final today = _todayKeyLocal();
      final currentKey = (me['dailyKey'] ?? '').toString().trim();

      final myPrevWins = _asInt(me['totalWins']);
      final pPrevWins = _asInt(partner['totalWins']);

      if (me['totalWins'] == null) {
        tx.set(myRef, {'totalWins': myPrevWins}, SetOptions(merge: true));
      }
      if (partner['totalWins'] == null) {
        tx.set(partnerRef, {'totalWins': pPrevWins}, SetOptions(merge: true));
      }
      if (currentKey.isEmpty) {
        tx.set(
          myRef,
          {'dailyKey': today, 'dailyHearts': 0, 'dailyMessages': 0},
          SetOptions(merge: true),
        );
        tx.set(
          partnerRef,
          {'dailyKey': today, 'dailyHearts': 0, 'dailyMessages': 0},
          SetOptions(merge: true),
        );
        return;
      }

      if (currentKey == today) return;

      final lastResultKey = (me['lastResultKey'] ?? '').toString().trim();
      final yKey = currentKey;

      if (lastResultKey != yKey) {
        final myScore = _asInt(me['dailyHearts']) + _asInt(me['dailyMessages']);
        final pScore =
            _asInt(partner['dailyHearts']) + _asInt(partner['dailyMessages']);

        String? winnerUid;
        if (myScore > pScore) winnerUid = myUid;
        if (pScore > myScore) winnerUid = partnerUid;

        final myIsWinner = winnerUid == myUid;
        final pIsWinner = winnerUid == partnerUid;

        final myPrevStreak = _asInt(me['winnerStreak']);
        final pPrevStreak = _asInt(partner['winnerStreak']);

        tx.set(
          myRef,
          {
            'lastResultKey': yKey,
            'isWinnerToday': myIsWinner,
            'winnerStreak': myIsWinner ? (myPrevStreak + 1) : 0,
            'totalWins': myIsWinner ? (myPrevWins + 1) : myPrevWins,
          },
          SetOptions(merge: true),
        );

        tx.set(
          partnerRef,
          {
            'lastResultKey': yKey,
            'isWinnerToday': pIsWinner,
            'winnerStreak': pIsWinner ? (pPrevStreak + 1) : 0,
            'totalWins': pIsWinner ? (pPrevWins + 1) : pPrevWins,
          },
          SetOptions(merge: true),
        );
      }
      tx.set(
        myRef,
        {'dailyKey': today, 'dailyHearts': 0, 'dailyMessages': 0},
        SetOptions(merge: true),
      );
      tx.set(
        partnerRef,
        {'dailyKey': today, 'dailyHearts': 0, 'dailyMessages': 0},
        SetOptions(merge: true),
      );
    });
  }

  void _spawnHearts() {
    for (int i = 0; i < 10; i++) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 900 + _rand.nextInt(500)),
      );

      final h = _FlyingHeart(
        id: DateTime.now().microsecondsSinceEpoch + i,
        x: 0.20 + _rand.nextDouble() * 0.60,
        controller: c,
      );

      c.addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          c.dispose();
          if (mounted) setState(() => _hearts.removeWhere((x) => x.id == h.id));
        }
      });

      setState(() => _hearts.add(h));
      c.forward();
    }
  }

  Future<void> _sendHeart({
    required Map<String, dynamic> me,
    required Map<String, dynamic> partner,
    required String partnerUid,
  }) async {
    final partnerFirst = (partner['firstName'] ?? '').toString().trim();
    final name = partnerFirst.isEmpty ? 'Aşkım' : partnerFirst;
    final msg = await LoveMessages.randomFor(name);

    await _sendInteraction(
      me: me,
      partner: partner,
      partnerUid: partnerUid,
      type: 'heart',
      message: msg,
    );
  }

  Future<void> _sendManual({
    required Map<String, dynamic> me,
    required Map<String, dynamic> partner,
    required String partnerUid,
  }) async {
    final t = _manual.text.trim();
    if (t.isEmpty) return;

    if (_isCoolingDown()) {
      _showCooldownSnack();
      return;
    }

    _manual.clear();

    await _sendInteraction(
      me: me,
      partner: partner,
      partnerUid: partnerUid,
      type: 'message',
      message: t,
    );
  }

  Future<void> _sendInteraction({
    required Map<String, dynamic> me,
    required Map<String, dynamic> partner,
    required String partnerUid,
    required String type,
    required String message,
  }) async {
    final myUid = _uid;
    if (myUid == null) return;

    if (_isCoolingDown()) {
      _showCooldownSnack();
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _ensureDailyRollOverIfNeeded(myUid: myUid, partnerUid: partnerUid);

      final users = FirestoreService.instance.users;
      final batch = FirestoreService.instance.db.batch();

      final dayKey = _todayKeyLocal();
      final pid = _pairId(myUid, partnerUid);
      final createdAtMs = DateTime.now().millisecondsSinceEpoch;

      batch.set(
        users.doc(myUid),
        {
          'dailyKey': dayKey,
          if (type == 'heart') 'dailyHearts': FieldValue.increment(1),
          if (type == 'message') 'dailyMessages': FieldValue.increment(1),
          if (type == 'heart') 'totalHearts': FieldValue.increment(1),
          if (type == 'message') 'totalMessages': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      batch.set(
        users.doc(partnerUid),
        {
          'lastIncomingText': message,
          'lastIncomingAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        FirestoreService.instance.interactions.doc(),
        {
          'pairId': pid,
          'dayKey': dayKey,
          'createdAtMs': createdAtMs,
          'type': type,
          'message': message,
          'createdAt': FieldValue.serverTimestamp(),
          'fromUid': myUid,
          'toUid': partnerUid,
        },
      );

      await batch.commit();

      final partnerFirst = (partner['firstName'] ?? '').toString().trim();
      final senderFirst = (me['firstName'] ?? '').toString().trim();

      final pushTitle = senderFirst.isEmpty ? 'YMS 💗' : '$senderFirst 💗';
      final pushBody = message.isNotEmpty
          ? message
          : (partnerFirst.isEmpty
              ? 'Seni hatırladı'
              : '$partnerFirst seni hatırladı');

      await PushService.instance.sendToUid(
        toUid: partnerUid,
        title: pushTitle,
        body: pushBody,
      );

      _lastSendAt = DateTime.now();
      await _saveLastSendAt(_lastSendAt!);

      _spawnHearts();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = trError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _unpair({
    required String myUid,
    required String partnerUid,
  }) async {
    setState(() => _error = null);

    final users = FirestoreService.instance.users;

    final newMyCode = PairingService.generateCode(length: 6);
    final newPartnerCode = PairingService.generateCode(length: 6);

    final reset = <String, dynamic>{
      'isPaired': false,
      'pairedUserId': null,
      'pairedAt': null,
      'dailyHearts': 0,
      'dailyMessages': 0,
      'totalHearts': 0,
      'totalMessages': 0,
      'lastIncomingText': null,
      'lastIncomingAt': null,
      'lastLocation': null,
      'winnerStreak': 0,
      'isWinnerToday': false,
      'lastResultKey': null,
      'dailyKey': '',
      'totalWins': 0,
    };

    try {
      final batch = FirestoreService.instance.db.batch();
      batch.set(users.doc(myUid), {...reset, 'pairCode': newMyCode},
          SetOptions(merge: true));
      batch.set(users.doc(partnerUid), {...reset, 'pairCode': newPartnerCode},
          SetOptions(merge: true));
      await batch.commit();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PairingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = trError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _uid;
    if (myUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final users = FirestoreService.instance.users;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: users.doc(myUid).snapshots(),
      builder: (context, mySnap) {
        if (!mySnap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final me = mySnap.data!.data() ?? {};
        final partnerUid = (me['pairedUserId'] ?? '').toString().trim();

        if (me['isPaired'] != true || partnerUid.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const PairingScreen()),
              (_) => false,
            );
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: users.doc(partnerUid).snapshots(),
          builder: (context, pSnap) {
            if (!pSnap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final partner = pSnap.data!.data() ?? {};

            final dkNow = _todayKeyLocal();
            if (_lastSeenDayKey != dkNow && !_rolloverRunning) {
              _lastSeenDayKey = dkNow;
              _rolloverRunning = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await _ensureDailyRollOverIfNeeded(
                      myUid: myUid, partnerUid: partnerUid);
                  if (mounted) setState(() {});
                } finally {
                  _rolloverRunning = false;
                }
              });
            }

            final myName =
                '${(me['firstName'] ?? '')} ${(me['lastName'] ?? '')}'.trim();
            final pName =
                '${(partner['firstName'] ?? '')} ${(partner['lastName'] ?? '')}'
                    .trim();

            final myLoc = me['lastLocation'] as Map<String, dynamic>?;
            final pLoc = partner['lastLocation'] as Map<String, dynamic>?;
            final km = _calcKm(myLoc, pLoc);
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

            final myIsWinner = me['isWinnerToday'] == true;
            final pIsWinner = partner['isWinnerToday'] == true;

            final myTotalWins = _asInt(me['totalWins']);
            final pTotalWins = _asInt(partner['totalWins']);

            final myStreak = _asInt(me['winnerStreak']);
            final pStreak = _asInt(partner['winnerStreak']);

            final lastIncoming =
                (me['lastIncomingText'] ?? '').toString().trim();

            return Stack(
              children: [
                Scaffold(
                  appBar: AppBar(
                    title: const Text('Ana Sayfa'),
                    actions: [
                      TextButton.icon(
                        onPressed: _sending
                            ? null
                            : () async {
                                final ok =
                                    await _updateLocationOnce(silent: false);
                                if (!mounted) return;

                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Konum güncellendi ✅'
                                        : 'Konum güncellenemedi ❌'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.my_location_rounded,
                            color: AppTheme.primary),
                        label: const Text(
                          'GPS',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () async {
                          final uid = _uid;
                          if (uid == null) return;

                          final ok = await NotificationService.instance
                              .requestPermissionAndRegisterToken(uid: uid);

                          if (!mounted) return;
                          _refreshNotifState();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Bildirimler açıldı ✅'
                                  : 'Bildirim izni verildi ama token alınamadı.'),
                            ),
                          );
                        },
                        icon: Icon(
                          _notifEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          color: AppTheme.primary,
                        ),
                        label: const Text(
                          'Bildirimleri Aç',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Eşleşmeyi kaldır?'),
                              content: const Text(
                                  'İki tarafta da her şey sıfırlanır ve eşleşme ekranına dönersiniz.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Vazgeç')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Kaldır')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await _unpair(myUid: myUid, partnerUid: partnerUid);
                          }
                        },
                        icon: const Icon(Icons.link_off_rounded,
                            color: AppTheme.primary),
                        label: const Text(
                          'Eşleşmeyi Kaldır',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _HeaderBlock(
                            myName: myName,
                            partnerName: pName,
                            kmText: kmText,
                            days: days,
                            myIsWinner: myIsWinner,
                            pIsWinner: pIsWinner,
                            myStreak: myStreak,
                            partnerStreak: pStreak,
                            myTotalWins: myTotalWins,
                            partnerTotalWins: pTotalWins,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _counterCard(
                              title: 'Sen',
                              dailyHearts: myDailyHearts,
                              dailyMsgs: myDailyMsgs,
                              totalHearts: myTotalHearts,
                              totalMsgs: myTotalMsgs,
                              winner: myIsWinner,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _counterCard(
                              title: 'Partner',
                              dailyHearts: pDailyHearts,
                              dailyMsgs: pDailyMsgs,
                              totalHearts: pTotalHearts,
                              totalMsgs: pTotalMsgs,
                              winner: pIsWinner,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          onTap: _sending
                              ? null
                              : () => _sendHeart(
                                  me: me,
                                  partner: partner,
                                  partnerUid: partnerUid),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 30,
                                  offset: const Offset(0, 18),
                                  color: AppTheme.primary.withAlpha(70),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _sending
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Icon(Icons.favorite_rounded,
                                      color: Colors.white, size: 96),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _cooldownText(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _isCoolingDown()
                              ? Colors.black.withAlpha(160)
                              : Colors.black.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.chat_bubble_rounded,
                                color: AppTheme.primary),
                          ),
                          title: Text(
                            'Bugün - Son mesaj',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.black.withAlpha(170)),
                          ),
                          subtitle: Text(
                            lastIncoming.isNotEmpty
                                ? lastIncoming
                                : 'Henüz bir mesaj yok 💗',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withAlpha(150)),
                          ),
                          trailing: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () =>
                                setState(() => _showHistory = !_showHistory),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.primary.withAlpha(60)),
                              ),
                              child: Icon(
                                _showHistory
                                    ? Icons.remove_rounded
                                    : Icons.add_rounded,
                                color: AppTheme.primary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_showHistory) ...[
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              height: 280,
                              child: StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream: _todayChatStream(
                                    myUid: myUid, partnerUid: partnerUid),
                                builder: (context, snap) {
                                  if (!snap.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }

                                  final docs = snap.data!.docs;
                                  if (docs.isEmpty) {
                                    return Text(
                                      'Bugün mesaj yok.',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black.withAlpha(140)),
                                    );
                                  }

                                  return ListView.separated(
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) => Divider(
                                      color: Colors.black.withAlpha(10),
                                      height: 1,
                                    ),
                                    itemBuilder: (context, i) {
                                      final d = docs[i].data();
                                      final msg = (d['message'] ?? '')
                                          .toString()
                                          .trim();
                                      final type = (d['type'] ?? '').toString();
                                      final fromUid =
                                          (d['fromUid'] ?? '').toString();

                                      final isMe = fromUid == myUid;
                                      final who = isMe ? 'Sen' : 'Partner';
                                      final icon =
                                          type == 'heart' ? '💗' : '💬';

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(icon,
                                                style: const TextStyle(
                                                    fontSize: 16)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w800),
                                                  children: [
                                                    TextSpan(
                                                      text: '$who: ',
                                                      style: TextStyle(
                                                        color: isMe
                                                            ? AppTheme.primary
                                                            : Colors.black
                                                                .withAlpha(180),
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                        text: msg.isEmpty
                                                            ? '(boş)'
                                                            : msg),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _manual,
                                  decoration: const InputDecoration(
                                    labelText: 'Mesaj yaz',
                                    hintText: 'Kısa bir şey yaz…',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _sending
                                    ? null
                                    : () => _sendManual(
                                        me: me,
                                        partner: partner,
                                        partnerUid: partnerUid),
                                child: const Text('Gönder'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                ..._hearts.map((h) => _FlyingHeartWidget(heart: h)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _counterCard({
    required String title,
    required int dailyHearts,
    required int dailyMsgs,
    required int totalHearts,
    required int totalMsgs,
    required bool winner,
  }) {
    final badge = winner ? ' 🏆' : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title$badge',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('💗 Kalp: $dailyHearts (Toplam: $totalHearts)',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('💬 Mesaj: $dailyMsgs (Toplam: $totalMsgs)',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  final String myName;
  final String partnerName;
  final String kmText;
  final int days;

  final bool myIsWinner;
  final bool pIsWinner;

  final int myStreak;
  final int partnerStreak;

  final int myTotalWins;
  final int partnerTotalWins;

  const _HeaderBlock({
    required this.myName,
    required this.partnerName,
    required this.kmText,
    required this.days,
    required this.myIsWinner,
    required this.pIsWinner,
    required this.myStreak,
    required this.partnerStreak,
    required this.myTotalWins,
    required this.partnerTotalWins,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _personCard(
          label: 'Sen',
          name: myName,
          isWinnerToday: myIsWinner,
          streak: myStreak,
          totalWins: myTotalWins,
        ),
        const SizedBox(height: 10),
        _personCard(
          label: 'Partner',
          name: partnerName,
          isWinnerToday: pIsWinner,
          streak: partnerStreak,
          totalWins: partnerTotalWins,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _pill('Mesafe', '$kmText km')),
            const SizedBox(width: 10),
            Expanded(child: _pill('Birlikte', '$days gün')),
          ],
        ),
      ],
    );
  }

  Widget _personCard({
    required String label,
    required String name,
    required bool isWinnerToday,
    required int streak,
    required int totalWins,
  }) {
    final showCrown = isWinnerToday && streak > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(text: '$label: '),
                      TextSpan(
                        text: name.isEmpty ? '---' : name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              if (showCrown) ...[
                const SizedBox(width: 10),
                _crownBadge(streak),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  size: 16, color: AppTheme.primary.withAlpha(230)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Toplam Kazanma: $totalWins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withAlpha(170),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crownBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Text(
        '🏆 x$streak',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.black.withAlpha(180),
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
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
              color: Colors.black.withAlpha(150),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FlyingHeart {
  final int id;
  final double x;
  final AnimationController controller;
  _FlyingHeart({required this.id, required this.x, required this.controller});
}

class _FlyingHeartWidget extends StatelessWidget {
  final _FlyingHeart heart;
  const _FlyingHeartWidget({required this.heart});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: heart.controller,
      builder: (context, _) {
        final t = heart.controller.value;
        final top = MediaQuery.of(context).size.height * (0.68 - 0.40 * t);
        final left = MediaQuery.of(context).size.width * heart.x;
        return Positioned(
          top: top,
          left: left,
          child: Opacity(
            opacity: (1 - t).clamp(0, 1),
            child: Transform.scale(
              scale: 0.8 + 0.5 * (1 - t),
              child: Icon(
                Icons.favorite,
                color: AppTheme.primary.withAlpha(240),
                size: 26,
              ),
            ),
          ),
        );
      },
    );
  }
}
