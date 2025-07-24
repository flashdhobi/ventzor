import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  String? _logoUrl;
  String? _error;

  bool _loading = false;
  bool _isEditMode = false;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _loadOrgIfExists();
  }

  Future<void> _loadOrgIfExists() async {
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
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _logoFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadLogo(String orgId) async {
    if (_logoFile == null) return _logoUrl;
    final ref = FirebaseStorage.instance.ref(
      'org_logos/$orgId/logo_${DateTime.now().millisecondsSinceEpoch}',
    );
    await ref.putFile(_logoFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final website = _websiteController.text.trim();
    final email = _emailController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final orgId = _isEditMode
        ? _orgId!
        : name.toLowerCase().replaceAll(' ', '_');
    final orgRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId);

    if (!_isEditMode) {
      final exists = await orgRef.get();
      if (exists.exists) {
        setState(() {
          _error = 'Organization with this name already exists.';
          _loading = false;
        });
        return;
      }
    }

    final logoUrl = await _uploadLogo(orgId);

    final org = Organization(
      id: orgId,
      name: name,
      adminUserId: user.uid,
      adminEmail: user.email ?? '',
      createdAt: DateTime.now(),
      address: address,
      businessEmail: email,
      website: website,
      logoUrl: logoUrl ?? '',
      phoneNumber: phone,
    );

    await orgRef.set(org.toMap(), SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'orgId': orgId,
      'role': 'admin',
    }, SetOptions(merge: true));

    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Organization' : 'Create Organization'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                ),
                validator: (value) => value!.isEmpty ? 'Enter name' : null,
                enabled: !_isEditMode,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Business Email'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(labelText: 'Website'),
              ),
              const SizedBox(height: 16),

              _logoFile != null
                  ? Image.file(_logoFile!, height: 60)
                  : _logoUrl != null && _logoUrl!.isNotEmpty
                  ? Image.network(_logoUrl!, height: 60)
                  : const Icon(Icons.image, size: 60, color: Colors.grey),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.upload),
                label: const Text('Upload Logo'),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(_isEditMode ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
