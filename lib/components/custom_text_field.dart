import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final String hintText;
  final Widget? suffixIcon;
  final TextInputType keyboardType; // ← added

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text, // ← added (default = text)
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType, // ← added
      decoration: InputDecoration(
        hintText: hintText,
        fillColor: Colors.brown.shade100,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(icon),
        ),
        suffixIcon: suffixIcon,
      ),
      style: const TextStyle(
        height: 1.5,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    );
  }
}
