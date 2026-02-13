import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/pairing_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_error.dart';
import 'home_screen.dart';
import 'qr_scan_screen.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  String? _uid;
  bool _loading = false;
  String? _error;
  final _codeCtrl = TextEditingController();
  bool _ensuringCode = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!mounted) return;
    setState(() => _uid = uid);
    if (uid == null) {
      return;
    }
    _sub?.cancel();
    _sub = FirestoreService.instance.users.doc(uid).snapshots().listen((snap) {
      final me = snap.data() ?? {};
      final isPaired = me['isPaired'] == true;
      final partnerUid = (me['pairedUserId'] ?? '').toString().trim();
      final myCode = (me['pairCode'] ?? '').toString().trim();
      if (isPaired && partnerUid.isNotEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
      if (!isPaired && myCode.isEmpty) {
        _ensureMyPairCodeOnce(uid);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _copy(String txt) async {
    await Clipboard.setData(ClipboardData(text: txt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandı ✅')),
    );
  }

  Future<void> _ensureMyPairCodeOnce(String uid) async {
    if (_ensuringCode) return;
    _ensuringCode = true;
    try {
      final users = FirestoreService.instance.users;
      final ref = users.doc(uid);
      final snap = await ref.get();
      final me = snap.data() ?? {};
      final current = (me['pairCode'] ?? '').toString().trim();
      if (current.isNotEmpty) return;
      final newCode = PairingService.generateCode(length: 6);
      await ref.set({'pairCode': newCode}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) setState(() => _error = trError(e));
    } finally {
      _ensuringCode = false;
    }
  }

  Future<void> _refreshMyCode() async {
    final myUid = _uid;
    if (myUid == null) return;
    try {
      final newCode = PairingService.generateCode(length: 6);
      await FirestoreService.instance.users.doc(myUid).set(
        {'pairCode': newCode},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (mounted) setState(() => _error = trError(e));
    }
  }

  Future<void> _pairWithCode(String input) async {
    final myUid = _uid;
    if (myUid == null) return;
    final code = PairingService.normalize(input);
    if (!PairingService.isValid(code)) {
      setState(() => _error = 'Kod geçersiz. Örn: YMS-ABC123 veya ABC123');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = FirestoreService.instance.users;
      final q = await users.where('pairCode', isEqualTo: code).limit(1).get();
      if (q.docs.isEmpty) {
        setState(
            () => _error = 'Bu kod bulunamadı. Tekrar kontrol eder misin?');
        return;
      }
      final partnerDoc = q.docs.first;
      if (partnerDoc.id == myUid) {
        setState(() => _error = 'Kendi kodunla eşleşemezsin 🙂');
        return;
      }
      final partner = partnerDoc.data();
      if (partner['isPaired'] == true) {
        setState(() => _error = 'Bu kullanıcı zaten eşleşmiş.');
        return;
      }
      final mySnap = await users.doc(myUid).get();
      final me = mySnap.data() ?? {};
      if (me['isPaired'] == true) {
        setState(() => _error = 'Sen zaten eşleşmişsin.');
        return;
      }
      final batch = FirestoreService.instance.db.batch();
      final now = FieldValue.serverTimestamp();
      batch.set(
        users.doc(myUid),
        {
          'isPaired': true,
          'pairedUserId': partnerDoc.id,
          'pairedAt': now,
        },
        SetOptions(merge: true),
      );
      batch.set(
        users.doc(partnerDoc.id),
        {
          'isPaired': true,
          'pairedUserId': myUid,
          'pairedAt': now,
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _error = trError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
      builder: (context, snap) {
        final me = snap.data?.data() ?? {};
        final myCode = (me['pairCode'] ?? '').toString().trim();
        final isPaired = me['isPaired'] == true;
        final partnerUid = (me['pairedUserId'] ?? '').toString().trim();
        if (isPaired && partnerUid.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          });
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Eşleşme')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Senin Eşleşme Kodun',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(14),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.primary.withAlpha(35),
                                ),
                              ),
                              child: Text(
                                myCode.isEmpty ? 'Kod hazırlanıyor…' : myCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed:
                                myCode.isEmpty ? null : () => _copy(myCode),
                            icon: const Icon(Icons.copy_rounded,
                                color: AppTheme.primary),
                          ),
                          IconButton(
                            tooltip: 'Kodu yenile',
                            onPressed: _loading ? null : _refreshMyCode,
                            icon: const Icon(Icons.refresh_rounded,
                                color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.black.withAlpha(10)),
                          ),
                          child: QrImageView(
                            data: myCode.isEmpty ? 'YMS' : myCode,
                            size: 190,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Partnerin kodu yazabilir veya QR’ı kopyalayabilir.',
                          style: TextStyle(
                            color: Colors.black.withAlpha(140),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Partner kodu',
                          hintText: 'YMS-ABC123 veya ABC123',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _pairWithCode(_codeCtrl.text),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(_loading ? 'Eşleşiyor…' : 'Eşleştir'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () async {
                                    final scanned =
                                        await Navigator.push<String?>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const QrScanScreen()),
                                    );
                                    if (scanned != null &&
                                        scanned.trim().isNotEmpty) {
                                      _codeCtrl.text = scanned;
                                      await _pairWithCode(scanned);
                                    }
                                  },
                            icon: const Icon(Icons.qr_code_rounded),
                            label: const Text('QR'),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
