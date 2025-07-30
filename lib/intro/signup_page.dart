import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ventzor/miscscreens/html_viewer.dart';
import 'package:ventzor/model/ventzor_user.dart';

import '../services/user_service.dart';
import '../dashboard/home_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  String? _error;

  final _auth = FirebaseAuth.instance;
  final _userService = UserService();

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      // 1. Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      final uid = user.uid;

      // 2. Create Firestore user profile (no org yet)
      final ventozerUser = VentozerUser(
        uid: uid,
        email: email,
        orgId: '', // Will be added later
        role: 'member',
        displayName: name,
        createdAt: DateTime.now(),
      );

      await _userService.createUser(ventozerUser);

      // 3. Navigate to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
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
                  : const Text('Create Account'),
            ),

            const SizedBox(height: 20),
            _buildFooterLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        const Text(
          "By signing up, you agree to our",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink("Terms & Conditions", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocalHtmlViewer(
                    filePath: "assets/html/terms_and_conditions.html",
                    screenTitle: 'Terms & Conditions',
                  ),
                ),
              );
            }),
            const Text(
              " | ",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            _buildFooterLink("Privacy Policy", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocalHtmlViewer(
                    filePath: "assets/html/privacy_policy.html",
                    screenTitle: 'Privacy Policy',
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blueAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
