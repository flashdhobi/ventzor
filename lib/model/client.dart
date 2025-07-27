import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String orgId;
  final String name;
  final String email;
  final String phone;
  final String? company;
  final String? address;
  final String status; // 'lead' or 'customer'
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastContacted;

  Client({
    required this.id,
    required this.orgId,
    required this.name,
    required this.email,
    required this.phone,
    this.company,
    this.address,
    required this.status,
    this.notes,
    required this.createdAt,
    this.lastContacted,
  });

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'name': name,
      'email': email,
      'phone': phone,
      'company': company,
      'address': address,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastContacted': lastContacted != null
          ? Timestamp.fromDate(lastContacted!)
          : null,
    };
  }

  factory Client.fromMap(String id, Map<String, dynamic> map) {
    return Client(
      id: id,
      orgId: map['orgId'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      company: map['company'],
      address: map['address'],
      status: map['status'],
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastContacted: map['lastContacted'] != null
          ? (map['lastContacted'] as Timestamp).toDate()
          : null,
    );
  }
}
