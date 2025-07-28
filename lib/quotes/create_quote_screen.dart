import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventzor/model/client.dart';
import 'package:ventzor/model/productservice.dart';
import 'package:ventzor/model/quote.dart';

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
