import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:HPGM/login.dart';
import 'package:HPGM/navbar.dart';
import 'package:HPGM/services/token_storage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ── Form key ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ── UI state ──────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedRole = 'beekeeper';

  // ── API Configuration ─────────────────────────────────────
  // ⚠️ CHANGE THIS TO YOUR ACTUAL SERVER IP
  final String _baseUrl = 'http://196.43.168.57'; // Your server IP

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Register call ─────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/register'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim().toLowerCase(),
              'password': _passwordController.text,
              'password_confirmation': _confirmController.text,
              'role': _selectedRole,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      debugPrint(
        'Register response [${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Registration successful - auto login
        final token = data['token'];

        if (token != null && token.isNotEmpty) {
          // Save token using TokenStorage
          await TokenStorage.saveToken(token);

          Fluttertoast.showToast(
            msg: '✅ Account created successfully!',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => NavBar(token: token)),
            );
          }
        } else {
          // No token returned, just go to login
          Fluttertoast.showToast(
            msg: '✅ Account created! Please login.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      } else {
        final msg = _extractError(data);
        _showError(msg);
        setState(() => _isLoading = false);
      }
    } on http.ClientException {
      _showError('No internet connection. Please check your network.');
      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
      debugPrint('Register error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Extract readable error from API response ──────────────
  String _extractError(Map<String, dynamic> data) {
    if (data['errors'] != null && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    if (data['message'] != null) return data['message'].toString();
    if (data['error'] != null) return data['error'].toString();
    return 'Registration failed. Please try again.';
  }

  void _showError(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16,
    );
  }

  // ── Validators ────────────────────────────────────────────
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!ok.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!v.contains(RegExp(r'[A-Z]')))
      return 'Add at least one uppercase letter';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Add at least one number';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),

                Image.asset('lib/images/log-1.png', height: 130, width: 130),
                const SizedBox(height: 12),

                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 206, 109, 40),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign up to start monitoring your hives',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 28),

                _buildField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: _validateName,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  suffix: _eyeIcon(
                    visible: _obscurePassword,
                    onTap:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _confirmController,
                  label: 'Confirm Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  validator: _validateConfirm,
                  suffix: _eyeIcon(
                    visible: _obscureConfirm,
                    onTap:
                        () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 16),

                _buildRoleDropdown(),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 206, 109, 40),
                      disabledBackgroundColor: const Color.fromARGB(
                        150,
                        206,
                        109,
                        40,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : const Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(fontSize: 14),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color.fromARGB(255, 206, 109, 40),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable field ────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        fillColor: Colors.brown.shade100,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 206, 109, 40),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: Colors.brown),
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
    );
  }

  // ── Eye toggle ────────────────────────────────────────────
  Widget _eyeIcon({required bool visible, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off : Icons.visibility,
        color: Colors.grey,
      ),
      onPressed: onTap,
    );
  }

  // ── Role dropdown ─────────────────────────────────────────
  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.brown.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.brown),
          items: const [
            DropdownMenuItem(
              value: 'beekeeper',
              child: Row(
                children: [
                  Icon(Icons.hive, color: Colors.brown, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Beekeeper',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.brown,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _selectedRole = v);
          },
        ),
      ),
    );
  }
}
