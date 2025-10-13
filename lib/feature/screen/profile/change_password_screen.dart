// lib/feature/profile/change_password_screen.dart
import 'package:flutter/material.dart';

import '../../repositories/profile_repo.dart';

class ChangePasswordScreen extends StatefulWidget {
  final ProfileRepo repo;
  const ChangePasswordScreen({super.key, required this.repo});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _pwRules(String? v) {
    final t = v ?? '';
    if (t.length < 8) return 'At least 8 characters';
    //if (!RegExp(r'[A-Z]').hasMatch(t)) return 'Include an uppercase letter';
    //if (!RegExp(r'[a-z]').hasMatch(t)) return 'Include a lowercase letter';
    //if (!RegExp(r'[0-9]').hasMatch(t)) return 'Include a number';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repo.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _current,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _new,
              decoration: const InputDecoration(labelText: 'New password'),
              obscureText: true,
              validator: _pwRules,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              obscureText: true,
              validator: (v) => v == _new.text ? null : 'Passwords do not match',
            ),
          ],
        ),
      ),
    );
  }
}
