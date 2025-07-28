import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/model/client.dart';

class ClientRepository {
  final CollectionReference _clientsCollection = FirebaseFirestore.instance
      .collection('clients');

  // Create a new client
  Future<String> addClient(Client client) async {
    final docRef = await _clientsCollection.add(client.toMap());
    return docRef.id;
  }

  // Get a single client by ID
  Future<Client?> getClient(String id) async {
    final doc = await _clientsCollection.doc(id).get();
    if (doc.exists) {
      return Client.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Stream a single client by ID
  Stream<Client?> streamClient(String id) {
    return _clientsCollection.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return Client.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // Get all clients for an organization
  Future<List<Client>> getClientsByOrg(String orgId) async {
    final query = await _clientsCollection
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs
        .map(
          (doc) => Client.fromMap(doc.id, doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  // Stream all clients for an organization
  Stream<List<Client>> streamClientsByOrg(String orgId) {
    return _clientsCollection
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Client.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  // Get clients by status (lead/customer) for an organization
  Future<List<Client>> getClientsByStatus(String orgId, String status) async {
    final query = await _clientsCollection
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs
        .map(
          (doc) => Client.fromMap(doc.id, doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  // Stream clients by status (lead/customer) for an organization
  Stream<List<Client>> streamClientsByStatus(String orgId, String status) {
    return _clientsCollection
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Client.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  // Update a client
  Future<void> updateClient(Client client) async {
    await _clientsCollection.doc(client.id).update(client.toMap());
  }

  // Update specific fields of a client
  Future<void> updateClientFields({
    required String id,
    required Map<String, dynamic> fields,
  }) async {
    await _clientsCollection.doc(id).update(fields);
  }

  // Delete a client
  Future<void> deleteClient(String id) async {
    await _clientsCollection.doc(id).delete();
  }

  // Search clients by name or company
  Future<List<Client>> searchClients(String orgId, String query) async {
    final clients = await getClientsByOrg(orgId);
    return clients.where((client) {
      final nameMatch = client.name.toLowerCase().contains(query.toLowerCase());
      final companyMatch =
          client.company?.toLowerCase().contains(query.toLowerCase()) ?? false;
      return nameMatch || companyMatch;
    }).toList();
  }

  // Update last contacted timestamp
  Future<void> updateLastContacted(String clientId) async {
    await _clientsCollection.doc(clientId).update({
      'lastContacted': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Change client status (lead to customer or vice versa)
  Future<void> changeClientStatus(String clientId, String newStatus) async {
    await _clientsCollection.doc(clientId).update({'status': newStatus});
  }
}
