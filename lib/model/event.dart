import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  String? id;
  final String title;
  final String description;
  final DateTime from;
  final DateTime to;
  final bool isAllDay;
  final String? color;

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.from,
    required this.to,
    this.isAllDay = false,
    this.color,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      from: (data['from'] as Timestamp).toDate(),
      to: (data['to'] as Timestamp).toDate(),
      isAllDay: data['isAllDay'] ?? false,
      color: data['color'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'from': Timestamp.fromDate(from),
      'to': Timestamp.fromDate(to),
      'isAllDay': isAllDay,
      'color': color,
    };
  }
}
