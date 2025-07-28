import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final String id;
  final String orgId;
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isService; // true for service, false for product
  final String? imageUrl;
  final DateTime createdAt;
  final bool isActive;

  ProductService({
    required this.id,
    required this.orgId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isService,
    this.imageUrl,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'isService': isService,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  factory ProductService.fromMap(String id, Map<String, dynamic> map) {
    return ProductService(
      id: id,
      orgId: map['orgId'],
      name: map['name'],
      description: map['description'],
      price: map['price'].toDouble(),
      category: map['category'],
      isService: map['isService'],
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive: map['isActive'],
    );
  }
}

extension ProductServiceExtension on ProductService {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'isService': isService,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
