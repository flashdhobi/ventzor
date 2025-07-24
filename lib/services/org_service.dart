import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ventzor/model/organization.dart';
import 'package:ventzor/services/user_service.dart';

class OrgService {
  final _orgsRef = FirebaseFirestore.instance.collection('organizations');
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _userService = UserService();

  /// Create a new organization
  Future<void> createOrganization(Organization org) async {
    await _orgsRef.doc(org.id).set(org.toMap());
  }

  Future<Organization?> getOrganizationById(String id) async {
    final doc = await _orgsRef.doc(id).get();
    if (doc.exists) {
      return Organization.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  /// Get an organization by ID
  Future<Organization?> getOrganization(String orgId) async {
    final doc = await _orgsRef.doc(orgId).get();
    if (doc.exists) {
      return Organization.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  /// Listen to updates for an organization
  Stream<Organization?> streamOrganization(String orgId) {
    return _orgsRef.doc(orgId).snapshots().map((doc) {
      if (doc.exists) {
        return Organization.fromMap(doc.id, doc.data()!);
      }
      return null;
    });
  }

  /// Update organization fields (partial update)
  Future<void> updateOrganization(
    String orgId,
    Map<String, dynamic> updates,
  ) async {
    await _orgsRef.doc(orgId).update(updates);
  }

  /// Delete an organization (optional, for admin tools)
  Future<void> deleteOrganization(String orgId) async {
    await _orgsRef.doc(orgId).delete();
  }

  Future<void> createOrJoinOrganization(String orgNameInput) async {
    final orgId = orgNameInput.trim().toLowerCase();
    final orgRef = _firestore.collection('organizations').doc(orgId);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final userId = user.uid;
    final userEmail = user.email ?? "";

    final orgSnapshot = await orgRef.get();

    if (orgSnapshot.exists) {
      final adminEmail = orgSnapshot.data()?['adminEmail'];
      // 🔔 Send email to existing admin
      await _functions.httpsCallable('sendJoinRequest').call({
        'orgName': orgId,
        'userEmail': userEmail,
        'adminEmail': adminEmail,
      });
    } else {
      // 🏢 Create new org and assign current user as admin
      final newOrg = Organization(
        id: orgId,
        name: orgNameInput,
        adminUserId: userId,
        adminEmail: userEmail,
        createdAt: DateTime.now(),
        businessEmail: '',
        website: '',
        address: '',
        logoUrl: '',
        phoneNumber: '',
      );
      await orgRef.set(newOrg.toMap());

      // 🔄 Update user role and orgId
      await _userService.updateUser(userId, {'role': 'admin', 'orgId': orgId});
    }
  }
}
