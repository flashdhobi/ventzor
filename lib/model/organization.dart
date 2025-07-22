import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String name;
  final String adminEmail;
  final DateTime createdAt;

  Organization({
    required this.name,
    required this.adminEmail,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {'adminEmail': adminEmail, 'createdAt': createdAt};
  }

  static Organization fromMap(String name, Map<String, dynamic> map) {
    return Organization(
      name: name,
      adminEmail: map['adminEmail'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
