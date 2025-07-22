import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../dashboard/home_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _orgController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final orgName = _orgController.text.trim().toLowerCase();

    setState(() {
      _loading = true;
      _error = null;
    });

    final firestore = FirebaseFirestore.instance;
    final FirebaseFunctions _functions = FirebaseFunctions.instance;

    final orgRef = firestore.collection('organizations').doc(orgName);

    try {
      final orgSnapshot = await orgRef.get();

      if (orgSnapshot.exists) {
        // 🔔 Org exists → send join request to admin
        final adminEmail = orgSnapshot.data()?['adminEmail'];

        await _functions.httpsCallable('sendJoinRequest').call({
          'orgName': orgName,
          'userEmail': email,
          'adminEmail': adminEmail,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent to admin.')),
        );
      } else {
        // ORG DOESN’T EXIST: Create user and org
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        await orgRef.set({'adminEmail': email, 'createdAt': Timestamp.now()});

        debugPrint("Org created: $orgName with admin: $email");

        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _orgController,
              decoration: const InputDecoration(labelText: 'Organization Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _signup,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
