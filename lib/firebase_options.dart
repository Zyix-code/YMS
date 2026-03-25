import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmpL4kb046gCD3qjWNSzI_m7HoVN1fUuc',
    appId: '1:472099892182:android:99d49e3d110403e2fe1277',
    messagingSenderId: '472099892182',
    projectId: 'ymss-c7a49',
    storageBucket: 'ymss-c7a49.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAghLvCfL6kzjjQS3Ihe2-I-acs1eGKc28',
    appId: '1:472099892182:ios:a26accdb2864afbffe1277',
    messagingSenderId: '472099892182',
    projectId: 'ymss-c7a49',
    storageBucket: 'ymss-c7a49.firebasestorage.app',
    iosBundleId: 'com.example.yms',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC3yGugiY6QLHkeQkIpbehAGKm2yx5bciE',
    appId: '1:472099892182:web:a7885719b6ca80f5fe1277',
    messagingSenderId: '472099892182',
    projectId: 'ymss-c7a49',
    authDomain: 'ymss-c7a49.firebaseapp.com',
    storageBucket: 'ymss-c7a49.firebasestorage.app',
    measurementId: 'G-G2S64ZESPZ',
  );
}
