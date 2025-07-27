import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/model/event.dart';

class EventRepository {
  final CollectionReference _eventsCollection = FirebaseFirestore.instance
      .collection('events');

  Stream<List<Event>> getEvents() {
    return _eventsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Event>> getEventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return _eventsCollection
        .where('from', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('from', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
        });
  }

  Future<void> addEvent(Event event) {
    return _eventsCollection.add(event.toFirestore());
  }

  Future<void> updateEvent(Event event) {
    return _eventsCollection.doc(event.id).update(event.toFirestore());
  }

  Future<void> deleteEvent(String id) {
    return _eventsCollection.doc(id).delete();
  }
}
