import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/signup_validation.dart';
import '../widgets/ui_kit.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _programmeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final List<int> _intakeYears;
  int? _intakeYear;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    _intakeYears = validIntakeYears(DateTime.now().year);
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _intakeYear == null) return;

    setState(() => _isLoading = true);
    final error = await _authService.registerUser(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      studentId: _studentIdController.text,
      programme: _programmeController.text,
      intakeYear: _intakeYear!,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_read_outlined,
          color: AppColors.success,
          size: 40,
        ),
        title: const Text('Verify your student email'),
        content: Text(
          'A verification link was sent to ${_emailController.text}. '
          'Verify the address before signing in.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _updateStudentEmail(String value) {
    final studentId = normalizeStudentId(value);
    _emailController.text = isValidStudentId(studentId)
        ? studentEmailForId(studentId)
        : '';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      fillColor: AppColors.surfaceSoft,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _programmeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.secondary,
                            AppColors.tertiary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.prominentRadius,
                        ),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person_add_alt_1,
                              color: AppColors.primary,
                              size: 30,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Student registration',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Use your INTI student identity.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create student account',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            decoration: _decoration(
                              'Full name',
                              Icons.person_outline,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your full name.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _studentIdController,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(9),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[iI0-9]'),
                              ),
                              TextInputFormatter.withFunction(
                                (oldValue, newValue) => newValue.copyWith(
                                  text: newValue.text.toUpperCase(),
                                ),
                              ),
                            ],
                            decoration: _decoration(
                              'Student ID',
                              Icons.badge_outlined,
                              helperText: 'Format: I followed by 8 digits',
                            ),
                            onChanged: _updateStudentEmail,
                            validator: (value) => isValidStudentId(value ?? '')
                                ? null
                                : 'Use the format I24026253.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _programmeController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoration(
                              'Programme',
                              Icons.school_outlined,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your programme.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            initialValue: _intakeYear,
                            decoration: _decoration(
                              'Intake year',
                              Icons.calendar_month_outlined,
                            ),
                            items: _intakeYears
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year,
                                    child: Text('$year'),
                                  ),
                                )
                                .toList(),
                            onChanged: (year) =>
                                setState(() => _intakeYear = year),
                            validator: (year) => year == null
                                ? 'Select your intake year.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: _decoration(
                              'Student email',
                              Icons.email_outlined,
                              helperText: '@$studentEmailDomain',
                            ),
                            validator: (email) =>
                                isValidStudentEmail(
                                  email ?? '',
                                  _studentIdController.text,
                                )
                                ? null
                                : 'Enter a valid Student ID first.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: _decoration(
                              'Password',
                              Icons.lock_outline,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value == null || value.length < 6
                                ? 'Use at least 6 characters.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmation,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: _decoration(
                              'Confirm password',
                              Icons.lock_reset_outlined,
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmation
                                    ? 'Show password confirmation'
                                    : 'Hide password confirmation',
                                onPressed: () => setState(
                                  () => _obscureConfirmation =
                                      !_obscureConfirmation,
                                ),
                                icon: Icon(
                                  _obscureConfirmation
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value != _passwordController.text
                                ? 'Passwords do not match.'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              onPressed: _isLoading ? null : _register,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: Text(
                                _isLoading
                                    ? 'Creating account...'
                                    : 'Create account',
                              ),
                            ),
                          ),
                        ],
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
