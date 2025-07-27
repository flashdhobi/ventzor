import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';

import '../../model/organization.dart';
import '../../services/org_service.dart';
import '../../services/user_service.dart';

class OrganizationSetupPage extends StatefulWidget {
  const OrganizationSetupPage({super.key});

  @override
  State<OrganizationSetupPage> createState() => _OrganizationFormScreenState();
}

class _OrganizationFormScreenState extends State<OrganizationSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _logoFile;
  Uint8List? _logoBytes;
  String? _logoFileName;
  String? _logoUrl;
  bool _isLogoChanged = false;

  String? _error;
  bool _loading = false;
  bool _isEditMode = false;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _loadOrgIfExists();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgIfExists() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ventzorUser = await UserService().getUser(user.uid);
      final orgId = ventzorUser?.orgId;

      if (orgId != null) {
        final org = await OrgService().getOrganizationById(orgId);
        if (org != null) {
          setState(() {
            _orgId = orgId;
            _isEditMode = true;
            _nameController.text = org.name;
            _addressController.text = org.address;
            _phoneController.text = org.phoneNumber;
            _websiteController.text = org.website;
            _emailController.text = org.businessEmail;
            _logoUrl = org.logoUrl;
          });
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to load organization data');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _logoBytes = result.files.single.bytes;
          _logoFileName = result.files.single.name;
          _isLogoChanged = true;
          if (!kIsWeb) {
            _logoFile = File(result.files.single.path!);
          }
        });
        _showSnackBar('Logo selected');
      } else {
        _showSnackBar('No file selected');
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<String?> _uploadLogo(String orgId) async {
    if (!_isLogoChanged) return _logoUrl;
    if (_logoBytes == null) return null;

    setState(() => _loading = true);
    try {
      final fileName =
          _logoFileName ?? 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance
          .ref()
          .child('org_logos')
          .child(orgId)
          .child(fileName);

      await ref.putData(_logoBytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      _showSnackBar('Failed to upload logo');
      return null;
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orgId = _isEditMode
          ? _orgId!
          : _generateOrgId(_nameController.text);
      final orgRef = FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId);

      if (!_isEditMode) {
        final exists = await orgRef.get();
        if (exists.exists) {
          throw Exception('Organization with this name already exists');
        }
      }

      final uploadedLogoUrl = await _uploadLogo(orgId);

      final org = Organization(
        id: orgId,
        name: _nameController.text.trim(),
        adminUserId: user.uid,
        adminEmail: user.email ?? '',
        createdAt: DateTime.now(),
        address: _addressController.text.trim(),
        businessEmail: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        logoUrl: uploadedLogoUrl ?? _logoUrl ?? '',
        phoneNumber: _phoneController.text.trim(),
      );

      await orgRef.set(org.toMap(), SetOptions(merge: true));

      // Update user's org reference
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'orgId': orgId,
        'role': 'admin',
      }, SetOptions(merge: true));

      if (context.mounted) {
        Navigator.of(context).pop(true);
        _showSnackBar(
          'Organization ${_isEditMode ? 'updated' : 'created'} successfully',
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _generateOrgId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_')
        .substring(0, name.length.clamp(0, 20));
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildLogoPreview() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _logoBytes != null
              ? Image.memory(_logoBytes!, fit: BoxFit.cover)
              : _logoUrl != null && _logoUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(_logoUrl!, fit: BoxFit.cover),
                )
              : const Center(
                  child: Icon(Icons.image, size: 40, color: Colors.grey),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          _logoFileName ??
              (_logoUrl != null ? 'Current logo' : 'No logo selected'),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Organization' : 'Create Organization'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
              tooltip: 'Delete Organization',
            ),
        ],
      ),
      body: _loading && !_isEditMode
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        labelText: 'Organization Name*',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Required field' : null,
                      enabled: !_isEditMode,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Business Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isNotEmpty && !value.contains('@')) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        border: OutlineInputBorder(),
                        prefixText: 'https://',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),
                    Center(child: _buildLogoPreview()),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Text(
                              _isEditMode
                                  ? 'UPDATE ORGANIZATION'
                                  : 'CREATE ORGANIZATION',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Organization?'),
        content: const Text(
          'This will permanently delete all organization data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteOrganization();
    }
  }

  Future<void> _deleteOrganization() async {
    setState(() => _loading = true);
    try {
      // Delete organization document
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_orgId)
          .delete();

      // Remove org reference from users
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'orgId': FieldValue.delete(),
              'role': FieldValue.delete(),
            });
      }

      // Delete logo from storage if exists
      if (_logoUrl != null && _logoUrl!.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(_logoUrl!).delete();
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        _showSnackBar('Organization deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to delete organization');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
