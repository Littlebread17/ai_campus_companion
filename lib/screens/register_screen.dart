import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _RegisterScreenState(); }

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final nameController = TextEditingController(); final studentIdController = TextEditingController(); final programmeController = TextEditingController(); final yearController = TextEditingController(); final emailController = TextEditingController(); final passwordController = TextEditingController();
  bool isLoading = false;
  Future<void> register() async {
    if ([nameController, studentIdController, programmeController, yearController, emailController, passwordController].any((c) => c.text.isEmpty)) { showMessage('Please fill in all fields.'); return; }
    if (passwordController.text.length < 6) { showMessage('Password must be at least 6 characters.'); return; }
    setState(() => isLoading = true);
    final error = await _authService.registerUser(name: nameController.text, email: emailController.text, password: passwordController.text, studentId: studentIdController.text, programme: programmeController.text, year: yearController.text);
    if (!mounted) return; setState(() => isLoading = false);
    if (error != null) { showMessage(error); } else { showMessage('Account registered successfully.'); Navigator.pop(context); }
  }
  void showMessage(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }
  Widget input(TextEditingController c, String label, IconData icon, {bool obscure = false}) => Padding(padding: const EdgeInsets.only(bottom: 14), child: TextField(controller: c, obscureText: obscure, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon))));
  @override void dispose(){ for(final c in [nameController,studentIdController,programmeController,yearController,emailController,passwordController]){c.dispose();} super.dispose(); }
  @override Widget build(BuildContext context){ return Scaffold(backgroundColor: const Color(0xfff4f7fb), appBar: AppBar(title: const Text('Register Account')), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
    const Icon(Icons.person_add, size: 70, color: Colors.blue), const SizedBox(height: 12), const Text('Create Student Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 24),
    input(nameController, 'Full Name', Icons.person), input(studentIdController, 'Student ID', Icons.badge), input(programmeController, 'Programme', Icons.school), input(yearController, 'Year', Icons.calendar_month), input(emailController, 'Email', Icons.email), input(passwordController, 'Password', Icons.lock, obscure: true),
    const SizedBox(height: 8), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : register, child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register'))),
  ]))))); }
}
