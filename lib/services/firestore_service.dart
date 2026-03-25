import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pairing_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  CollectionReference<Map<String, dynamic>> get pairCodes =>
      db.collection('pairCodes');
  CollectionReference<Map<String, dynamic>> get interactions =>
      db.collection('interactions');

  Future<void> ensureUserDoc({required String uid}) async {
    final userRef = users.doc(uid);
    final userSnap = await userRef.get();

    if (userSnap.exists) {
      final data = userSnap.data();
      final String? existingCode = data?['pairCode'] as String?;

      if (existingCode != null && existingCode.isNotEmpty) {
        return;
      }
    }

    final String newCode = PairingService.generateCode(length: 6);

    bool alreadyPaired = false;
    String? partnerId;

    if (userSnap.exists && userSnap.data() != null) {
      final data = userSnap.data()!;
      alreadyPaired = data['isPaired'] == true;
      partnerId = data['pairedUserId'] as String?;
    }

    final Map<String, dynamic> userData = {
      'pairCode': newCode,
      'isPaired': alreadyPaired,
      'pairedUserId': partnerId,
      'platform': 'web',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!userSnap.exists) {
      userData.addAll({
        'firstName': '',
        'lastName': '',
        'dailyHearts': 0,
        'totalHearts': 0,
        'dailyMessages': 0,
        'totalMessages': 0,
        'winnerStreak': 0,
        'totalWins': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final batch = db.batch();
    batch.set(userRef, userData, SetOptions(merge: true));

    batch.set(pairCodes.doc(newCode), {
      'uid': uid,
      'active': !alreadyPaired,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> unpair(
      {required String myUid, required String partnerUid}) async {
    final batch = db.batch();

    final Map<String, dynamic> resetData = {
      'isPaired': false,
      'pairedUserId': null,
      'pairedAt': null,
    };

    batch.update(users.doc(myUid), resetData);
    batch.update(users.doc(partnerUid), resetData);

    final mySnap = await users.doc(myUid).get();
    final myCode = mySnap.data()?['pairCode'] as String?;
    if (myCode != null) {
      batch.update(pairCodes.doc(myCode), {'active': true});
    }

    await batch.commit();
  }
}
