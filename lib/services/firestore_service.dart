import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pairing_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  CollectionReference<Map<String, dynamic>> get interactions =>
      db.collection('interactions');

  Future<void> ensureUserDoc({required String uid}) async {
    final ref = users.doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final code = PairingService.generateCode(length: 6);

    await ref.set({
      'firstName': '',
      'lastName': '',
      'email': null,
      'phone': null,
      'platform': 'web',
      'pairCode': code,
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
