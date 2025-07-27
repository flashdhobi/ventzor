import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ventzor/model/invoice.dart';
import 'package:ventzor/services/invoice_service.dart';

class InvoiceEditScreen extends StatefulWidget {
  final Invoice? invoice;

  const InvoiceEditScreen({super.key, this.invoice});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _orgId;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _invoiceNumberController;
  late TextEditingController _clientNameController;
  late DateTime _date;
  late DateTime _dueDate;
  late double _taxRate;
  late String _notes;
  late List<InvoiceItem> _items;

  @override
  void initState() {
    super.initState();
    _initInvoice();
  }

  _initInvoice() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    _orgId = userDoc.data()?['orgId'];
    if (_orgId == null) throw Exception('No organization assigned');

    final invoice = widget.invoice;
    _invoiceNumberController = TextEditingController(
      text:
          invoice?.invoiceNumber ??
          'INV-${DateTime.now().millisecondsSinceEpoch}',
    );
    _clientNameController = TextEditingController(
      text: invoice?.clientName ?? '',
    );
    _date = invoice?.date ?? DateTime.now();
    _dueDate = invoice?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    _taxRate = invoice?.taxRate ?? 0.0;
    _notes = invoice?.notes ?? '';
    _items = invoice?.items ?? [];
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
      orgId: _orgId,
      clientId: widget.invoice!.clientId,
      invoiceNumber: _invoiceNumberController.text,
      clientName: _clientNameController.text,
      date: _date,
      dueDate: _dueDate,
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

  @override
  Widget build(BuildContext context) {
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
              TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(labelText: 'Invoice Number'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(labelText: 'Client Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Date'),
                      subtitle: Text(DateFormat.yMd().format(_date)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => _date = date);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(DateFormat.yMd().format(_dueDate)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => _dueDate = date);
                        }
                      },
                    ),
                  ),
                ],
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Tax Rate (%)'),
                keyboardType: TextInputType.number,
                initialValue: _taxRate.toString(),
                onChanged: (value) =>
                    _taxRate = double.tryParse(value) ?? _taxRate,
              ),
              const SizedBox(height: 16),
              const Text('Items', style: TextStyle(fontSize: 18)),
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return InvoiceItemCard(
                  item: item,
                  onChanged: (updatedItem) => _updateItem(index, updatedItem),
                  onDelete: () => _removeItem(index),
                );
              }),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                onPressed: _addItem,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                initialValue: _notes,
                onChanged: (value) => _notes = value,
              ),
              const SizedBox(height: 24),
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

class InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final ValueChanged<InvoiceItem> onChanged;
  final VoidCallback onDelete;

  const InvoiceItemCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TextFormField(
              initialValue: item.description,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (value) =>
                  onChanged(item.copyWith(description: value)),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => onChanged(
                      item.copyWith(
                        quantity: double.tryParse(value) ?? item.quantity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice.toString(),
                    decoration: const InputDecoration(labelText: 'Unit Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => onChanged(
                      item.copyWith(
                        unitPrice: double.tryParse(value) ?? item.unitPrice,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension InvoiceItemCopyWith on InvoiceItem {
  InvoiceItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
  }) {
    return InvoiceItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
