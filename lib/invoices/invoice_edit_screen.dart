import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ventzor/invoices/invoice_item_card.dart';
import 'package:ventzor/model/client.dart';
import 'package:ventzor/model/invoice.dart';
import 'package:ventzor/model/job.dart';
import 'package:ventzor/model/productservice.dart';
import 'package:ventzor/services/client_service.dart';
import 'package:ventzor/services/invoice_service.dart';
import 'package:ventzor/services/job_service.dart';
import 'package:ventzor/services/pns_service.dart';

class InvoiceEditScreen extends StatefulWidget {
  final Invoice? invoice;

  const InvoiceEditScreen({super.key, this.invoice});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _invoiceNumberController;
  late TextEditingController _clientNameController;
  DateTime? _date;
  DateTime? _dueDate;
  double _taxRate = 0.0;
  String _notes = '';
  List<InvoiceItem> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _orgId;

  // Client selection
  Client? _selectedClient;
  bool _loadingClients = false;
  List<Client> _clients = [];

  // Jobs selection
  final List<Job> _completedJobs = [];
  bool _loadingJobs = false;

  // Products/Services selection
  List<ProductService> _productsServices = [];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _invoiceNumberController = TextEditingController();
    _clientNameController = TextEditingController();
    _loaduser();
    _initializeData();
  }

  Future<void> _loaduser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get user's organization ID
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      _orgId = userDoc.data()?['orgId'];
      if (_orgId == null) throw Exception('No organization assigned');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeData() async {
    try {
      // Load initial data
      await _loadClients();

      if (widget.invoice != null) {
        // Editing existing invoice
        _invoiceNumberController.text = widget.invoice!.invoiceNumber;
        _clientNameController.text = widget.invoice!.clientName;
        _date = widget.invoice!.date;
        _dueDate = widget.invoice!.dueDate;
        _taxRate = widget.invoice!.taxRate;
        _notes = widget.invoice!.notes;
        _items = widget.invoice!.items;

        // Select the client
        _selectedClient = _clients.firstWhere(
          (c) => c.id == widget.invoice!.clientId,
          orElse: () => _clients.first,
        );

        // Load completed jobs for this client
        await _loadCompletedJobs(widget.invoice!.clientId);
      } else {
        // Creating new invoice
        _invoiceNumberController.text =
            'INV-${DateTime.now().millisecondsSinceEpoch}';
        _date = DateTime.now();
        _dueDate = DateTime.now().add(const Duration(days: 30));
      }

      // Load products/services
      await _loadProductsServices();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error initializing: $e')));
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final invoice = Invoice(
      id: widget.invoice?.id,
      orgId: _orgId!,
      clientId: widget.invoice!.clientId,
      invoiceNumber: _invoiceNumberController.text,
      clientName: _clientNameController.text,
      date: _date!,
      dueDate: _dueDate!,
      items: _items,
      taxRate: _taxRate,
      notes: _notes,
    );

    final invoiceRepo = Provider.of<InvoiceRepository>(context, listen: false);
    try {
      if (invoice.id == null) {
        await invoiceRepo.addInvoice(invoice);
      } else {
        await invoiceRepo.updateInvoice(invoice);
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save invoice: $e')));
    }
  }

  Future<void> _deleteInvoice() async {
    if (widget.invoice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<InvoiceRepository>(
          context,
          listen: false,
        ).deleteInvoice(widget.invoice!.id!);
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete invoice: $e')));
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add(
        InvoiceItem(description: 'New Item', quantity: 1, unitPrice: 0),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, InvoiceItem item) {
    setState(() {
      _items[index] = item;
    });
  }

  Future<void> _loadClients() async {
    setState(() => _loadingClients = true);
    try {
      final clientRepo = Provider.of<ClientRepository>(context, listen: false);
      _clients = await clientRepo.getClientsByOrg(
        'current_org_id',
      ); // Replace with your org ID
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load clients: $e')));
    } finally {
      setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadCompletedJobs(String clientId) async {
    setState(() => _loadingJobs = true);
    try {
      final jobRepo = Provider.of<JobRepository>(context, listen: false);
      // _completedJobs = await jobRepo.getJobsByClientAndStatus(
      //   clientId,
      //   'completed',
      // );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load jobs: $e')));
    } finally {
      setState(() => _loadingJobs = false);
    }
  }

  Future<void> _loadProductsServices() async {
    setState(() => _loadingProducts = true);
    try {
      final pnsRepo = Provider.of<PnSRepository>(context, listen: false);
      _productsServices = await pnsRepo.getActiveProductsServices(
        'current_org_id',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products/services: $e')),
      );
    } finally {
      setState(() => _loadingProducts = false);
    }
  }

  void _addItemFromProduct(ProductService product) {
    setState(() {
      _items.add(
        InvoiceItem(
          description: product.name,
          quantity: 1,
          unitPrice: product.price,
        ),
      );
    });
  }

  void _addItemsFromJob(Job job) {
    // Add items from job's associated quote or manual entries
    setState(() {
      _items.add(
        InvoiceItem(
          description: job.description,
          quantity: 1,
          unitPrice: job.estimatedCost,
        ),
      );
    });
  }

  // ... (keep existing _removeItem, _updateItem, _saveInvoice, _deleteInvoice methods)

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoice == null ? 'Create Invoice' : 'Edit Invoice'),
        actions: [
          if (widget.invoice != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteInvoice,
            ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveInvoice),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client Selection
              _buildClientDropdown(),
              const SizedBox(height: 16),

              // Completed Jobs Section
              if (_selectedClient != null) _buildCompletedJobsSection(),
              const SizedBox(height: 16),

              // Products/Services Section
              _buildProductsServicesSection(),
              const SizedBox(height: 16),

              // Invoice Details
              TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(labelText: 'Invoice Number'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date'),
                      subtitle: Text(DateFormat.yMd().format(_date!)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _date = date);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(DateFormat.yMd().format(_dueDate!)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _dueDate = date);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Items List
              const Text('Invoice Items', style: TextStyle(fontSize: 18)),
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return InvoiceItemCard(
                  item: item,
                  onChanged: (updatedItem) => _updateItem(index, updatedItem),
                  onDelete: () => _removeItem(index),
                );
              }),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                initialValue: _notes,
                onChanged: (value) => _notes = value,
              ),
              const SizedBox(height: 24),

              // Totals
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTotalRow(
                        'Subtotal',
                        _items.fold(0, (sum, item) => sum + item.total),
                      ),
                      // _buildTotalRow(
                      //   'Tax (${_taxRate}%)',
                      //   _items.fold(0, (sum, item) => sum + item.total) *
                      //       _taxRate /
                      //       100,
                      // ),
                      // const Divider(),
                      // _buildTotalRow(
                      //   'Total',
                      //   _items.fold(0, (sum, item) => sum + item.total) *
                      //       (1 + _taxRate / 100),
                      //   isTotal: true,
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Client *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _loadingClients
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Client>(
                    value: _selectedClient,
                    items: _clients.map((client) {
                      return DropdownMenuItem<Client>(
                        value: client,
                        child: Text(client.name),
                      );
                    }).toList(),
                    onChanged: (client) {
                      setState(() {
                        _selectedClient = client;
                        _clientNameController.text = client?.name ?? '';
                        if (client != null) {
                          _loadCompletedJobs(client.id);
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Select a client',
                    ),
                    validator: (value) =>
                        value == null ? 'Please select a client' : null,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedJobsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Completed Jobs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _loadingJobs
                ? const Center(child: CircularProgressIndicator())
                : _completedJobs.isEmpty
                ? const Text(
                    'No completed jobs found',
                    style: TextStyle(color: Colors.grey),
                  )
                : Column(
                    children: _completedJobs.map((job) {
                      return ListTile(
                        title: Text(job.title),
                        subtitle: Text(
                          'Completed: ${DateFormat.yMd().format(job.endTime)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addItemsFromJob(job),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsServicesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Products & Services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _productsServices.isEmpty
                ? const Text(
                    'No products/services found',
                    style: TextStyle(color: Colors.grey),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _productsServices.map((item) {
                      return FilterChip(
                        label: Text('${item.name} (\$${item.price})'),
                        onSelected: (_) => _addItemFromProduct(item),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? const TextStyle(fontSize: 18) : null),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: isTotal
                ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                : null,
          ),
        ],
      ),
    );
  }
}
