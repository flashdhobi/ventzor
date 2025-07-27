import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/model/quote.dart';

class QuoteRepository {
  final CollectionReference _quotesCollection = FirebaseFirestore.instance
      .collection('quotes');

  Stream<List<Quote>> getQuotes() {
    return _quotesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
    });
  }

  Stream<Quote> getQuote(String id) {
    return _quotesCollection.doc(id).snapshots().map((doc) {
      return Quote.fromFirestore(doc);
    });
  }

  Future<void> addQuote(Quote quote) {
    return _quotesCollection.add(quote.toMap());
  }

  Future<void> updateQuote(Quote quote) {
    return _quotesCollection.doc(quote.id).update(quote.toMap());
  }

  Future<void> deleteQuote(String id) {
    return _quotesCollection.doc(id).delete();
  }

  Future<void> updateQuoteStatus(String id, String status) {
    return _quotesCollection.doc(id).update({'status': status});
  }
}
