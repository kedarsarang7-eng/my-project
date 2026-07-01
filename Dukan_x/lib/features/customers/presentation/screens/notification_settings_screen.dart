import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _orderUpdates = true;
  bool _promotions = true;
  bool _securityAlerts = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _orderUpdates = prefs.getBool('notify_order_updates') ?? true;
      _promotions = prefs.getBool('notify_promotions') ?? true;
      _securityAlerts = prefs.getBool('notify_security') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader("Orders & Activity"),
                _buildSwitchTile(
                  title: "Order Updates",
                  subtitle: "Get notified about order status changes",
                  value: _orderUpdates,
                  onChanged: (val) {
                    setState(() => _orderUpdates = val);
                    _updateSetting('notify_order_updates', val);
                  },
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Promotions"),
                _buildSwitchTile(
                  title: "Offers & Deals",
                  subtitle: "Receive updates on sales and discounts",
                  value: _promotions,
                  onChanged: (val) {
                    setState(() => _promotions = val);
                    _updateSetting('notify_promotions', val);
                  },
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Security"),
                _buildSwitchTile(
                  title: "Security Alerts",
                  subtitle: "Login account/activity alerts",
                  value: _securityAlerts,
                  onChanged: (val) {
                    setState(() => _securityAlerts = val);
                    _updateSetting('notify_security', val);
                  },
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
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
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
        ),
        activeColor: Colors.blue,
      ),
    );
  }
}
