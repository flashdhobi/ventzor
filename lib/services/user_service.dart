import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/model/ventzor_user.dart';

class UserService {
  final _usersRef = FirebaseFirestore.instance.collection('users');

  /// Create a user document (called after signup)
  Future<void> createUser(VentozerUser user) async {
    await _usersRef.doc(user.uid).set(user.toMap());
  }

  /// Get user by UID
  Future<VentozerUser?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (doc.exists) {
      return VentozerUser.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  /// Listen to user profile
  Stream<VentozerUser?> streamUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return VentozerUser.fromMap(doc.id, doc.data()!);
      }
      return null;
    });
  }

  /// Update user role or profile (partial update)
  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await _usersRef.doc(uid).update(updates);
  }

  /// List all users in an organization
  Future<List<VentozerUser>> getUsersInOrg(String orgId) async {
    final querySnapshot = await _usersRef
        .where('orgId', isEqualTo: orgId)
        .get();

    return querySnapshot.docs
        .map((doc) => VentozerUser.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Optional: Delete user document (doesn't delete Firebase Auth account)
  Future<void> deleteUser(String uid) async {
    await _usersRef.doc(uid).delete();
  }
}
