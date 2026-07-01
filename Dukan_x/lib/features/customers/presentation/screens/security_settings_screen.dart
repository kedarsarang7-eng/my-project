// ============================================================================
// SECURITY SETTINGS SCREEN
// ============================================================================
// Manage app security settings (App Lock, etc.)
//
// Author: DukanX Engineering
// Version: 1.1.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/auth/services/biometric_service.dart';
import '../../../../features/auth/services/pin_service.dart';
import '../../../../features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _biometricsEnabled = false;
  bool _pinEnabled = false;
  bool _isLoading = true;
  bool _isDeviceSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final supported = await BiometricService().isDeviceSupported();
    final bioEnabled = await BiometricService().isBiometricsEnabled();
    final pinSet = await PinService().isPinSet();

    if (mounted) {
      setState(() {
        _isDeviceSupported = supported;
        _biometricsEnabled = bioEnabled;
        _pinEnabled = pinSet;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    setState(() => _isLoading = true);
    try {
      if (value) {
        final success = await BiometricService().enableBiometrics();
        if (success) {
          setState(() => _biometricsEnabled = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Biometric App Lock Enabled"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // User cancelled or failed auth
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Authentication Failed"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        await BiometricService().disableBiometrics();
        setState(() => _biometricsEnabled = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Security",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection("App Access"),
                if (_isDeviceSupported)
                  SwitchListTile(
                    value: _biometricsEnabled,
                    onChanged: _toggleBiometrics,
                    title: Text(
                      "Biometric App Lock",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      "Require fingerprint/face ID to open app",
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    secondary: const Icon(Icons.fingerprint),
                    activeColor: Theme.of(context).colorScheme.primary,
                  )
                else
                  ListTile(
                    title: Text(
                      "Biometrics Unavailable",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                    subtitle: Text(
                      "Device does not support biometrics",
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    leading: const Icon(Icons.fingerprint, color: Colors.grey),
                  ),
                ListTile(
                  title: Text(
                    "PIN Code",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _pinEnabled ? "PIN is set" : "Setup 4-digit PIN",
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                  ),
                  leading: const Icon(Icons.dialpad),
                  trailing: _pinEnabled
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PinSetupScreen(
                          onSuccess: () {
                            _loadSettings();
                          },
                        ),
                      ),
                    );
                    _loadSettings(); // Reload after return as well
                  },
                ),
                const SizedBox(height: 24),
                _buildSection("Account"),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text("Change Password", style: GoogleFonts.outfit()),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  enabled: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Change Password"),
                        content: const Text(
                          "To change your password, please sign out and use the 'Forgot Password' option on the login screen.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    "Delete Account",
                    style: GoogleFonts.outfit(color: Colors.red),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Delete Account"),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "This action cannot be undone!",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Deleting your account will permanently remove:",
                            ),
                            const SizedBox(height: 8),
                            const Text("• All your business data"),
                            const Text("• All invoices and bills"),
                            const Text("• Customer records"),
                            const Text("• Payment history"),
                            const SizedBox(height: 16),
                            const Text(
                              "To proceed, please contact our support team:",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              "support@dukanx.app",
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please email support@dukanx.app to request account deletion",
                                  ),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            },
                            child: const Text(
                              "I Understand",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
