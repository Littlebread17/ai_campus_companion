import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) { showMessage('Please fill in all fields.'); return; }
    setState(() => isLoading = true);
    final error = await _authService.loginUser(email: emailController.text, password: passwordController.text);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (error != null) showMessage(error);
  }

  void showMessage(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }
  @override void dispose() { emailController.dispose(); passwordController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xfff4f7fb), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.school, size: 76, color: Colors.blue), const SizedBox(height: 16),
      const Text('AI Campus Companion', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Student Support & Engagement App'), const SizedBox(height: 28),
      TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
      const SizedBox(height: 16),
      TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : login, child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'))),
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('No account? Register here')),
    ]))))));
  }
}
