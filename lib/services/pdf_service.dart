// services/cloud_function_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PDFService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> generateQuotePdf(String quoteId, String orgId) async {
    try {
      // For emulator testing (optional)
      // _functions.useFunctionsEmulator('localhost', 5001);

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final result = await _functions.httpsCallable('generateQuotePdf').call(
        <String, dynamic>{'docId': quoteId, 'orgId': orgId},
      );

      return result.data['pdfUrl'] as String?;
    } on FirebaseFunctionsException catch (e) {
      print(e);
      throw _parseFirebaseError(e);
    } catch (e) {
      print(e);

      throw 'Failed to generate PDF: ${e.toString()}';
    }
  }

  String _parseFirebaseError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Authentication required';
      case 'permission-denied':
        return 'You don\'t have permission';
      case 'not-found':
        return 'Quote not found';
      default:
        return e.message ?? 'PDF generation failed';
    }
  }
}
