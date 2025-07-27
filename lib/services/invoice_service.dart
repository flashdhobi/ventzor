import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/model/invoice.dart';

class InvoiceRepository {
  final CollectionReference _invoicesCollection = FirebaseFirestore.instance
      .collection('invoices');

  Stream<List<Invoice>> getInvoices() {
    return _invoicesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  Future<void> addInvoice(Invoice invoice) {
    return _invoicesCollection.add(invoice.toFirestore());
  }

  Future<void> updateInvoice(Invoice invoice) {
    return _invoicesCollection.doc(invoice.id).update(invoice.toFirestore());
  }

  Future<void> deleteInvoice(String id) {
    return _invoicesCollection.doc(id).delete();
  }
}
