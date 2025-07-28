import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ventzor/model/productservice.dart';

class PnSRepository {
  final CollectionReference _productsCollection = FirebaseFirestore.instance
      .collection('products_services');

  // Add a new product/service
  Future<String> addProductService(ProductService item) async {
    try {
      final docRef = await _productsCollection.add(item.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding product/service: $e');
      rethrow;
    }
  }

  // Update an existing product/service
  Future<void> updateProductService(ProductService item) async {
    try {
      await _productsCollection.doc(item.id).update(item.toMap());
    } catch (e) {
      debugPrint('Error updating product/service: $e');
      rethrow;
    }
  }

  // Get a single product/service by ID
  Future<ProductService?> getProductService(String id) async {
    try {
      final doc = await _productsCollection.doc(id).get();
      if (doc.exists) {
        return ProductService.fromMap(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product/service: $e');
      rethrow;
    }
  }

  // Stream a single product/service
  Stream<ProductService?> streamProductService(String id) {
    return _productsCollection
        .doc(id)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return ProductService.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }
          return null;
        })
        .handleError((e) {
          debugPrint('Error streaming product/service: $e');
          return null;
        });
  }

  // Get all active products/services for an organization
  Future<List<ProductService>> getActiveProductsServices(String orgId) async {
    try {
      final query = await _productsCollection
          .where('orgId', isEqualTo: orgId)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return query.docs
          .map(
            (doc) => ProductService.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting active products/services: $e');
      rethrow;
    }
  }

  // Stream all active products/services for an organization
  Stream<List<ProductService>> streamActiveProductsServices(String orgId) {
    return _productsCollection
        .where('orgId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProductService.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        )
        .handleError((e) {
          debugPrint('Error streaming active products/services: $e');
          return [];
        });
  }

  // Get products/services by category
  Future<List<ProductService>> getProductsServicesByCategory(
    String orgId,
    String category,
  ) async {
    try {
      final query = await _productsCollection
          .where('orgId', isEqualTo: orgId)
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return query.docs
          .map(
            (doc) => ProductService.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting products/services by category: $e');
      rethrow;
    }
  }

  // Toggle active status
  Future<void> toggleActiveStatus(String id, bool isActive) async {
    try {
      await _productsCollection.doc(id).update({'isActive': isActive});
    } catch (e) {
      debugPrint('Error toggling active status: $e');
      rethrow;
    }
  }

  // Search products/services
  Future<List<ProductService>> searchProductsServices(
    String orgId,
    String query,
  ) async {
    try {
      final allItems = await getActiveProductsServices(orgId);
      return allItems.where((item) {
        final nameMatch = item.name.toLowerCase().contains(query.toLowerCase());
        final descMatch = item.description.toLowerCase().contains(
          query.toLowerCase(),
        );
        final categoryMatch = item.category.toLowerCase().contains(
          query.toLowerCase(),
        );
        return nameMatch || descMatch || categoryMatch;
      }).toList();
    } catch (e) {
      debugPrint('Error searching products/services: $e');
      rethrow;
    }
  }
}
