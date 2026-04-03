import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/firestore_service.dart';
import '../services/pairing_service.dart';
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
  bool _isInitDone = false;
  String? _error;

  final _codeCtrl = TextEditingController();
  bool _navigating = false;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _initCode();
  }

  Future<void> _initCode() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirestoreService.instance.ensureUserDoc(uid: uid);
    } catch (e) {
      debugPrint('Kod başlatma hatası: $e');
    } finally {
      _safeSetState(() => _isInitDone = true);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _goHome() {
    if (_navigating) return;
    _navigating = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _copy(String txt) async {
    await Clipboard.setData(ClipboardData(text: txt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandı ✅')),
    );
  }

  Future<void> _refreshMyCode() async {
    final myUid = _uid;
    if (myUid == null) return;

    _safeSetState(() {
      _error = null;
      _loading = true;
    });

    try {
      final users = FirestoreService.instance.users;
      final db = FirestoreService.instance.db;

      final mySnap = await users.doc(myUid).get();
      final me = mySnap.data() ?? <String, dynamic>{};

      final oldCode = (me['pairCode'] ?? '').toString().trim();
      final newCode = PairingService.generateCode(length: 6);

      final batch = db.batch();

      batch.set(
          users.doc(myUid), {'pairCode': newCode}, SetOptions(merge: true));

      batch.set(
        db.collection('pairCodes').doc(newCode),
        {
          'uid': myUid,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (oldCode.isNotEmpty && oldCode != newCode) {
        batch.set(
          db.collection('pairCodes').doc(oldCode),
          {
            'uid': myUid,
            'active': false,
            'disabledAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('permission-denied')) {
        _safeSetState(() => _error =
            'İzin hatası 😅\nPartner zaten eşleşmiş olabilir ya da partnerın kaydı yok.');
      } else {
        _safeSetState(() => _error = trError(e));
      }
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  Future<void> _pairWithCode(String input) async {
    final myUid = _uid;
    if (myUid == null) return;

    final code = PairingService.normalize(input);
    if (!PairingService.isValid(code)) {
      _safeSetState(
          () => _error = 'Kod geçersiz 😅\nÖrn: YMS-ABC123 veya ABC123');
      return;
    }

    _safeSetState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = FirestoreService.instance.db;
      final users = FirestoreService.instance.users;

      final pcRef = db.collection('pairCodes').doc(code);
      final pcSnap = await pcRef.get();

      if (!pcSnap.exists) {
        _safeSetState(() => _error = 'Bu kod bulunamadı 🕵️‍♂️');
        return;
      }

      final pc = pcSnap.data() ?? <String, dynamic>{};
      final partnerUid = (pc['uid'] ?? '').toString().trim();
      final active = (pc['active'] == null) ? true : (pc['active'] == true);

      if (!active) {
        _safeSetState(() => _error = 'Bu kod pasif ❌\nPartner kodu yenilesin.');
        return;
      }
      if (partnerUid.isEmpty) {
        _safeSetState(
            () => _error = 'Kod bozuk görünüyor 🤕\nPartner kodu yenilesin.');
        return;
      }
      if (partnerUid == myUid) {
        _safeSetState(() => _error = 'Kendi kodunla eşleşemezsin 🙂');
        return;
      }

      final mySnap = await users.doc(myUid).get();
      final me = mySnap.data() ?? <String, dynamic>{};
      if (me['isPaired'] == true) {
        _safeSetState(() => _error = 'Zaten eşleşmişsin 💞');
        return;
      }

      final myCode = (me['pairCode'] ?? '').toString().trim();
      if (myCode.isEmpty) {
        _safeSetState(() => _error =
            'Senin kodun hazır değil 😅\n1-2 sn bekleyip tekrar dene.');
        return;
      }

      final now = FieldValue.serverTimestamp();

      final batch = db.batch();

      batch.update(users.doc(myUid),
          {'isPaired': true, 'pairedUserId': partnerUid, 'pairedAt': now});

      batch.update(users.doc(partnerUid),
          {'isPaired': true, 'pairedUserId': myUid, 'pairedAt': now});

      batch.update(pcRef, {
        'active': false,
        'pairedBy': myUid,
        'pairedAt': now,
        'pairedWith': myUid,
      });

      final myCodeRef = db.collection('pairCodes').doc(myCode);
      batch.set(
          myCodeRef,
          {
            'uid': myUid,
            'active': false,
            'pairedBy': myUid,
            'pairedAt': now,
            'pairedWith': partnerUid,
          },
          SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      _goHome();
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('permission-denied')) {
        _safeSetState(() => _error =
            'İzin hatası 😅\nPartner zaten eşleşmiş olabilir ya da partnerın kaydı yok.');
      } else {
        _safeSetState(() => _error = trError(e));
      }
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _uid;
    if (myUid == null || !_isInitDone) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final users = FirestoreService.instance.users;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: users.doc(myUid).snapshots(),
      builder: (context, snap) {
        final me = snap.data?.data() ?? <String, dynamic>{};

        final isPaired = me['isPaired'] == true;
        final partnerUid = (me['pairedUserId'] ?? '').toString().trim();
        final myCode = (me['pairCode'] ?? '').toString().trim();

        if (isPaired && partnerUid.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _goHome();
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Eşleştirme'),
            actions: [
              TextButton(
                onPressed: _loading ? null : _refreshMyCode,
                child: const Text('Kodu Yenile',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Senin Kodun',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      SelectableText(
                        myCode.isEmpty ? '...' : myCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 22),
                      ),
                      const SizedBox(height: 12),
                      if (myCode.isNotEmpty)
                        Center(
                          child: QrImageView(
                            data: myCode,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  myCode.isEmpty ? null : () => _copy(myCode),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Kopyala'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () async {
                                      final v = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const QrScanScreen(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      if (v is String && v.trim().isNotEmpty) {
                                        _pairWithCode(v.trim());
                                      }
                                    },
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('QR Oku'),
                            ),
                          ),
                        ],
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
                      const Text('Partner Kodu Gir',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeCtrl,
                        enabled: !_loading,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (v) => _loading ? null : _pairWithCode(v),
                        decoration: const InputDecoration(
                          hintText: 'Örn: YMS-ABC123 / ABC123',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => _pairWithCode(_codeCtrl.text),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Eşleş'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
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
              const SizedBox(height: 16),
              Text(
                'Not: Kod yenilersen eski kod pasif olur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
