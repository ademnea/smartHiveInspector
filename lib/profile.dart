import 'dart:convert';

import 'package:HPGM/Services/auth_manager.dart';
import 'package:HPGM/Services/auth_services.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:HPGM/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  final String token;
  final Future<http.Response?> Function(String? storedUserId)? profileFetcher;

  const ProfileScreen({
    Key? key,
    required this.token,
    this.profileFetcher,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userId = '';
  String userName = 'Bee Keeper';
  String email = 'beekeeper@example.com';
  String role = 'user';
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _hydrateStoredProfile() async {
    final storedProfile = await TokenStorage.getStoredProfile();
    final storedUser = _extractUserMap(storedProfile);
    final storedUserId = await TokenStorage.getUserId();
    final storedName = await TokenStorage.getDisplayName();
    final storedEmail = await TokenStorage.getUsername();
    final storedRole = await TokenStorage.getRole();

    if (!mounted) return;

    setState(() {
      userId =
          storedUser?['id']?.toString().trim().isNotEmpty == true
              ? storedUser!['id'].toString().trim()
              : (storedUserId?.trim() ?? '');
      userName = _resolveDisplayName(storedUser, fallbackName: storedName);
      email = _resolveEmail(storedUser, fallbackEmail: storedEmail);
      role = _resolveRole(storedUser, fallbackRole: storedRole);
    });
  }

  String _resolveDisplayName(
    Map<String, dynamic>? user, {
    String? fallbackName,
  }) {
    final candidates = [
      user?['name'],
      user?['full_name'],
      user?['username'],
      fallbackName,
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return 'Bee Keeper';
  }

  String _resolveEmail(
    Map<String, dynamic>? user, {
    String? fallbackEmail,
  }) {
    final candidates = [
      user?['email'],
      user?['username'],
      fallbackEmail,
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return 'No email';
  }

  String _resolveRole(
    Map<String, dynamic>? user, {
    String? fallbackRole,
  }) {
    final candidates = [user?['role'], fallbackRole];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return 'user';
  }

  Future<http.Response?> _fetchProfileResponse(String? storedUserId) async {
    final userIdValue = storedUserId?.trim();
    final endpoints = <String>[
      'http://196.43.168.57/api/v1/profile',
      if (userIdValue != null && userIdValue.isNotEmpty)
        'http://196.43.168.57/api/v1/users/$userIdValue',
      if (userIdValue != null && userIdValue.isNotEmpty)
        'http://196.43.168.57/api/v1/user/$userIdValue',
      'http://196.43.168.57/api/v1/me',
      'http://196.43.168.57/api/v1/auth/me',
    ];

    http.Response? lastResponse;
    for (final endpoint in endpoints) {
      final response = await AuthManager.get(endpoint, context: context);
      if (response != null && response.statusCode == 200) {
        return response;
      }
      if (response != null) {
        lastResponse = response;
      }
    }

    return lastResponse;
  }

  Future<void> _persistResolvedProfile(Map<String, dynamic> user) async {
    final normalizedUser = Map<String, dynamic>.from(user);
    final resolvedUserId =
        normalizedUser['id']?.toString().trim().isNotEmpty == true
            ? normalizedUser['id'].toString().trim()
            : userId;
    final resolvedName = _resolveDisplayName(
      normalizedUser,
      fallbackName: userName,
    );
    final resolvedEmail = _resolveEmail(normalizedUser, fallbackEmail: email);
    final resolvedRole = _resolveRole(normalizedUser, fallbackRole: role);

    normalizedUser['id'] = resolvedUserId;
    normalizedUser['name'] = resolvedName;
    normalizedUser['email'] = resolvedEmail;
    normalizedUser['role'] = resolvedRole;

    await TokenStorage.updateStoredUserInfo(
      userId: resolvedUserId,
      username: resolvedEmail,
      displayName: resolvedName,
      role: resolvedRole,
      profile: {'user': normalizedUser},
    );
  }

  Future<void> _loadUserProfile({bool showLoader = true}) async {
    await _hydrateStoredProfile();

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }
    final storedUserId = await TokenStorage.getUserId();

    try {
      final response =
          widget.profileFetcher != null
              ? await widget.profileFetcher!(storedUserId)
              : await _fetchProfileResponse(storedUserId);

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final user = _extractUserMap(jsonDecode(response.body));
        if (user == null) {
          setState(() {
            _errorMessage = 'Invalid profile response from server.';
          });
        } else {
          final resolvedUserId =
              user['id']?.toString().trim().isNotEmpty == true
                  ? user['id'].toString().trim()
                  : (storedUserId?.trim() ?? '');
          final resolvedName = _resolveDisplayName(user, fallbackName: userName);
          final resolvedEmail = _resolveEmail(user, fallbackEmail: email);
          final resolvedRole = _resolveRole(user, fallbackRole: role);

          setState(() {
            userId = resolvedUserId;
            userName = resolvedName;
            email = resolvedEmail;
            role = resolvedRole;
            _errorMessage = null;
          });

          await _persistResolvedProfile(user);
        }
      } else {
        setState(() {
          _errorMessage = _buildProfileErrorMessage(response);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Map<String, dynamic>? _extractUserMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['user'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded['user']);
      }
      if (decoded['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      return decoded;
    }
    return null;
  }

  String _buildProfileErrorMessage(dynamic response) {
    if (response == null) {
      return 'No response from server while loading profile.';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall back to status code.
    }

    return 'Failed to load profile: HTTP ${response.statusCode}';
  }

  Future<void> _openEditProfile() async {
    final updatedUser = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              userId: userId,
              initialName: userName,
              initialEmail: email,
              currentRole: role,
            ),
      ),
    );

    if (!mounted || updatedUser == null) return;

    setState(() {
      userId = updatedUser['id']?.toString() ?? userId;
      userName = updatedUser['name']?.toString() ?? userName;
      email = updatedUser['email']?.toString() ?? email;
      role = updatedUser['role']?.toString() ?? role;
    });

    await TokenStorage.updateStoredUserInfo(
      userId: userId,
      username: email,
      displayName: userName,
      role: role,
      profile: {'user': updatedUser},
    );

    await _loadUserProfile(showLoader: false);
  }

  Future<void> _logout() async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Logout'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldLogout) return;

    try {
      await AuthService.logout();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed:
                _isLoading || _isRefreshing
                    ? null
                    : () => _loadUserProfile(showLoader: false),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.amber[100],
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.amber[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(fontSize: 16, color: Colors.brown[600]),
                    ),
                    if (userId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'User ID: $userId',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.brown[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_isRefreshing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Refreshing profile...',
                          style: TextStyle(color: Colors.brown[400]),
                        ),
                      ),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange[800],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.orange[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    _buildProfileSection(
                      title: 'Account Information',
                      icon: Icons.account_circle,
                      children: [
                        _buildProfileItem(
                          title: 'Edit Profile',
                          icon: Icons.edit,
                          onTap: _openEditProfile,
                        ),
                        _buildProfileItem(
                          title: 'Change Password',
                          icon: Icons.lock,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Change Password is not wired yet.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    _buildProfileSection(
                      title: 'App Settings',
                      icon: Icons.settings,
                      children: [
                        _buildProfileItem(
                          title: 'Notification Settings',
                          icon: Icons.notifications,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notification Settings - Coming Soon',
                                ),
                              ),
                            );
                          },
                        ),
                        _buildProfileItem(
                          title: 'Language',
                          icon: Icons.language,
                          value: 'English',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Language Settings - Coming Soon',
                                ),
                              ),
                            );
                          },
                        ),
                        _buildProfileItem(
                          title: 'Theme',
                          icon: Icons.color_lens,
                          value: 'Light',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Theme Settings - Coming Soon'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    _buildProfileSection(
                      title: 'Support',
                      icon: Icons.help,
                      children: [
                        _buildProfileItem(
                          title: 'Help Center',
                          icon: Icons.help_center,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Help Center - Coming Soon'),
                              ),
                            );
                          },
                        ),
                        _buildProfileItem(
                          title: 'Contact Support',
                          icon: Icons.support_agent,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Contact Support - Coming Soon'),
                              ),
                            );
                          },
                        ),
                        _buildProfileItem(
                          title: 'About',
                          icon: Icons.info,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('About - Coming Soon'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required String title,
    required IconData icon,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.brown[400], size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.brown),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(color: Colors.brown[600], fontSize: 14),
              ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String initialName;
  final String initialEmail;
  final String currentRole;

  const EditProfileScreen({
    Key? key,
    required this.userId,
    required this.initialName,
    required this.initialEmail,
    required this.currentRole,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
    };
    final userIdValue = widget.userId.trim();
    final endpoints = <String>[
      'http://196.43.168.57/api/v1/profile',
      if (userIdValue.isNotEmpty)
        'http://196.43.168.57/api/v1/users/$userIdValue',
      if (userIdValue.isNotEmpty)
        'http://196.43.168.57/api/v1/user/$userIdValue',
    ];

    http.Response? response;
    for (final endpoint in endpoints) {
      response = await AuthManager.put(
        endpoint,
        context: context,
        body: payload,
      );
      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        break;
      }
    }

    if (!mounted) return;

    if (response != null &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      final user = _extractUserMap(jsonDecode(response.body));
      if (user != null) {
        final normalizedUser = {
          ...user,
          'id': user['id'] ?? widget.userId,
          'name': user['name'] ?? _nameController.text.trim(),
          'email': user['email'] ?? _emailController.text.trim(),
          'role': user['role'] ?? widget.currentRole,
        };
        await TokenStorage.updateStoredUserInfo(
          userId: normalizedUser['id']?.toString(),
          username: normalizedUser['email']?.toString(),
          displayName: normalizedUser['name']?.toString(),
          role: normalizedUser['role']?.toString(),
          profile: {'user': normalizedUser},
        );
        Navigator.of(context).pop(normalizedUser);
        return;
      }

      Navigator.of(context).pop({
        'id': widget.userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': widget.currentRole,
      });
      return;
    }

    setState(() {
      _isSaving = false;
      _errorMessage = _buildSaveErrorMessage(response);
    });
  }

  Map<String, dynamic>? _extractUserMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['user'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded['user']);
      }
      if (decoded['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      return decoded;
    }
    return null;
  }

  String _buildSaveErrorMessage(dynamic response) {
    if (response == null) {
      return 'No response from server while saving profile.';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
        final errors = decoded['errors'];
        if (errors is Map<String, dynamic> && errors.isNotEmpty) {
          final firstEntry = errors.entries.first.value;
          if (firstEntry is List && firstEntry.isNotEmpty) {
            return firstEntry.first.toString();
          }
        }
      }
    } catch (_) {
      // Fall back to status code.
    }

    return 'Failed to save profile: HTTP ${response.statusCode}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Role',
                      style: TextStyle(
                        color: Colors.brown[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.currentRole,
                      style: TextStyle(color: Colors.brown[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Email is required';
                  }
                  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailPattern.hasMatch(trimmed)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
