import 'package:flutter/material.dart';
import '../firebase_auth_service.dart';
import '../widgets/common.dart';

enum AuthMode { login, signup, reset }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthMode _mode = AuthMode.login;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _loading = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty) {
      _toast('Enter your email.');
      return;
    }
    if (_mode != AuthMode.reset && _pass.text.length < 6) {
      _toast('Password must be at least 6 characters.');
      return;
    }
    if (_mode == AuthMode.signup && _name.text.trim().isEmpty) {
      _toast('Enter your name.');
      return;
    }
    setState(() => _loading = true);
    String? error;
    if (_mode == AuthMode.login) {
      error = await PentaAuth.signIn(_email.text, _pass.text);
    } else if (_mode == AuthMode.signup) {
      error = await PentaAuth.signUp(_name.text, _email.text, _pass.text);
    } else {
      error = await PentaAuth.sendReset(_email.text);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      _toast(error);
    } else if (_mode == AuthMode.reset) {
      _toast('Password reset email sent.');
      setState(() => _mode = AuthMode.login);
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool hide = false, TextInputType? type}) {
    return TextField(
      controller: c,
      obscureText: hide,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Welcome back';
    String button = 'Log in';
    if (_mode == AuthMode.signup) {
      title = 'Create account';
      button = 'Sign up';
    } else if (_mode == AuthMode.reset) {
      title = 'Reset password';
      button = 'Send reset email';
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Text('PENTA',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 10, color: neonCyan)),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                const SizedBox(height: 28),
                if (_mode == AuthMode.signup) ...[
                  _field(_name, 'Name', Icons.person),
                  const SizedBox(height: 14),
                ],
                _field(_email, 'Email', Icons.email, type: TextInputType.emailAddress),
                if (_mode != AuthMode.reset) ...[
                  const SizedBox(height: 14),
                  _field(_pass, 'Password', Icons.lock, hide: true),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(button),
                  ),
                ),
                const SizedBox(height: 8),
                if (_mode == AuthMode.login)
                  TextButton(
                    onPressed: () => setState(() => _mode = AuthMode.reset),
                    child: const Text('Forgot password?'),
                  ),
                TextButton(
                  onPressed: () => setState(() => _mode = _mode == AuthMode.signup ? AuthMode.login : AuthMode.signup),
                  child: Text(_mode == AuthMode.signup ? 'Already have an account? Log in' : 'New here? Sign up'),
                ),
                const SizedBox(height: 24),
                const CreditLine(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
