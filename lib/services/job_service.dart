import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/model/job.dart';

class JobRepository {
  final CollectionReference _jobsCollection = FirebaseFirestore.instance
      .collection('jobs');

  Stream<List<Job>> getJobs() {
    return _jobsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Job>> getJobsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return _jobsCollection
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
        });
  }

  Future<void> addJob(Job job) {
    return _jobsCollection.add(job.toFirestore());
  }

  Future<void> updateJob(Job job) {
    return _jobsCollection.doc(job.id).update(job.toFirestore());
  }

  Future<void> deleteJob(String id) {
    return _jobsCollection.doc(id).delete();
  }

  Future<void> updateJobStatus(String id, String status) {
    return _jobsCollection.doc(id).update({'status': status});
  }
}
