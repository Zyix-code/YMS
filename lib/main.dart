import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yms/screens/intro_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
  }

  var user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    final cred = await FirebaseAuth.instance.signInAnonymously();
    user = cred.user;
  }

  if (user != null) {
    await NotificationService.instance.initAndAutoRegister(uid: user.uid);
  }

  runApp(const YmsApp());
}

class YmsApp extends StatelessWidget {
  const YmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const IntroScreen(),
    );
  }
}
