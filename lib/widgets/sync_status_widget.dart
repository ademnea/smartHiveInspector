import 'package:flutter/material.dart';
import '../Services/sync_manager.dart';

class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  int _queueCount = 0;
  bool _isSyncing = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();

    // Set up callbacks for sync status updates
    SyncManager.setCallbacks(
      onSyncStatusChanged: (isSyncing) {
        if (mounted) {
          setState(() {
            _isSyncing = isSyncing;
          });
        }
      },
      onQueueCountChanged: (count) {
        if (mounted) {
          setState(() {
            _queueCount = count;
            _isVisible = count > 0;
          });
        }
      },
      onSyncFailed: (message) {
        if (mounted) {
          final scaffold = ScaffoldMessenger.of(context);
          scaffold.showSnackBar(
            SnackBar(
              content: Text(
                message,
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
      },
    );
  }

  Future<void> _checkSyncStatus() async {
    final status = await SyncManager.getQueueStatus();
    if (mounted) {
      setState(() {
        _queueCount = status['queueCount'] ?? 0;
        _isSyncing = status['isSyncing'] ?? false;
        _isVisible = _queueCount > 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSyncDialog,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isSyncing ? Colors.blue[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isSyncing ? Colors.blue[300]! : Colors.orange[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[600]!,
                      ),
                    ),
                  )
                else
                  Icon(Icons.cloud_upload, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  _isSyncing ? 'Syncing...' : '$_queueCount pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isSyncing ? Colors.blue[800] : Colors.orange[800],
                    fontFamily: "Sans",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Offline Operations',
            style: TextStyle(fontFamily: "Sans", fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSyncing)
                const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Syncing operations...',
                      style: TextStyle(fontFamily: "Sans"),
                    ),
                  ],
                )
              else
                Text(
                  'You have $_queueCount offline operations waiting to sync.',
                  style: const TextStyle(fontFamily: "Sans"),
                ),
              const SizedBox(height: 12),
              const Text(
                'These operations will automatically sync when you have an internet connection.',
                style: TextStyle(
                  fontFamily: "Sans",
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            if (!_isSyncing) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(fontFamily: "Sans")),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await SyncManager.triggerSync();
                },
                child: const Text(
                  'Try Sync Now',
                  style: TextStyle(fontFamily: "Sans"),
                ),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(fontFamily: "Sans")),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A floating sync status indicator that can be added to any screen
class FloatingSyncStatus extends StatelessWidget {
  const FloatingSyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: const SyncStatusWidget(),
    );
  }
}

/// A banner sync status that can be added at the top of screens
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  int _queueCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();

    // Set up callbacks for sync status updates
    SyncManager.setCallbacks(
      onSyncStatusChanged: (isSyncing) {
        if (mounted) {
          setState(() {
            _isSyncing = isSyncing;
          });
        }
      },
      onQueueCountChanged: (count) {
        if (mounted) {
          setState(() {
            _queueCount = count;
          });
        }
      },
    );
  }

  Future<void> _checkSyncStatus() async {
    final status = await SyncManager.getQueueStatus();
    if (mounted) {
      setState(() {
        _queueCount = status['queueCount'] ?? 0;
        _isSyncing = status['isSyncing'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_queueCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isSyncing ? Colors.blue[50] : Colors.orange[50],
        border: Border(
          bottom: BorderSide(
            color: _isSyncing ? Colors.blue[200]! : Colors.orange[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_isSyncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            )
          else
            Icon(Icons.cloud_upload, size: 16, color: Colors.orange[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSyncing
                  ? 'Syncing $_queueCount offline operations...'
                  : '$_queueCount operations waiting to sync',
              style: TextStyle(
                fontSize: 13,
                color: _isSyncing ? Colors.blue[800] : Colors.orange[800],
                fontFamily: "Sans",
              ),
            ),
          ),
          if (!_isSyncing)
            TextButton(
              onPressed: () async {
                await SyncManager.triggerSync();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Sync Now',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[800],
                  fontFamily: "Sans",
                ),
              ),
            ),
        ],
      ),
    );
  }
}
