import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(institutionConfigProvider);

    return PageScaffold(
      title: 'Settings',
      body: configAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 200), SizedBox(height: 16), ShimmerBox(height: 300)])),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(institutionConfigProvider)),
        data: (config) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _InstitutionCard(config: config),
            const SizedBox(height: 16),
            _SettingsGroup(title: 'General', items: [
              (Icons.school_outlined, 'Institution Details', AppTheme.primary, () {}),
              (Icons.class_outlined, 'Academic Year', AppTheme.secondary, () {}),
              (Icons.access_time_rounded, 'School Timings', AppTheme.accent, () {}),
              (Icons.holiday_village_outlined, 'Holiday Calendar', AppTheme.warning, () {}),
            ]),
            const SizedBox(height: 12),
            _SettingsGroup(title: 'Modules', items: [
              (Icons.account_balance_wallet_outlined, 'Fee Configuration', AppTheme.success, () {}),
              (Icons.directions_bus_outlined, 'Transport Settings', AppTheme.success, () {}),
              (Icons.local_library_outlined, 'Library Settings', const Color(0xFF7C3AED), () {}),
              (Icons.apartment_outlined, 'Hostel Settings', AppTheme.primary, () {}),
            ]),
            const SizedBox(height: 12),
            _SettingsGroup(title: 'Users & Access', items: [
              (Icons.people_outline, 'User Management', AppTheme.primary, () {}),
              (Icons.lock_outline, 'Roles & Permissions', AppTheme.secondary, () {}),
              (Icons.notifications_outlined, 'Notification Settings', AppTheme.warning, () {}),
            ]),
            const SizedBox(height: 12),
            _AppearanceCard(),
            const SizedBox(height: 12),
            _SignOutTile(ref: ref),
          ]),
        ),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  final Map<String, dynamic> config;
  const _InstitutionCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final name = config['institutionName'] ?? config['name'] ?? 'Institution';
    final logo = config['logoUrl'];
    final address = config['address'] ?? '';
    final board = config['board'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primary]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: logo != null ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(logo, fit: BoxFit.cover)) : const Icon(Icons.school_rounded, color: Colors.white, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          if (board.isNotEmpty) Text(board, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (address.isNotEmpty) Text(address, style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20), onPressed: () {}),
      ]),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<(IconData, String, Color, VoidCallback)> items;
  const _SettingsGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary, letterSpacing: 0.5))),
      Container(
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
        child: Column(children: items.asMap().entries.map((e) {
          final (icon, label, color, onTap) = e.value;
          return Column(children: [
            ListTile(
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
              title: Text(label, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
              onTap: onTap,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            if (e.key < items.length - 1) const Divider(height: 1, indent: 62),
          ]);
        }).toList()),
      ),
    ]);
  }
}

class _AppearanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
        child: SwitchListTile(
          value: isDark,
          onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
          secondary: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppTheme.primary, size: 18),
          ),
          title: const Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(isDark ? 'Dark theme enabled' : 'Light theme enabled', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          activeColor: AppTheme.primary,
        ),
      ),
    ]);
  }
}

class _SignOutTile extends StatelessWidget {
  final WidgetRef ref;
  const _SignOutTile({required this.ref});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
    child: ListTile(
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.logout, color: AppTheme.error, size: 18)),
      title: const Text('Sign Out', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: () async {
        final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Sign out of admin panel?'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Sign Out'))],
        ));
        if (ok == true) ref.read(authStateProvider.notifier).signOut();
      },
    ),
  );
}
