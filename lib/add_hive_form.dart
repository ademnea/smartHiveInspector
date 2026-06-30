import 'dart:convert';

import 'package:flutter/material.dart';

import 'Services/auth_manager.dart';
import 'Services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'services/offline_queue_service.dart';

class AddHiveForm extends StatefulWidget {
  final int farmId;
  final String apiaryLocation;
  final String farmName;
  final VoidCallback onHiveAdded;

  const AddHiveForm({
    super.key,
    required this.farmId,
    required this.apiaryLocation,
    required this.farmName,
    required this.onHiveAdded,
  });

  @override
  _AddHiveFormState createState() => _AddHiveFormState();
}

class _AddHiveFormState extends State<AddHiveForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  bool _isConnected = true;
  bool _isColonized = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _longitudeController.dispose();
    _latitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      appBar: AppBar(
        title: const Text(
          'Add New Hive',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: "Sans",
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.brown[800],
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farm: ${widget.farmName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[800],
                      fontFamily: "Sans",
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Location: ${widget.apiaryLocation}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.brown[600],
                      fontFamily: "Sans",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationSection(),
                  const SizedBox(height: 25),
                  _buildStatusSection(),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hive Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.brown[800],
              fontFamily: "Sans",
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _longitudeController,
            decoration: InputDecoration(
              labelText: 'Longitude',
              labelStyle: TextStyle(
                color: Colors.brown[600],
                fontFamily: "Sans",
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.brown[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.brown[600]!, width: 2),
              ),
              prefixIcon: Icon(Icons.location_on, color: Colors.brown[600]),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter longitude';
              }
              final parsed = double.tryParse(value);
              if (parsed == null) {
                return 'Please enter a valid number';
              }
              if (parsed < -180 || parsed > 180) {
                return 'Longitude must be between -180 and 180';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _latitudeController,
            decoration: InputDecoration(
              labelText: 'Latitude',
              labelStyle: TextStyle(
                color: Colors.brown[600],
                fontFamily: "Sans",
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.brown[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.brown[600]!, width: 2),
              ),
              prefixIcon: Icon(Icons.location_on, color: Colors.brown[600]),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter latitude';
              }
              final parsed = double.tryParse(value);
              if (parsed == null) {
                return 'Please enter a valid number';
              }
              if (parsed < -90 || parsed > 90) {
                return 'Latitude must be between -90 and 90';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hive Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.brown[800],
              fontFamily: "Sans",
            ),
          ),
          const SizedBox(height: 15),
          SwitchListTile(
            title: const Text(
              'Connected',
              style: TextStyle(fontFamily: "Sans"),
            ),
            subtitle: const Text(
              'Is the hive connected to monitoring systems?',
              style: TextStyle(fontFamily: "Sans"),
            ),
            value: _isConnected,
            onChanged: (bool value) {
              setState(() {
                _isConnected = value;
              });
            },
            activeThumbColor: Colors.brown[600],
          ),
          const Divider(),
          SwitchListTile(
            title: const Text(
              'Colonized',
              style: TextStyle(fontFamily: "Sans"),
            ),
            subtitle: const Text(
              'Does the hive have an active bee colony?',
              style: TextStyle(fontFamily: "Sans"),
            ),
            value: _isColonized,
            onChanged: (bool value) {
              setState(() {
                _isColonized = value;
              });
            },
            activeThumbColor: Colors.brown[600],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
        ),
        child:
            _isSubmitting
                ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Text(
                  'Add Hive',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Sans",
                  ),
                ),
      ),
    );
  }

  Map<String, dynamic> _buildHivePayload() {
    return {
      'longitude': double.parse(_longitudeController.text.trim()),
      'latitude': double.parse(_latitudeController.text.trim()),
      'connected': _isConnected,
      'colonized': _isColonized,
      'farm_id': widget.farmId,
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
      // Ignore JSON parsing issues and use the fallback message.
    }

    return 'Failed with status $statusCode';
  }

  Future<void> _cacheCreatedHive(String responseBody) async {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final cachedHives = await CacheService.loadHives(widget.farmId) ?? [];
      cachedHives.add(decoded);
      await CacheService.saveHives(widget.farmId, cachedHives);
    } catch (_) {
      // The live server response is already authoritative; cache update is best-effort.
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final isConnected = await ConnectivityService().hasInternetConnection();
      final hiveData = _buildHivePayload();

      if (!isConnected) {
        // Queue the add hive operation for later sync
        await OfflineQueueService.queueCreateHive(hiveData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No internet connection. Hive will be added when you come back online.',
                style: TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
          widget.onHiveAdded(); // Refresh the UI
        }
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final response = await AuthManager.post(
          'http://196.43.168.57/api/v1/hives',
          body: hiveData,
          context: context,
        );

        if (response == null) {
          final stillOnline =
              await ConnectivityService().hasInternetConnection();

          if (!stillOnline) {
            await OfflineQueueService.queueCreateHive(hiveData);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Connection dropped. Hive queued for sync when online.',
                    style: TextStyle(fontFamily: "Sans"),
                  ),
                  backgroundColor: Colors.orange[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              Navigator.pop(context);
              widget.onHiveAdded();
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Request failed. Please log in again or try later.',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }

        if (response.statusCode == 201) {
          await _cacheCreatedHive(response.body);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Hive added successfully!',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            Navigator.pop(context);
            widget.onHiveAdded(); // Refresh the UI
          }
        } else {
          final errorMsg = _extractErrorMessage(
            response.body,
            response.statusCode,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to add hive: $errorMsg',
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
        }
      } catch (error) {
        print('Error adding hive: $error');

        final stillOnline = await ConnectivityService().hasInternetConnection();
        if (!stillOnline) {
          await OfflineQueueService.queueCreateHive(hiveData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Connection lost. Hive queued for sync when online.',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            Navigator.pop(context);
            widget.onHiveAdded();
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error adding hive: $error',
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
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }
}
