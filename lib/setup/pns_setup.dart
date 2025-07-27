import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../model/productservice.dart';

class ProductsServicesSetupPage extends StatefulWidget {
  const ProductsServicesSetupPage({super.key});

  @override
  State<ProductsServicesSetupPage> createState() =>
      _ProductsServicesSetupPageState();
}

class _ProductsServicesSetupPageState extends State<ProductsServicesSetupPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ProductService> _items = [];
  bool _loading = false;
  String? _error;
  String? _orgId;
  String _selectedCategory = 'All';
  String _selectedType = 'All';
  final List<String> _categories = [
    'All',
    'Electronics',
    'Clothing',
    'Food',
    'Consulting',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrganizationProducts();
  }

  Future<void> _loadOrganizationProducts() async {
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

      // Load products/services
      final query = _firestore
          .collection('products_services')
          .where('orgId', isEqualTo: _orgId)
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      _items = snapshot.docs
          .map((doc) => ProductService.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleItemStatus(ProductService item) async {
    try {
      await _firestore.collection('products_services').doc(item.id).update({
        'isActive': !item.isActive,
      });
      await _loadOrganizationProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _firestore.collection('products_services').doc(id).delete();
      await _loadOrganizationProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: ${e.toString()}')),
      );
    }
  }

  void _navigateToEditPage([ProductService? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditProductServicePage(orgId: _orgId!, existingItem: item),
      ),
    );

    if (result == true) {
      await _loadOrganizationProducts();
    }
  }

  List<ProductService> get _filteredItems {
    return _items.where((item) {
      final categoryMatch =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final typeMatch =
          _selectedType == 'All' ||
          (_selectedType == 'Products' && !item.isService) ||
          (_selectedType == 'Services' && item.isService);
      return categoryMatch && typeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrganizationProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditPage(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: ['All', 'Products', 'Services'].map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedType = value!);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text(_error!))
          else if (_items.isEmpty)
            const Expanded(
              child: Center(child: Text('No products or services found')),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return _buildItemCard(item);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ProductService item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: Icon(item.isService ? Icons.work : Icons.shopping_bag),
        ),
        title: Text(item.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 4),
            Text(
              '\$${item.price.toStringAsFixed(2)} • ${item.category}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isActive ? Icons.toggle_on : Icons.toggle_off,
                color: item.isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleItemStatus(item),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditPage(item);
                } else if (value == 'delete') {
                  _confirmDelete(item.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class AddEditProductServicePage extends StatefulWidget {
  final String orgId;
  final ProductService? existingItem;

  const AddEditProductServicePage({
    required this.orgId,
    this.existingItem,
    super.key,
  });

  @override
  State<AddEditProductServicePage> createState() =>
      _AddEditProductServicePageState();
}

class _AddEditProductServicePageState extends State<AddEditProductServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  var _categoryController = TextEditingController();

  bool _isService = false;
  bool _isActive = true;
  bool _loading = false;
  String? _error;

  final List<String> _categories = [
    'Electronics',
    'Clothing',
    'Food',
    'Consulting',
    'Maintenance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _descriptionController.text = item.description;
      _priceController.text = item.price.toStringAsFixed(2);
      _categoryController.text = item.category;
      _isService = item.isService;
      _isActive = item.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final price = double.tryParse(_priceController.text) ?? 0;

      final item = ProductService(
        id:
            widget.existingItem?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        orgId: widget.orgId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        category: _categoryController.text.trim(),
        isService: _isService,
        createdAt: widget.existingItem?.createdAt ?? DateTime.now(),
        isActive: _isActive,
      );

      await FirebaseFirestore.instance
          .collection('products_services')
          .doc(item.id)
          .set(item.toMap());

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Add New Item' : 'Edit Item'),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price*',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _categories;
                  }
                  return _categories.where(
                    (category) => category.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      _categoryController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Category*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: SizedBox(
                        width: 250, // Adjust width as needed
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('This is a service'),
                value: _isService,
                onChanged: (value) => setState(() => _isService = value),
              ),
              if (widget.existingItem != null)
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(
                        widget.existingItem == null
                            ? 'ADD ITEM'
                            : 'UPDATE ITEM',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
