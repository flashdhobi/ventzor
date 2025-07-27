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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadOrganization();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      _isAdmin = userDoc.data()?['role'] == 'admin';
    });
  }

  Future<void> _loadOrganization() async {
    setState(() {
      _loadingOrg = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final orgId = userDoc.data()?['orgId'];
      if (orgId == null || orgId.isEmpty) {
        throw Exception("No organization assigned to this user");
      }

      final org = await OrgService().getOrganizationById(orgId);
      setState(() {
        _organization = org;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _loadingOrg = false;
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadOrganization(), _checkAdminStatus()]);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Profile', style: theme.textTheme.titleLarge),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: Text('Email: ${user?.email ?? "Unknown"}'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: Text('Role: ${_isAdmin ? 'Admin' : 'Member'}'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Organization Section
              if (_loadingOrg)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                _buildErrorCard()
              else if (_organization != null)
                _buildOrganizationCard()
              else
                _buildNoOrganizationCard(),

              const SizedBox(height: 24),

              // Action Buttons
              if (_isAdmin)
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).pushNamed('/organizationSetup');
                    _refresh();
                  },
                  child: const Text('Manage Organization'),
                ),

              const SizedBox(height: 24),

              // Action Buttons
              if (_isAdmin)
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(
                      context,
                    ).pushNamed('/productServiceSetup');
                    _refresh();
                  },
                  child: const Text('Manage Products and Services'),
                ),

              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _refresh, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_organization!.logoUrl != null &&
                    _organization!.logoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _organization!.logoUrl!,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _organization!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildDetailItem(Icons.location_on, _organization!.address),
            _buildDetailItem(Icons.phone, _organization!.phoneNumber),
            _buildDetailItem(Icons.email, _organization!.businessEmail),
            _buildDetailItem(Icons.language, _organization!.website),
            if (_isAdmin)
              Text(
                'Admin: ${_organization!.adminEmail}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOrganizationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.business, size: 40),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'No organization found. Please set up your organization.'
                  : 'You are not assigned to any organization yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }
}
