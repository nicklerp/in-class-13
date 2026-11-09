import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await AuthService.instance.signOut();
      // AuthGate automatically shows AuthenticationScreen.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ChangePasswordDialog(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(changed == true
            ? 'Your password was updated successfully.'
            : 'Password change cancelled.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? 'No email available';
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.account_circle,
                    size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Signed in as',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 32),
                FilledButton.tonalIcon(
                  onPressed: _signingOut ? null : _showChangePasswordDialog,
                  icon: const Icon(Icons.password),
                  label: const Text('Change password'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _signingOut ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance.changePassword(
        _newPassword.text,
        currentPassword: _currentPassword.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPassword,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPassword,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Use at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassword,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  validator: (value) => value != _newPassword.text
                      ? 'Passwords do not match'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _changePassword,
            child: Text(_saving ? 'Updating...' : 'Update'),
          ),
        ],
      ),
    );
  }
}
