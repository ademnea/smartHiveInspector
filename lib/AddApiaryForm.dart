import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:HPGM/Services/auth_manager.dart';
import 'package:HPGM/Services/connectivity_service.dart';
import 'services/token_storage.dart';
import 'package:HPGM/Services/apiary_queue_service.dart';

class AddApiaryForm extends StatefulWidget {
  final VoidCallback onApiaryAdded;

  const AddApiaryForm({super.key, required this.onApiaryAdded});

  @override
  State<AddApiaryForm> createState() => _AddApiaryFormState();
}

class _AddApiaryFormState extends State<AddApiaryForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      appBar: AppBar(
        title: const Text(
          'Add New Apiary',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: "Sans",
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Basic Information'),

              _buildTextField('Name', _nameController, hint: 'Apiary name'),
              const SizedBox(height: 20),

              _buildSectionHeader('Location Details'),
              _buildTextField(
                'District',
                _districtController,
                hint: 'District',
              ),
              _buildTextField(
                'Address',
                _addressController,
                hint: 'Detailed address',
              ),
              _buildTextField(
                'Latitude',
                _latitudeController,
                hint: 'Latitude coordinates',
                isNumeric: true,
              ),
              _buildTextField(
                'Longitude',
                _longitudeController,
                hint: 'Longitude coordinates',
                isNumeric: true,
              ),
              const SizedBox(height: 20),

              _buildSectionHeader('Additional Information'),
              _buildTextField(
                'Description',
                _descriptionController,
                hint: 'Description (optional)',
                isRequired: false,
              ),
              const SizedBox(height: 30),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isLoading ? null : _submitForm,
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'SUBMIT APIARY',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: "Sans",
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.orange[700]?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[700]!.withOpacity(0.3)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.brown[800],
          fontFamily: "Sans",
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isNumeric = false,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType:
            isNumeric
                ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
                : TextInputType.text,
        style: const TextStyle(fontFamily: "Sans"),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.brown[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.brown[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.brown[600], fontFamily: "Sans"),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          if (isNumeric && value != null && value.isNotEmpty) {
            final parsed = double.tryParse(value);
            if (parsed == null) {
              return 'Please enter a valid number';
            }
            final normalizedLabel = label.toLowerCase();
            if (normalizedLabel == 'latitude' &&
                (parsed < -90 || parsed > 90)) {
              return 'Latitude must be between -90 and 90';
            }
            if (normalizedLabel == 'longitude' &&
                (parsed < -180 || parsed > 180)) {
              return 'Longitude must be between -180 and 180';
            }
          }
          return null;
        },
      ),
    );
  }

  Future<int?> _loadCurrentUserId() async {
    final storedUserId = await TokenStorage.getUserId();
    if (storedUserId == null || storedUserId.trim().isEmpty) {
      return null;
    }

    return int.tryParse(storedUserId.trim());
  }

  Map<String, dynamic> _buildApiaryPayload(int ownerId) {
    final description = _descriptionController.text.trim();

    return {
      'ownerId': ownerId,
      'name': _nameController.text.trim(),
      'district': _districtController.text.trim(),
      'address': _addressController.text.trim(),
      'latitude': double.parse(_latitudeController.text.trim()),
      'longitude': double.parse(_longitudeController.text.trim()),
      'description': description,
    };
  }

  String _extractErrorMessage(String responseBody, int statusCode) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
        if (message is List && message.isNotEmpty) {
          return message.join(', ');
        }
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      // Fall back to a generic message if the response is not JSON.
    }

    return 'Failed with status $statusCode';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUserId = await _loadCurrentUserId();
    if (currentUserId == null || currentUserId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error: User not properly authenticated',
            style: TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    final apiaryData = _buildApiaryPayload(currentUserId);

    // Check connectivity before submitting
    final isConnected = await ConnectivityService().hasInternetConnection();
    if (!isConnected) {
      // Queue the add action
      await ApiaryQueueService.addToQueue(
        ApiaryQueueItem(actionType: ApiaryActionType.add, data: apiaryData),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No internet. Apiary will be added automatically when online.',
            style: TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => _isLoading = false);
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Sending data: $apiaryData');
      final response = await AuthManager.post(
        'http://196.43.168.57/api/v1/farms',
        body: apiaryData,
        context: context,
        headers: {'Accept': 'application/json'},
      );

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please log in to continue',
              style: TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        // Success - show confirmation and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Apiary added successfully!',
              style: TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        widget.onApiaryAdded();
        print('Apiary added successfully with owner id ');
        Navigator.pop(context);
      } else {
        final errorMsg = _extractErrorMessage(
          response.body,
          response.statusCode,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMsg',
              style: const TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
