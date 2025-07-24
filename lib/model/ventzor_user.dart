import 'package:cloud_firestore/cloud_firestore.dart';

class VentozerUser {
  final String uid;
  final String email;
  final String orgId;
  final String role; // 'admin' or 'member'
  final String? displayName;
  final DateTime createdAt;

  VentozerUser({
    required this.uid,
    required this.email,
    required this.orgId,
    required this.role,
    this.displayName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'orgId': orgId,
      'role': role,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory VentozerUser.fromMap(String uid, Map<String, dynamic> map) {
    return VentozerUser(
      uid: uid,
      email: map['email'],
      orgId: map['orgId'],
      role: map['role'],
      displayName: map['displayName'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
