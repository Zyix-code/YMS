import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/local_storage.dart';
import '../services/firestore_service.dart';
import 'setup_screen.dart';
import 'pairing_screen.dart';
import 'home_screen.dart';

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    if (user == null) {
      _replace(const SetupScreen());
      return;
    }

    await LocalStorage.setUserId(user.uid);

    final snap = await FirestoreService.instance.users.doc(user.uid).get();
    final data = snap.data();

    final firstOk = (data?['firstName'] ?? '').toString().trim().isNotEmpty;
    final lastOk = (data?['lastName'] ?? '').toString().trim().isNotEmpty;

    if (!firstOk || !lastOk) {
      _replace(const SetupScreen());
      return;
    }

    final isPaired = data?['isPaired'] == true;
    final partnerUid = (data?['pairedUserId'] ?? '').toString().trim();

    if (isPaired && partnerUid.isNotEmpty) {
      _replace(const HomeScreen());
    } else {
      _replace(const PairingScreen());
    }
  }

  void _replace(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
