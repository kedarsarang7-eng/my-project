import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../services/auth_service.dart';
import '../services/cloud_storage_service.dart';

class CloudSyncSettingsScreen extends StatefulWidget {
  final String ownerId;

  const CloudSyncSettingsScreen({super.key, required this.ownerId});

  @override
  State<CloudSyncSettingsScreen> createState() =>
      _CloudSyncSettingsScreenState();
}

class _CloudSyncSettingsScreenState extends State<CloudSyncSettingsScreen> {
  final CloudStorageService _cloudService = CloudStorageService();
  final AuthService _authService = AuthService();

  bool _isCloudSyncEnabled = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _activeDevices = [];
  Map<String, String> _syncStatus = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final cloudSyncEnabled = await _cloudService.isCloudSyncEnabled(
        ownerId: widget.ownerId,
      );
      final devices = await _cloudService.getActiveDevices(
        ownerId: widget.ownerId,
      );
      final syncStatus = await _cloudService.getSyncStatus(
        ownerId: widget.ownerId,
      );

      setState(() {
        _isCloudSyncEnabled = cloudSyncEnabled;
        _activeDevices = devices;
        _syncStatus = syncStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleCloudSync(bool enabled) async {
    try {
      if (enabled) {
        await _cloudService.enableCloudSync(ownerId: widget.ownerId);
      } else {
        await _cloudService.disableCloudSync(ownerId: widget.ownerId);
      }

      if (mounted) {
        setState(() => _isCloudSyncEnabled = enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled ? 'Cloud sync enabled' : 'Cloud sync disabled',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _signOutFromDevice(String deviceId) async {
    try {
      await _cloudService.signOutFromCloud(
        ownerId: widget.ownerId,
        deviceId: deviceId,
      );
      if (mounted) {
        _loadSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device signed out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _authService.signOut();
                if (mounted) {
                  context.go(RoutePaths.authGate);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync & Data Settings'),
        backgroundColor: Colors.green,
      ),
      body: ResponsiveContainer(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cloud Sync Toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cloud Sync',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enable to automatically sync your data to cloud. Your data will be safe on all devices.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cloud Sync Status:'),
                                Switch(
                                  value: _isCloudSyncEnabled,
                                  onChanged: _toggleCloudSync,
                                  activeColor: Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sync Status:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_syncStatus.containsKey('error'))
                                    Text(
                                      '❌ ${_syncStatus['error']}',
                                      style: const TextStyle(color: Colors.red),
                                    )
                                  else ...[
                                    Text(
                                      '📊 Owner: ${_syncStatus['owner'] ?? 'unknown'}',
                                    ),
                                    Text(
                                      '👥 Customers: ${_syncStatus['customers'] ?? 'unknown'}',
                                    ),
                                    Text(
                                      '📄 Bills: ${_syncStatus['bills'] ?? 'unknown'}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Active Devices
                    const Text(
                      'Active Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_activeDevices.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No active devices',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activeDevices.length,
                        itemBuilder: (ctx, idx) {
                          final device = _activeDevices[idx];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.devices,
                                color: Colors.green,
                              ),
                              title: Text(
                                device['deviceName'] ?? 'Unknown Device',
                              ),
                              subtitle: Text(
                                'Last login: ${device['lastLogin']?.toDate() ?? 'Unknown'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                ),
                                tooltip: 'Sign out from this device',
                                onPressed: () =>
                                    _signOutFromDevice(device['deviceId']),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // Data Storage Options
                    const Text(
                      'Data Storage Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _storageOptionCard(
                              icon: Icons.phone_android,
                              title: 'Local Storage Only',
                              subtitle: 'Data stored on this device only',
                              isSelected: !_isCloudSyncEnabled,
                              onTap: () => _toggleCloudSync(false),
                            ),
                            const SizedBox(height: 12),
                            _storageOptionCard(
                              icon: Icons.cloud,
                              title: 'Cloud Storage (Recommended)',
                              subtitle:
                                  'Data synced to Google Cloud - access from any device',
                              isSelected: _isCloudSyncEnabled,
                              onTap: () => _toggleCloudSync(true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Multi-Device Features
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Multi-Device Features',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _featureItem('✅', 'Login on multiple devices'),
                            _featureItem('✅', 'Data syncs across all devices'),
                            _featureItem(
                              '✅',
                              'Customer data always up-to-date',
                            ),
                            _featureItem('✅', 'Bills visible on all devices'),
                            _featureItem('✅', 'Manage devices from settings'),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _logout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Logout from all Devices',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ℹ️ Data Safety',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• All data is encrypted in transit and at rest\n'
                            '• Local storage is encrypted using AES-256\n'
                            '• Cloud data is protected by Firebase security rules\n'
                            '• Only you can access your data\n'
                            '• Data persists locally even without cloud',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _storageOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.green.shade50 : Colors.transparent,
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.green : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.green : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
