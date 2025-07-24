import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String adminEmail;
  final String adminUserId;
  final String businessEmail;
  final String website;
  final String phoneNumber;
  final String address;
  final String? logoUrl;
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.adminEmail,
    required this.adminUserId,
    required this.businessEmail,
    required this.website,
    required this.phoneNumber,
    required this.address,
    this.logoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'adminEmail': adminEmail,
      'adminUserId': adminUserId,
      'businessEmail': businessEmail,
      'website': website,
      'phoneNumber': phoneNumber,
      'address': address,
      'logoUrl': logoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Organization.fromMap(String id, Map<String, dynamic> map) {
    return Organization(
      id: id,
      name: map['name'] ?? '',
      adminEmail: map['adminEmail'] ?? '',
      adminUserId: map['adminUserId'] ?? '',
      businessEmail: map['businessEmail'] ?? '',
      website: map['website'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      logoUrl: map['logoUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
