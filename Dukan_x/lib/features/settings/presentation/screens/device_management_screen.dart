// ============================================================================
// DEVICE MANAGEMENT SCREEN — Phase 3 Multi-Device Auth
// ============================================================================
// Displays all registered devices for the current user.
// Allows deregistering other devices (remote sign-out).
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/services/device_registration_service.dart';
import '../../../../core/services/device_id_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      _currentDeviceId = await DeviceIdService.instance.getDeviceId();
      final devices = await DeviceRegistrationService.instance.listDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load devices: $e')));
      }
    }
  }

  Future<void> _deregisterDevice(String sessionId, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deregister Device'),
        content: Text(
          'Are you sure you want to sign out "$deviceName"? '
          'This device will need to log in again to sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SIGN OUT DEVICE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await DeviceRegistrationService.instance.deregisterDevice(
        sessionId,
      );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$deviceName has been signed out')),
          );
        }
        await _loadDevices();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to deregister device')),
          );
        }
      }
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows;
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }

  String _formatLastActive(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 5) return 'Active now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.devices, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    'No devices registered',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Devices will appear here after logging in',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final deviceId = device['deviceId'] as String? ?? '';
                  final isCurrentDevice = deviceId == _currentDeviceId;
                  final isActive = device['isActive'] as bool? ?? false;
                  final platform = device['platform'] as String? ?? 'unknown';
                  final deviceName =
                      device['deviceName'] as String? ?? 'Unknown Device';
                  final lastActive = device['lastActiveAt'] as String? ?? '';

                  return Card(
                    elevation: isCurrentDevice ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isCurrentDevice
                          ? BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? theme.colorScheme.primary.withAlpha(30)
                            : theme.disabledColor.withAlpha(30),
                        child: Icon(
                          _platformIcon(platform),
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              deviceName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isCurrentDevice)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'This Device',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            isActive ? Icons.circle : Icons.circle_outlined,
                            size: 10,
                            color: isActive ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatLastActive(lastActive),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                      trailing: isCurrentDevice
                          ? null
                          : isActive
                          ? IconButton(
                              icon: const Icon(Icons.logout, color: Colors.red),
                              onPressed: () => _deregisterDevice(
                                device['id'] as String,
                                deviceName,
                              ),
                              tooltip: 'Sign out this device',
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }
}
