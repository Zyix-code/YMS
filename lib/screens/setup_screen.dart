import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../services/pairing_service.dart';
import '../utils/app_error.dart';
import 'pairing_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = false;
  String? _error;

  final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _normEmail(String s) => s.trim().toLowerCase();

  String _normPhone(String s) {
    var p = s.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    p = p.replaceAll(RegExp(r'[^0-9\+]'), '');
    if (p.startsWith('0') && p.length == 11) p = '+90${p.substring(1)}';
    if (!p.startsWith('+') && p.startsWith('90') && p.length == 12) p = '+$p';
    return p;
  }

  bool _isValidPhone(String normalized) {
    return RegExp(r'^\+\d{10,15}$').hasMatch(normalized);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Oturum bulunamadı. Sayfayı yeniler misin?');
      return;
    }

    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final first = _first.text.trim();
    final last = _last.text.trim();

    final emailRaw = _email.text.trim();
    final phoneRaw = _phone.text.trim();

    final emailLower = emailRaw.isEmpty ? '' : _normEmail(emailRaw);
    final phoneNorm = phoneRaw.isEmpty ? '' : _normPhone(phoneRaw);

    setState(() => _loading = true);

    try {
      final users = FirestoreService.instance.users;
      final db = FirestoreService.instance.db;

      final ref = users.doc(uid);
      final snap = await ref.get();
      final data = snap.data() ?? {};

      final existingCode = (data['pairCode'] ?? '').toString().trim();
      final pairCode = existingCode.isNotEmpty
          ? existingCode
          : PairingService.generateCode(length: 6);

      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'firstName': first,
        'lastName': last,
        'email': emailLower.isEmpty ? null : emailLower,
        'phone': phoneNorm.isEmpty ? null : phoneNorm,
        'platform': 'web',
        'pairCode': pairCode,
        'isPaired': false,
        'pairedUserId': null,
        'pairedAt': null,
        'dailyKey': '',
        'dailyHearts': 0,
        'dailyMessages': 0,
        'totalHearts': 0,
        'totalMessages': 0,
        'winnerStreak': 0,
        'lastResultDayKey': null,
        'winnerToday': false,
        'totalWins': 0,
        'lastLocation': null,
      }, SetOptions(merge: true));

      await db.collection('pairCodes').doc(pairCode).set({
        'uid': uid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PairingScreen()),
      );
    } catch (e) {
      setState(() => _error = trError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlk Kurulum')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profilini oluşturalım 💗',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Sonra eşleşmeye geçeceğiz.',
                      style: TextStyle(
                        color: Colors.black.withAlpha(150),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(
                        labelText: 'Ad',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Ad gerekli 🙂';
                        if (t.length < 2) return 'Ad çok kısa.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(
                        labelText: 'Soyad',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Soyad gerekli 🙂';
                        if (t.length < 2) return 'Soyad çok kısa.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'E-posta (opsiyonel)',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final em = _normEmail(t);
                        if (!_emailRe.hasMatch(em)) {
                          return 'E-posta formatı geçersiz.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon (opsiyonel)',
                        prefixIcon: Icon(Icons.phone),
                        hintText: '05XXXXXXXXX veya +90XXXXXXXXXX',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final p = _normPhone(t);
                        if (!_isValidPhone(p)) {
                          return 'Telefon formatı geçersiz. Örn: 05XXXXXXXXX';
                        }
                        return null;
                      },
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: Text(_loading ? 'Kaydediliyor…' : 'Devam'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
