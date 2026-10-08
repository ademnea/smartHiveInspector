import 'package:HPGM/api/farmer_api.dart';
import 'package:HPGM/config/api_config.dart';
import 'package:HPGM/add_hive_form.dart';
import 'package:HPGM/edit_hive_form.dart';
import 'package:HPGM/records_form.dart';
import 'package:HPGM/Services/auth_manager.dart';
import 'package:HPGM/Services/token_storage.dart';
import 'package:HPGM/Services/cache_service.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/hivedetails.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'dart:convert';

class Hives extends StatefulWidget {
  final int farmId;
  final String token;
  final String apiaryLocation;
  final String farmName;
  final VoidCallback onHiveDeleted; // Callback for hive deletion

  const Hives({
    super.key,
    required this.farmId,
    required this.token,
    required this.apiaryLocation,
    required this.farmName,
    required this.onHiveDeleted, // Initialize the callback
  });

  @override
  State<Hives> createState() => _HivesState();
}

class Hive {
  final int id;
  final String name;
  final String longitude;
  final String latitude;
  final int farmId;
  final String? createdAt;
  final String? updatedAt;
  final double? weight;
  final double? honeyLevel;
  final double? temperature;

  /// Null when the API has no value yet (no device data).
  final bool? connected;
  final bool? colonized;

  /// One of Active, Inactive, Under Inspection, Queenless, Absconded,
  /// Decommissioned.
  final String? currentStatus;
  final String? queenStatus;
  final String? hiveType;

  Hive({
    required this.id,
    required this.name,
    required this.longitude,
    required this.latitude,
    required this.farmId,
    required this.createdAt,
    required this.updatedAt,
    required this.weight,
    required this.temperature,
    required this.honeyLevel,
    required this.connected,
    required this.colonized,
    this.currentStatus,
    this.queenStatus,
    this.hiveType,
  });

  bool get isConnected => connected ?? false;
  bool get isColonized => colonized ?? false;

  // Reads a farmer API hive (flat fields, `connected`/`colonized` as 0/1 or
  // null) and the old API's hive (values nested under `state`), which may
  // still be in the offline cache.
  factory Hive.fromJson(Map<String, dynamic> json) {
    final state = json['state'] as Map<String, dynamic>?;
    final id = _toInt(json['id']) ?? 0;

    return Hive(
      id: id,
      name: _firstText([json['display_name'], json['name'], json['hive_code']]) ??
          'Hive $id',
      longitude: json['longitude']?.toString() ?? '',
      latitude: json['latitude']?.toString() ?? '',
      farmId: _toInt(json['apiary_id'] ?? json['farm_id']) ?? 0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      weight: _toDouble(state?['weight']?['record']),
      temperature: _toDouble(state?['temperature']?['interior_temperature']),
      honeyLevel: _toDouble(state?['weight']?['honey_percentage']),
      connected: _toBool(
        json['connected'] ?? state?['connection_status']?['Connected'],
      ),
      colonized: _toBool(
        json['colonized'] ?? state?['colonization_status']?['Colonized'],
      ),
      currentStatus: _firstText([json['current_status'], json['status']]),
      queenStatus: _firstText([json['queen_status']]),
      hiveType: _firstText([json['hive_type']]),
    );
  }

  static int? _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  static double? _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    return v == 1 || v == '1';
  }

  static String? _firstText(List<dynamic> values) {
    for (final v in values) {
      final text = v?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}

class _HivesState extends State<Hives> {
  List<Hive> hives = [];
  bool isTableView = false; // Add this state variable

  @override
  void initState() {
    super.initState();
    getHives(widget.farmId);
  }

  Future<void> getHives(int farmId) async {
    try {
      // Check if device is online
      final isOnline = await CacheService.isOnline();

      // If offline, try to load from cache first
      if (!isOnline) {
        print('📱 Device is offline, trying to load hives from cache...');
        final cachedHives = await CacheService.loadHives(farmId);
        if (cachedHives != null) {
          setState(() {
            hives = cachedHives.map((hive) => Hive.fromJson(hive)).toList();
          });

          print('✓ Loaded ${hives.length} hives from cache');

          // Show user-friendly offline message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '📱 Offline mode - Showing saved hives',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        } else {
          // No cached data available
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '📱 No internet connection and no saved hives available',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      // Device is online - proceed with API call
      print('🌐 Device is online, fetching hives from API...');

      final data = await FarmerApi.instance.allHives(farmId);

      // Save to cache for offline use
      await CacheService.saveHives(farmId, data);

      if (!mounted) return;
      setState(() {
        hives = data.map(Hive.fromJson).toList();
      });
    } catch (error) {
      print('Error fetching hives: $error');
      // A 401 has already sent the user to login (FarmerApi.onUnauthorized).
      if (error is ApiException && error.status == 401) return;

      // Try loading from cache as fallback
      final cachedHives = await CacheService.loadHives(farmId);
      if (cachedHives != null) {
        setState(() {
          hives = cachedHives.map((hive) => Hive.fromJson(hive)).toList();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ Connection error - Showing saved hives',
                style: TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '❌ Unable to load hives. Please try again later.',
                style: TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      body: LiquidPullToRefresh(
        color: Colors.orange,
        height: 150,
        animSpeedFactor: 2,
        onRefresh: () async {
          await getHives(widget.farmId);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.orange,
              title: Text(
                '${widget.farmName} Hives List',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: "Sans",
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AddHiveForm(
                              farmId: widget.farmId,
                              apiaryLocation: widget.apiaryLocation,
                              farmName: widget.farmName,
                              onHiveAdded: () async {
                                await getHives(widget.farmId);
                              },
                            ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    isTableView ? Icons.view_list : Icons.grid_view,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      isTableView = !isTableView;
                    });
                  },
                ),
              ],
            ),
            // Conditional rendering based on view type
            isTableView
                ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildHivesTable(),
                  ),
                )
                : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 16,
                      ),
                      child: buildHiveCard(hives[index]),
                    );
                  }, childCount: hives.length),
                ),
          ],
        ),
      ),
    );
  }

  // Modified method to build the table view
  Widget _buildHivesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.orange[700]),
            dataRowColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.hovered)) {
                return Colors.orange[50]!;
              }
              return Colors.white;
            }),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: "Sans",
            ),
            dataTextStyle: const TextStyle(
              color: Colors.black87,
              fontFamily: "Sans",
            ),
            columns: const [
              DataColumn(label: Text('Hive ID')),
              DataColumn(label: Text('Actions')),
            ],
            rows:
                hives.map((hive) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          hive.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View button
                            SizedBox(
                              width: 70,
                              height: 30,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  final token = await TokenStorage.getToken();
                                  if (token != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => HiveDetails(
                                              hiveId: hive.id,
                                              token: token,
                                              honeyLevel: hive.honeyLevel,
                                            ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 4, width: 4),
                            // Edit button
                            SizedBox(
                              width: 70,
                              height: 30,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () {
                                  _showEditHiveDialog(hive);
                                },
                              ),
                            ),
                            const SizedBox(height: 4, width: 4),
                            // Delete button
                            SizedBox(
                              width: 70,
                              height: 30,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () {
                                  _showDeleteConfirmation(hive);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  // Add method to show edit dialog
  void _showEditHiveDialog(Hive hive) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditHiveForm(
              hiveId: hive.id,
              farmId: widget.farmId,
              apiaryLocation: widget.apiaryLocation,
              farmName: widget.farmName,
              initialLatitude: hive.latitude,
              initialLongitude: hive.longitude,
              initialColonized: hive.isColonized,
              initialConnected: hive.isConnected,
              onHiveUpdated: () async {
                await getHives(widget.farmId);
              },
            ),
      ),
    );
  }

  // Add method to show delete confirmation
  void _showDeleteConfirmation(Hive hive) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete ${hive.name}',
            style: const TextStyle(fontFamily: "Sans"),
          ),
          content: const Text(
            'Are you sure you want to delete this hive? This action cannot be undone.',
            style: TextStyle(fontFamily: "Sans"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteHive(hive.id);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Add method to delete hive
  Future<void> _deleteHive(int hiveId) async {
    try {
      final response = await AuthManager.delete(
        '${ApiConfig.legacyHost}/api/v1/hives/$hiveId',
        context: context,
      );

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 204)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hive deleted successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
        await getHives(widget.farmId); // Refresh the list

        widget.onHiveDeleted(); // 💥 notify parent to update stats
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_buildDeleteHiveErrorMessage(response)),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  String _buildDeleteHiveErrorMessage(dynamic response) {
    if (response == null) {
      return 'Failed to delete hive. No response from server.';
    }

    try {
      final body = response.body;
      if (body is String && body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return 'Failed to delete hive: $message';
          }
        }
      }
    } catch (_) {
      // Fall back to the HTTP status if the response is not JSON.
    }

    return 'Failed to delete hive: HTTP ${response.statusCode}';
  }

  // Green for yes, red for no, grey when the API has no value.
  Color _flagColor(bool? flag) =>
      flag == null
          ? Colors.white70
          : flag
          ? Colors.green
          : Colors.red;

  Widget buildHiveCard(Hive hive) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.brown[300],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Icon(Icons.hexagon, color: Colors.orange[700], size: 28),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    hive.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Sans",
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  hive.isConnected ? Icons.link : Icons.link_off,
                  color: _flagColor(hive.connected),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: hive.currentStatus ?? 'Unknown',
              valueColor:
                  hive.currentStatus == null
                      ? Colors.white70
                      : hive.currentStatus!.toLowerCase() == 'active'
                      ? Colors.green
                      : Colors.orange,
            ),

            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.link,
              label: 'Device',
              value:
                  hive.connected == null
                      ? 'No data'
                      : hive.isConnected
                      ? 'ON'
                      : 'OFF',
              valueColor: _flagColor(hive.connected),
            ),

            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.emoji_nature,
              label: 'Queen',
              value: hive.queenStatus ?? 'Unknown',
              valueColor: Colors.white,
            ),

            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.star,
              label: 'Performance',
              value: 'Good', //Enum value for performance{Good, Average, Poor}
              valueColor: Colors.green,
            ),

            const SizedBox(height: 12),

            // Colonization Status
            _buildInfoRow(
              icon: Icons.grass,
              label: 'Colonization Status',
              value:
                  hive.colonized == null
                      ? 'Unknown'
                      : hive.isColonized
                      ? 'Colonized'
                      : 'Not Colonized',
              valueColor: _flagColor(hive.colonized),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final token = await TokenStorage.getToken();
                      if (token != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => HiveDetails(
                                  hiveId: hive.id,
                                  token: token,
                                  honeyLevel: hive.honeyLevel,
                                ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final token = await TokenStorage.getToken();
                      if (token != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RecordsForm(
                                  apiaryLocation: widget.apiaryLocation,
                                  hiveId: hive.name,
                                  farmName: widget.farmName,
                                ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Inspect',
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orange[700], size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Sans",
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.white,
                  fontFamily: "Sans",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
