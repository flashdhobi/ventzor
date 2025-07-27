import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Job {
  String? id;
  final String title;
  final String clientId;
  final String quoteId; // Reference to the associated quote
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'scheduled', 'in-progress', 'completed', 'cancelled'
  final List<String> assignedTeamMembers;
  final String location;
  final double estimatedCost;
  final double actualCost;

  Job({
    this.id,
    required this.title,
    required this.clientId,
    required this.quoteId,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.status = 'scheduled',
    this.assignedTeamMembers = const [],
    required this.location,
    required this.estimatedCost,
    this.actualCost = 0.0,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Job(
      id: doc.id,
      title: data['title'] ?? '',
      clientId: data['clientId'] ?? '',
      quoteId: data['quoteId'] ?? '',
      description: data['description'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'scheduled',
      assignedTeamMembers: List<String>.from(data['assignedTeamMembers'] ?? []),
      location: data['location'] ?? '',
      estimatedCost: data['estimatedCost']?.toDouble() ?? 0.0,
      actualCost: data['actualCost']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'clientId': clientId,
      'quoteId': quoteId,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status,
      'assignedTeamMembers': assignedTeamMembers,
      'location': location,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
    };
  }

  Color get statusColor {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'in-progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
