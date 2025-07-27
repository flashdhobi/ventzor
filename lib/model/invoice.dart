import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  String? id;
  final String orgId;
  final String clientId;
  final String invoiceNumber;
  final String clientName;
  final DateTime date;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final double taxRate;
  final String notes;

  Invoice({
    this.id,
    required this.orgId,
    required this.clientId,
    required this.invoiceNumber,
    required this.clientName,
    required this.date,
    required this.dueDate,
    required this.items,
    this.taxRate = 0.0,
    this.notes = '',
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get tax => subtotal * taxRate / 100;
  double get total => subtotal + tax;

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Invoice(
      id: doc.id,
      orgId: data['orgId'],
      clientId: data['clientId'],
      invoiceNumber: data['invoiceNumber'] ?? '',
      clientName: data['clientName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      items: (data['items'] as List)
          .map((item) => InvoiceItem.fromMap(item))
          .toList(),
      taxRate: data['taxRate']?.toDouble() ?? 0.0,
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'orgId': orgId,
      'clientId': clientId,
      'clientName': clientName,
      'date': Timestamp.fromDate(date),
      'dueDate': Timestamp.fromDate(dueDate),
      'items': items.map((item) => item.toMap()).toList(),
      'taxRate': taxRate,
      'notes': notes,
    };
  }
}

class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: map['description'],
      quantity: map['quantity']?.toDouble() ?? 0.0,
      unitPrice: map['unitPrice']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}
