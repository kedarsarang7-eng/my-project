import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Modern Professional Device Settings Screen
class DeviceSettingsScreen extends ConsumerStatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  ConsumerState<DeviceSettingsScreen> createState() =>
      _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  bool _enableCloudBackup = true;
  bool _autoSync = true;
  bool _notifications = true;
  double _defaultTaxRate = 18.0;
  String _backupFrequency = 'Daily';

  final List<String> _backupFrequencies = [
    'Every 6 hours',
    'Daily',
    'Weekly',
    'Monthly',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'Device Settings',
      subtitle: 'Configure device-specific preferences and hardware',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('General Preferences', isDark),
            const SizedBox(height: 16),
            _buildSettingsCard(
              isDark: isDark,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Receive alerts and reminders',
                    value: _notifications,
                    onChanged: (val) => setState(() => _notifications = val),
                    isDark: isDark,
                    color: const Color(0xFF8B5CF6),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                  ),
                  _buildSwitchTile(
                    icon: Icons.sync_outlined,
                    title: 'Auto Sync',
                    subtitle: 'Sync data automatically when online',
                    value: _autoSync,
                    onChanged: (val) => setState(() => _autoSync = val),
                    isDark: isDark,
                    color: const Color(0xFF06B6D4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Data & Backup', isDark),
            const SizedBox(height: 16),
            _buildSettingsCard(
              isDark: isDark,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.cloud_outlined,
                    title: 'Cloud Backup',
                    subtitle: 'Auto-sync data to cloud storage',
                    value: _enableCloudBackup,
                    onChanged: (val) =>
                        setState(() => _enableCloudBackup = val),
                    isDark: isDark,
                    color: const Color(0xFF3B82F6),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                  ),
                  _buildMenuTile(
                    icon: Icons.schedule_outlined,
                    title: 'Backup Frequency',
                    subtitle: _backupFrequency,
                    onTap: () => _showBackupFrequencyDialog(isDark),
                    isDark: isDark,
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Billing Defaults', isDark),
            const SizedBox(height: 16),
            _buildSettingsCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTaxRateHeader(context, isDark),
                    const SizedBox(height: 20),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF10B981),
                        inactiveTrackColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE5E7EB),
                        thumbColor: const Color(0xFF10B981),
                        overlayColor: const Color(0xFF10B981).withOpacity(0.2),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: _defaultTaxRate,
                        min: 0,
                        max: 28,
                        divisions: 28,
                        label: '${_defaultTaxRate.round()}%',
                        onChanged: (val) =>
                            setState(() => _defaultTaxRate = val),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0%',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                        Text(
                          '28%',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Hardware Integration', isDark),
            const SizedBox(height: 16),
            _buildSettingsCard(
              isDark: isDark,
              child: _buildMenuTile(
                icon: Icons.print_outlined,
                title: 'Printer Configuration',
                subtitle: 'Manage connected thermal printers',
                onTap: () => context.push('/printer-settings'),
                isDark: isDark,
                color: const Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Storage', isDark),
            const SizedBox(height: 16),
            _buildSettingsCard(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6366F1,
                            ).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.storage_outlined,
                            size: 18,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Flex + ellipsis on mobile so the label never forces
                        // a RenderFlex overflow on narrow viewports (Req 2.5).
                        if (context.isMobile)
                          Expanded(
                            child: Text(
                              'Local Storage Usage',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          )
                        else
                          Text(
                            'Local Storage Usage',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 0.45,
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flex + ellipsis on mobile so the usage labels never
                        // force a RenderFlex overflow on narrow viewports
                        // (Req 2.5).
                        if (context.isMobile)
                          Flexible(
                            child: Text(
                              '450 MB used',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          )
                        else
                          Text(
                            '450 MB used',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        if (context.isMobile)
                          Flexible(
                            child: Text(
                              '1 GB total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          )
                        else
                          Text(
                            '1 GB total',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.cleaning_services_outlined,
                          size: 18,
                        ),
                        label: const Text('Clear Cache'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'DukanX Enterprise',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 3.0.1 • Build 2026.01.25',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Tax-rate card header: the title (icon + label) and the "18%" badge.
  ///
  /// On mobile (width < 600) the title and badge are stacked vertically so
  /// neither overflows the narrow viewport and the slider stays usable
  /// (Req 2.4). On tablet/desktop the original spaceBetween Row is preserved
  /// bit-identically.
  Widget _buildTaxRateHeader(BuildContext context, bool isDark) {
    final isMobile = context.isMobile;

    final titleText = Text(
      'Default Tax Rate (GST)',
      maxLines: isMobile ? 1 : null,
      overflow: isMobile ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
    );

    final titleRow = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.percent, size: 18, color: Color(0xFF10B981)),
        ),
        const SizedBox(width: 12),
        // On mobile the title must flex within the row and ellipsize so it
        // never overflows / renders character-by-character (Req 2.1, 2.4).
        isMobile ? Expanded(child: titleText) : titleText,
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${_defaultTaxRate.toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF10B981),
        ),
      ),
    );

    if (isMobile) {
      // Stack the title and badge vertically so neither overflows (Req 2.4).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleRow, const SizedBox(height: 12), badge],
      );
    }

    // Non-mobile: preserve the original spaceBetween Row exactly.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [titleRow, badge],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      maxLines: context.isMobile ? 1 : null,
      overflow: context.isMobile ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _buildSettingsCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: context.isMobile ? 1 : null,
                  overflow: context.isMobile ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: context.isMobile ? 2 : null,
                  overflow: context.isMobile ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: context.isMobile ? 1 : null,
                      overflow: context.isMobile ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: context.isMobile ? 2 : null,
                      overflow: context.isMobile ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackupFrequencyDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Backup Frequency',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how often to backup your data',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                ..._backupFrequencies.map(
                  (freq) => ListTile(
                    title: Text(
                      freq,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _backupFrequency == freq
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    trailing: _backupFrequency == freq
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF3B82F6),
                          )
                        : null,
                    onTap: () {
                      setState(() => _backupFrequency = freq);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
