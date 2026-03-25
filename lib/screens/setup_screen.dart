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

  String _gender = "";
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

  Widget _genderBtn(
      {required String id,
      required IconData icon,
      required String label,
      required Color color}) {
    bool isSel = _gender == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSel ? color : Colors.grey.shade300, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? color : Colors.grey, size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: isSel ? color : Colors.grey,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Oturum bulunamadı. Sayfayı yeniler misin?');
      return;
    }

    if (_gender.isEmpty) {
      setState(() => _error = 'Lütfen cinsiyet seçimi yapın 🙂');
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
        'gender': _gender,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profilini oluşturalım 💗',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(
                      'Partnerin seni nasıl göreceğini belirle.',
                      style: TextStyle(
                          color: Colors.black.withAlpha(150),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    const Text("Cinsiyetin",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _genderBtn(
                            id: "erkek",
                            icon: Icons.male,
                            label: "Erkek",
                            color: Colors.blue),
                        const SizedBox(width: 12),
                        _genderBtn(
                            id: "kadin",
                            icon: Icons.female,
                            label: "Kadın",
                            color: Colors.pink),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(
                        labelText: 'Ad',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Ad gerekli 🙂';
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
                        if (!_emailRe.hasMatch(_normEmail(t)))
                          return 'Geçersiz e-posta.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon (opsiyonel)',
                        prefixIcon: Icon(Icons.phone),
                        hintText: '05XXXXXXXXX',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        if (!_isValidPhone(_normPhone(t)))
                          return 'Geçersiz telefon.';
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _save,
                        child: Text(_loading ? 'Kaydediliyor…' : 'Devam Et'),
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
