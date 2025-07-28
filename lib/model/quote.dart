import 'package:cloud_firestore/cloud_firestore.dart';

class Quote {
  final String id;
  final String orgId;
  final String clientId;
  final String clientName;
  final String status; // 'draft', 'sent', 'accepted', 'rejected'
  final List<QuoteItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final String? discountCode;
  final double total;
  final String? notes;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final String? createdBy;
  final String? pdfUrl;
  final DateTime? pdfGeneratedAt;

  Quote({
    required this.id,
    required this.orgId,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.notes,
    this.discount = 0,
    this.discountCode,
    required this.createdAt,
    this.expiryDate,
    this.createdBy,
    this.pdfUrl,
    this.pdfGeneratedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'clientId': clientId,
      'clientName': clientName,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'createdBy': createdBy,
    };
  }

  factory Quote.fromMap(String id, Map<String, dynamic> map) {
    return Quote(
      id: id,
      orgId: map['orgId'],
      clientId: map['clientId'],
      clientName: map['clientName'],
      status: map['status'],
      items: List<QuoteItem>.from(
        map['items'].map((item) => QuoteItem.fromMap(item)),
      ),
      subtotal: map['subtotal'].toDouble(),
      tax: map['tax'].toDouble(),
      total: map['total'].toDouble(),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      createdBy: map['createdBy'],
      pdfUrl: map['pdfUrl'],
      pdfGeneratedAt: map['pdfGeneratedAt']?.toDate(),
    );
  }

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    Map map = doc.data() as Map;
    return Quote(
      id: doc.id,
      orgId: map['orgId'],
      clientId: map['clientId'],
      clientName: map['clientName'],
      status: map['status'],
      items: List<QuoteItem>.from(
        map['items'].map((item) => QuoteItem.fromMap(item)),
      ),
      subtotal: map['subtotal'].toDouble(),
      tax: map['tax'].toDouble(),
      total: map['total'].toDouble(),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      createdBy: map['createdBy'],
      pdfUrl: map['pdfUrl'],
      pdfGeneratedAt: map['pdfGeneratedAt']?.toDate(),
    );
  }
}

class QuoteItem {
  final String itemId;
  final String name;
  final String description;
  final double price;
  final int quantity;
  final bool isService;

  QuoteItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.isService,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'isService': isService,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      itemId: map['itemId'],
      name: map['name'],
      description: map['description'],
      price: map['price'].toDouble(),
      quantity: map['quantity'],
      isService: map['isService'],
    );
  }

  double get lineTotal => price * quantity;
}

extension QuoteItemExtension on QuoteItem {
  QuoteItem copyWith({
    String? itemId,
    String? name,
    String? description,
    double? price,
    int? quantity,
    bool? isService,
  }) {
    return QuoteItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isService: isService ?? this.isService,
    );
  }
}
