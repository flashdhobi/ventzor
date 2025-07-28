import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/miscscreens/pdf_viewer.dart';
import 'package:ventzor/model/quote.dart';
import 'package:ventzor/quotes/create_quote_screen.dart';
import 'package:ventzor/quotes/quote_details.dart';
import 'package:ventzor/services/pdf_service.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Quote> _quotes = [];
  bool _loading = false;
  String? _error;
  String? _orgId;
  String _selectedStatus = 'All';
  final List<String> _statusOptions = [
    'All',
    'draft',
    'sent',
    'accepted',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get user's organization ID
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      _orgId = userDoc.data()?['orgId'];
      if (_orgId == null) throw Exception('No organization assigned');

      // Load quotes
      Query query = _firestore
          .collection('quotes')
          .where('orgId', isEqualTo: _orgId)
          .orderBy('createdAt', descending: true);

      if (_selectedStatus != 'All') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }

      final snapshot = await query.get();
      _quotes = snapshot.docs
          .map(
            (doc) => Quote.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateQuoteStatus(String quoteId, String newStatus) async {
    try {
      await _firestore.collection('quotes').doc(quoteId).update({
        'status': newStatus,
      });
      await _loadQuotes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteQuote(String id) async {
    try {
      await _firestore.collection('quotes').doc(id).delete();
      await _loadQuotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: ${e.toString()}')),
      );
    }
  }

  void _navigateToCreatePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateQuotePage(orgId: _orgId!)),
    );

    if (result == true) {
      await _loadQuotes();
    }
  }

  void _viewQuoteDetails(Quote quote) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuoteDetailsPage(quote: quote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePage,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              items: _statusOptions.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status[0].toUpperCase() + status.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value!);
                _loadQuotes();
              },
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text(_error!))
          else if (_quotes.isEmpty)
            const Expanded(child: Center(child: Text('No quotes found')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _quotes.length,
                itemBuilder: (context, index) {
                  final quote = _quotes[index];
                  return _buildQuoteCard(quote);
                },
              ),
            ),
        ],
      ),
    );
  }

  final PDFService _pdfService = PDFService();

  Future<void> _generatePdf(Quote quote) async {
    final user = _auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfUrl = await _pdfService.generateQuotePdf(quote.id, quote.orgId);

      Navigator.pop(context); // Close loading dialog

      if (pdfUrl != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF generated successfully!')));
        // Refresh the quotes list
        setState(() {});
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    }
  }

  void _viewPdf(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PDFViewerPage(pdfUrl: url)),
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    final statusColor = _getStatusColor(quote.status);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _viewQuoteDetails(quote),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quote #${quote.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quote.status[0].toUpperCase() + quote.status.substring(1),
                      style: TextStyle(color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Client: ${quote.clientName}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${dateFormat.format(quote.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Total: ${currencyFormat.format(quote.total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (quote.expiryDate != null)
                Text(
                  'Expires: ${dateFormat.format(quote.expiryDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: quote.expiryDate!.isBefore(DateTime.now())
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              const SizedBox(height: 8),

              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (quote.pdfUrl != null)
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf),
                      onPressed: () => _viewPdf(quote.pdfUrl!),
                      tooltip: 'View PDF',
                    )
                  else
                    ElevatedButton(
                      child: Text('Generate PDF'),
                      onPressed: () => _generatePdf(quote),
                    ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _viewQuoteDetails(quote),
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      if (quote.status == 'draft')
                        const PopupMenuItem(
                          value: 'mark_sent',
                          child: Text('Mark as Sent'),
                        ),
                      if (quote.status == 'sent') ...[
                        const PopupMenuItem(
                          value: 'mark_accepted',
                          child: Text('Mark as Accepted'),
                        ),
                        const PopupMenuItem(
                          value: 'mark_rejected',
                          child: Text('Mark as Rejected'),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'mark_sent') {
                        _updateQuoteStatus(quote.id, 'sent');
                      } else if (value == 'mark_accepted') {
                        _updateQuoteStatus(quote.id, 'accepted');
                      } else if (value == 'mark_rejected') {
                        _updateQuoteStatus(quote.id, 'rejected');
                      } else if (value == 'delete') {
                        _confirmDelete(quote.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.blue;
      case 'sent':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this quote?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteQuote(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
