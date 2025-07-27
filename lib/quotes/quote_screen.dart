import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/miscscreens/pdf_viewer.dart';
import 'package:ventzor/model/client.dart';
import 'package:ventzor/model/productservice.dart';
import 'package:ventzor/model/quote.dart';
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

class CreateQuotePage extends StatefulWidget {
  final String orgId;

  const CreateQuotePage({required this.orgId, super.key});

  @override
  State<CreateQuotePage> createState() => _CreateQuotePageState();
}

class _CreateQuotePageState extends State<CreateQuotePage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  Client? _selectedClient;
  final List<QuoteItem> _items = [];
  DateTime? _expiryDate;
  double _taxRate = 0.10; // 10% default tax
  bool _loadingClients = false;
  bool _loadingProducts = false;
  bool _saving = false;
  String? _error;

  List<Client> _clients = [];
  List<ProductService> _productsServices = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadProductsServices();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _loadingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('orgId', isEqualTo: widget.orgId)
          .orderBy('name')
          .get();

      _clients = snapshot.docs
          .map((doc) => Client.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      setState(() => _error = 'Failed to load clients');
    } finally {
      setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadProductsServices() async {
    setState(() => _loadingProducts = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products_services')
          .where('orgId', isEqualTo: widget.orgId)
          .orderBy('name')
          .get();

      _productsServices = snapshot.docs
          .map((doc) => ProductService.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      setState(() => _error = 'Failed to load products/services');
    } finally {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() => _expiryDate = pickedDate);
    }
  }

  void _addItem(ProductService item) {
    showDialog(
      context: context,
      builder: (context) {
        final quantityController = TextEditingController(text: '1');
        return AlertDialog(
          title: Text('Add ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter quantity';
                  if (int.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price:', style: TextStyle(fontSize: 16)),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 1;
                if (quantity < 1) return;

                setState(() {
                  _items.add(
                    QuoteItem(
                      itemId: item.id,
                      name: item.name,
                      description: item.description,
                      price: item.price,
                      quantity: quantity,
                      isService: item.isService,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateItemQuantity(int index, int newQuantity) {
    setState(() {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
    });
  }

  Future<void> _saveQuote() async {
    if (_selectedClient == null) {
      setState(() => _error = 'Please select a client');
      return;
    }

    if (_items.isEmpty) {
      setState(() => _error = 'Please add at least one item');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final subtotal = _items.fold(0.0, (sum, item) => sum + item.lineTotal);
      final tax = subtotal * _taxRate;
      final total = subtotal + tax;

      final quote = Quote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orgId: widget.orgId,
        clientId: _selectedClient!.id,
        clientName: _selectedClient!.name,
        status: 'draft',
        items: _items,
        subtotal: subtotal,
        tax: tax,
        total: total,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        expiryDate: _expiryDate,
        createdBy: user?.email,
      );

      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quote.id)
          .set(quote.toMap());

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Failed to save quote: ${e.toString()}');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.lineTotal);
    final tax = subtotal * _taxRate;
    final total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveQuote,
            tooltip: 'Save Quote',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              DropdownButtonFormField<Client>(
                value: _selectedClient,
                decoration: const InputDecoration(
                  labelText: 'Client*',
                  border: OutlineInputBorder(),
                ),
                items: _clients.map((client) {
                  return DropdownMenuItem(
                    value: client,
                    child: Text(client.name),
                  );
                }).toList(),
                onChanged: (client) => setState(() => _selectedClient = client),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectExpiryDate(context),
                        ),
                      ),
                      controller: TextEditingController(
                        text: _expiryDate != null
                            ? DateFormat('MMM dd, yyyy').format(_expiryDate!)
                            : '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Tax Rate (%)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: (_taxRate * 100).toStringAsFixed(2),
                      onChanged: (value) {
                        final rate = double.tryParse(value) ?? 0;
                        setState(() => _taxRate = rate / 100);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              if (_loadingProducts)
                const Center(child: CircularProgressIndicator())
              else if (_productsServices.isEmpty)
                const Center(child: Text('No products/services available'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _productsServices.map((item) {
                    return FilterChip(
                      label: Text(item.name),
                      onSelected: (_) => _addItem(item),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              if (_items.isEmpty)
                const Center(
                  child: Text(
                    'No items added',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Column(
                  children: [
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  if (item.quantity > 1) {
                                    _updateItemQuantity(
                                      index,
                                      item.quantity - 1,
                                    );
                                  }
                                },
                              ),
                              Text(item.quantity.toString()),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  _updateItemQuantity(index, item.quantity + 1);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                          leading: Text(
                            currencyFormat.format(item.lineTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Text(currencyFormat.format(subtotal)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tax (${(_taxRate * 100).toStringAsFixed(2)}%):',
                                ),
                                Text(currencyFormat.format(tax)),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _saveQuote,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('SAVE QUOTE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuoteDetailsPage extends StatelessWidget {
  final Quote quote;

  const QuoteDetailsPage({required this.quote, super.key});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final statusColor = _getStatusColor(quote.status);

    return Scaffold(
      appBar: AppBar(title: Text('Quote #${quote.id.substring(0, 8)}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status:', style: TextStyle(fontSize: 16)),
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
                            quote.status[0].toUpperCase() +
                                quote.status.substring(1),
                            style: TextStyle(color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Client: ${quote.clientName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created: ${dateFormat.format(quote.createdAt)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (quote.expiryDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Expires: ${dateFormat.format(quote.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: quote.expiryDate!.isBefore(DateTime.now())
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ],
                    if (quote.createdBy != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Created by: ${quote.createdBy}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...quote.items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.description),
                  trailing: Text(
                    '${item.quantity} × ${currencyFormat.format(item.price)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: Text(
                    currencyFormat.format(item.lineTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text(currencyFormat.format(quote.subtotal)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tax:'),
                        Text(currencyFormat.format(quote.tax)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          currencyFormat.format(quote.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (quote.notes != null && quote.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Text(quote.notes!),
            ],
            const SizedBox(height: 32),
          ],
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
}

// Add this to your existing ProductService class if not already present
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

// Add this extension to your QuoteItem class
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
