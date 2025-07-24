import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ventzor/intro/login_page.dart';
import 'package:ventzor/model/organization.dart';
import '../services/org_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Organization? _organization;
  bool _loadingOrg = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrganization();
  }

  Future<void> _loadOrganization() async {
    setState(() {
      _loadingOrg = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Get orgId from user doc (assuming 'organizationId' stored)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final orgId = userDoc.data()?['orgId'];

      if (orgId != null && orgId is String && orgId.isNotEmpty) {
        final org = await OrgService().getOrganizationById(orgId);
        setState(() {
          _organization = org;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingOrg = false;
      });
    }
  }

  // Call this after returning from Org Setup page to refresh org info
  Future<void> _refresh() async {
    await _loadOrganization();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Email: ${user?.email ?? "Unknown"}',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 24),

            if (_loadingOrg)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                'Error loading organization: $_error',
                style: const TextStyle(color: Colors.red),
              )
            else if (_organization != null)
              _buildOrganizationDetails()
            else
              const Text(
                'No organization found. Please set up your organization.',
              ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                // Navigate to Organization Setup page and refresh on return
                await Navigator.of(context).pushNamed('/organizationSetup');
                _refresh();
              },
              child: const Text('Setup / Update Organization'),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false, // removes all previous routes
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Organization: ${_organization!.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Address: ${_organization!.address}'),
        const SizedBox(height: 8),
        Text('Phone: ${_organization!.phoneNumber}'),
        const SizedBox(height: 8),
        Text('Business Email: ${_organization!.businessEmail}'),
        const SizedBox(height: 8),
        Text('Website: ${_organization!.website}'),
        const SizedBox(height: 8),
        if (_organization!.logoUrl!.isNotEmpty)
          Image.network(_organization!.logoUrl!, height: 100),
      ],
    );
  }
}
