import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'main_shell_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: authService.profileChanges(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.data?.exists == true) {
              return const MainShellScreen();
            }
            return _EmailVerificationScreen(
              email: user.email ?? 'your student email',
            );
          },
        );
      },
    );
  }
}

class _EmailVerificationScreen extends StatefulWidget {
  const _EmailVerificationScreen({required this.email});

  final String email;

  @override
  State<_EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<_EmailVerificationScreen> {
  final _authService = AuthService();
  bool _checking = false;
  bool _resending = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    final error = await _authService.completeEmailVerification();
    if (!mounted) return;
    setState(() => _checking = false);
    if (error != null) _showMessage(error);
  }

  Future<void> _resendEmail() async {
    setState(() => _resending = true);
    final error = await _authService.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _resending = false);
    _showMessage(error ?? 'Verification email sent. Check Junk or Spam too.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify student email'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _authService.logoutUser,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.primary,
                      size: 54,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Check your inbox',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A verification link was sent to\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Delivery may take a few minutes. Check Junk or Spam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.faint, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _checking ? null : _checkVerification,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _checking
                              ? 'Checking...'
                              : 'I have verified my email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _resending ? null : _resendEmail,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _resending ? 'Sending...' : 'Resend verification email',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
