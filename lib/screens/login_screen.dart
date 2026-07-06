import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      showMessage('Please fill in all fields.');
      return;
    }
    setState(() => isLoading = true);
    final error = await _authService.loginUser(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!mounted) return;
    setState(() => isLoading = false);
    if (error != null) showMessage(error);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8ff),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xff2563eb),
                          Color(0xff7c3aed),
                          Color(0xff06b6d4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.auto_awesome,
                            color: Color(0xff2563eb),
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'AI Campus Companion',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your INTI student dashboard for timetable, assignments, resources, events, and Canva AI support.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Login with your school-created account.',
                            style: TextStyle(color: Color(0xff64748b)),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _decoration(
                              'Email',
                              Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: _decoration(
                              'Password',
                              Icons.lock_outline,
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xff2563eb),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: isLoading ? null : login,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Center(
                            child: Text(
                              'Student accounts are managed by the school/admin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xff64748b),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xfff8fbff),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffdbe5f2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffdbe5f2)),
      ),
    );
  }
}
