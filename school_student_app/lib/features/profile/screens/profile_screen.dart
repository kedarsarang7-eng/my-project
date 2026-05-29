import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final profileAsync = ref.watch(profileProvider);

    return PageScaffold(
      title: 'My Profile',
      body: profileAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120, radius: 60), SizedBox(height: 16), ShimmerBox(height: 300)])),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: 20),
              _ProfileDetails(profile: profile),
              const SizedBox(height: 20),
              _ProfileActions(ref: ref),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
    final studentId = profile['studentId'] ?? '';
    final batch = profile['batchNames']?.join(', ') ?? '';
    final photoUrl = profile['photoUrl'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w700)) : null,
          ),
          const SizedBox(height: 12),
          Text(name.isEmpty ? 'Student' : name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          if (studentId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('ID: $studentId', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (batch.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(batch, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileDetails({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (Icons.phone_outlined, 'Phone', profile['phone'] ?? '—'),
      (Icons.email_outlined, 'Email', profile['email'] ?? '—'),
      (Icons.cake_outlined, 'Date of Birth', profile['dob'] ?? '—'),
      (Icons.school_outlined, 'School/Board', profile['board'] ?? profile['schoolName'] ?? '—'),
      (Icons.home_outlined, 'Address', profile['address'] ?? '—'),
      (Icons.person_outline, 'Parent/Guardian', profile['parentName'] ?? '—'),
      (Icons.phone_outlined, 'Parent Phone', profile['parentPhone'] ?? '—'),
    ];

    return Container(
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final (icon, label, value) = e.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value.toString().isEmpty ? '—' : value.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ])),
              ]),
            ),
            if (e.key < rows.length - 1) const Divider(height: 1, indent: 46),
          ]);
        }).toList(),
      ),
    );
  }
}

class _ProfileActions extends ConsumerWidget {
  final WidgetRef ref;
  const _ProfileActions({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return Column(
      children: [
        // Dark mode toggle
        Container(
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
          child: SwitchListTile(
            value: isDark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
            secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppTheme.primary),
            title: const Text('Dark Mode'),
            activeColor: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.lock_outline, color: AppTheme.primary),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
          tileColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.error),
          title: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
          tileColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Sign Out')),
                ],
              ),
            );
            if (confirm == true) ref.read(authStateProvider.notifier).signOut();
          },
        ),
      ],
    );
  }
}
