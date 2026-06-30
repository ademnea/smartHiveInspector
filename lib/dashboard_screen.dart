import 'dart:async';
import 'package:HPGM/analytics/foraging_advisory_screen.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';
import 'package:HPGM/bee_counter/bee_monitoring_screen.dart';
import 'package:HPGM/notifications/notification_screen.dart';
import 'package:HPGM/analytics/navigation_helper.dart';
import 'package:HPGM/navbar.dart';
import 'package:HPGM/profile.dart';
import 'package:HPGM/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/bee_counter/hive_selection_screen.dart';

// Notification Service (if not already defined elsewhere)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _notificationController =
      StreamController<List<NotificationItem>>.broadcast();

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get criticalCount => _notifications.where((n) => n.isCritical).length;

  Stream<List<NotificationItem>> get notificationStream =>
      _notificationController.stream;

  void addAdvisoryRecommendation(String recommendation, String hiveId) {
    _notifications.add(
      NotificationItem(
        title: 'Advisory Alert',
        body: recommendation,
        isRead: false,
        isCritical:
            recommendation.contains('urgent') ||
            recommendation.contains('critical'),
        timestamp: DateTime.now(),
      ),
    );
    _notificationController.add(_notifications);
  }

  void markAsRead(int index) {
    if (index < _notifications.length) {
      _notifications[index].isRead = true;
      _notificationController.add(_notifications);
    }
  }

  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    _notificationController.add(_notifications);
  }

  void clearAll() {
    _notifications.clear();
    _notificationController.add(_notifications);
  }
}

class NotificationItem {
  final String title;
  final String body;
  bool isRead;
  final bool isCritical;
  final DateTime timestamp;

  NotificationItem({
    required this.title,
    required this.body,
    this.isRead = false,
    this.isCritical = false,
    required this.timestamp,
  });
}

class DashboardScreen extends StatefulWidget {
  final String token;
  const DashboardScreen({super.key, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  StreamSubscription<List<NotificationItem>>? _notificationSubscription;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize notification count
    _notificationCount = NotificationService().unreadCount;

    // Listen to notification updates
    _notificationSubscription = NotificationService().notificationStream.listen(
      (notifications) {
        if (mounted) {
          setState(() {
            _notificationCount = NotificationService().unreadCount;
          });
        }
      },
    );

    // Load initial notifications from advisory system
    _loadInitialNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialNotifications() async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      final analysis = await advisoryService.getDailyForagingAnalysis(
        '1',
        DateTime.now(),
      );

      if (analysis != null) {
        // Add recommendations as notifications
        for (final recommendation in analysis.recommendations) {
          NotificationService().addAdvisoryRecommendation(
            recommendation.title,
            analysis.hiveId,
          );
        }
      }
    } catch (e) {
      print('Error loading initial notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BeeSight',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber[800],
        elevation: 0,
        actions: [
          // Notifications icon with smart badge
          NotificationBadge(
            count: _notificationCount,
            child: IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ),
          // Profile avatar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                final token = await TokenStorage.getToken();
                if (token != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(token: token),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 24, color: Colors.amber[800]),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard title and welcome message with notification summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.brown[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quick notification summary
                      if (_notificationCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                NotificationService().criticalCount > 0
                                    ? Colors.red.shade100
                                    : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  NotificationService().criticalCount > 0
                                      ? Colors.red.shade300
                                      : Colors.orange.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                NotificationService().criticalCount > 0
                                    ? Icons.error
                                    : Icons.notifications_active,
                                size: 16,
                                color:
                                    NotificationService().criticalCount > 0
                                        ? Colors.red.shade600
                                        : Colors.orange.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_notificationCount alert${_notificationCount != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      NotificationService().criticalCount > 0
                                          ? Colors.red.shade600
                                          : Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content - Grid layout feature cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // First row - two cards side by side
                    Row(
                      children: [
                        // Apiary Management Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Apiary Management',
                            icon: Icons.grid_view,
                            color: const Color(0xFFD4A657),
                            notifications: 2,
                            onTap: () async {
                              final token = await TokenStorage.getToken();
                              if (token != null && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NavBar(token: token),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bee Counter Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Bee Counter',
                            icon: Icons.trending_up,
                            color: const Color(0xFFCD853F),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const BeeMonitoringScreen(
                                        hiveId: '1',
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Second row - two cards side by side
                    Row(
                      children: [
                        // Advisory Resources Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Advisory Resources',
                            icon: Icons.book,
                            color: const Color(0xFFB87333),
                            onTap: () {
                              NavigationHelper.navigateToRecommendations(
                                context,
                                hiveId: '1',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Analytics Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Analytics',
                            icon: Icons.insights,
                            color: const Color(0xFFDAA520),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const EnhancedForagingDashboard(
                                            hiveId: '1',
                                          ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Third row - two cards side by side
                    Row(
                      children: [
                        // Notifications Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Notifications',
                            icon: Icons.notifications,
                            color: const Color(0xFF8B4513),
                            notifications: _notificationCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Hive Data Card
                        // Hive Data Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Hive Data',
                            icon: Icons.hive,
                            color: const Color(0xFF4682B4),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const HiveSelectionScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              // Already on Dashboard
              break;
            case 1:
              final token = await TokenStorage.getToken();
              if (token != null && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => NavBar(token: token)),
                );
              }
              break;
            case 2:
              // Navigate to Notifications screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
              break;
            case 3:
              final profileToken = await TokenStorage.getToken();
              if (profileToken != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(token: profileToken),
                  ),
                );
              }
              break;
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.brown[300],
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.hive), label: 'Hives'),
          BottomNavigationBarItem(
            icon: NotificationBadge(
              count: 0, // This will be updated dynamically
              child: const Icon(Icons.notifications),
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    int? notifications,
    required VoidCallback onTap,
  }) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.0),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  color: color,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (notifications != null && notifications > 0)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                notifications > 99 ? '99+' : notifications.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Notification Badge Widget
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
