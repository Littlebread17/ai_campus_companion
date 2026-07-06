import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _service = FirestoreService();
  final _message = TextEditingController();

  static const _categories = ['Suggestion', 'Bug', 'Praise', 'Other'];
  String _category = 'Suggestion';
  int _rating = 0;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _toast('Please tap a star to rate your experience.');
      return;
    }
    if (_message.text.trim().isEmpty) {
      _toast('Please write a short message.');
      return;
    }

    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    String name = user?.email ?? 'Student';
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      name = (profile.data()?['name'] ?? name).toString();
    } catch (_) {}

    try {
      await _service.addFeedback(
        userId: user?.uid ?? '',
        name: name,
        email: user?.email ?? '',
        category: _category,
        rating: _rating,
        message: _message.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Could not send: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: _done ? _successView() : _formView(),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xffdcfce7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xff16a34a),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thank you!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your feedback has been sent to the team. We read every message.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff64748b)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Share your feedback',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Help us improve AI Campus Companion.',
          style: TextStyle(color: Color(0xff64748b)),
        ),
        const SizedBox(height: 24),

        const Text(
          'How is your experience?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return IconButton(
              onPressed: () => setState(() => _rating = i + 1),
              iconSize: 40,
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled ? const Color(0xfff59e0b) : const Color(0xffcbd5e1),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final selected = c == _category;
            return ChoiceChip(
              label: Text(c),
              selected: selected,
              showCheckmark: false,
              selectedColor: const Color(0xff2563eb),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xff334155),
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected
                    ? const Color(0xff2563eb)
                    : const Color(0xffdbe5f2),
              ),
              onSelected: (_) => setState(() => _category = c),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        const Text('Message', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Tell us what you think…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_saving ? 'Sending' : 'Send feedback'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
