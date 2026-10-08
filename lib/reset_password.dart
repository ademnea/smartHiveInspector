import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/login.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Sets a new password using the token from the reset email.
///
/// The email links to /reset-password?token=…&email=…. Once the deep link is
/// registered it will open this screen with both values filled in; until
/// then the farmer can paste the token from the link.
class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? token;

  const ResetPasswordScreen({super.key, this.email, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _brand = Color.fromARGB(255, 206, 109, 40);

  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.email);
  late final _tokenController = TextEditingController(text: widget.token);
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscure = true;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final message = await FarmerApi.instance.resetPassword(
        email: _emailController.text.trim().toLowerCase(),
        token: _tokenController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: message ?? 'Password updated. Please log in.',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _serverErrors = {
          for (final field in e.errors?.keys ?? const <String>[])
            if (e.fieldError(field) != null) field: e.fieldError(field)!,
        };
      });
      if (e.status == 422 && !_serverErrors.containsKey('password')) {
        // Invalid or expired link.
        _showExpiredLink(e.message);
      } else if (_serverErrors.isEmpty) {
        Fluttertoast.showToast(
          msg: e.message,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _showExpiredLink(String message) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset link not valid'),
            content: Text(
              '$message\n\nThe link may have expired. Request a new one?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _resend();
                },
                child: const Text('Send new link'),
              ),
            ],
          ),
    );
  }

  Future<void> _resend() async {
    try {
      final message = await FarmerApi.instance.forgotPassword(
        _emailController.text.trim(),
      );
      Fluttertoast.showToast(
        msg: message ?? 'A new reset link has been sent.',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } on ApiException catch (e) {
      Fluttertoast.showToast(
        msg: e.message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the token from your reset email and choose a new password.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                _field(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  apiField: 'email',
                  keyboardType: TextInputType.emailAddress,
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Email is required'
                              : null,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _tokenController,
                  label: 'Reset token',
                  icon: Icons.vpn_key,
                  apiField: 'token',
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Paste the token from the email link'
                              : null,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _passwordController,
                  label: 'New password',
                  icon: Icons.lock,
                  apiField: 'password',
                  obscure: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _confirmController,
                  label: 'Confirm new password',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator:
                      (v) =>
                          v != _passwordController.text
                              ? 'Passwords do not match'
                              : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      disabledBackgroundColor: _brand.withAlpha(150),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : const Text(
                              'SET NEW PASSWORD',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? apiField,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure && _obscure,
      keyboardType: keyboardType,
      validator: validator,
      forceErrorText: apiField == null ? null : _serverErrors[apiField],
      onChanged:
          apiField == null || !_serverErrors.containsKey(apiField)
              ? null
              : (_) => setState(() => _serverErrors.remove(apiField)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.brown.shade100,
        prefixIcon: Icon(icon, color: Colors.brown),
        suffixIcon:
            obscure
                ? IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
                : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _brand, width: 2),
        ),
      ),
    );
  }
}
