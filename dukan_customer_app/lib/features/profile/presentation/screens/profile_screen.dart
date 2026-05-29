import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../../core/auth/customer_session_manager.dart';
import '../../../../core/navigation/app_router.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.editProfile),
          ),
        ],
      ),
      body: profile.when(
        data: (p) => _ProfileBody(profile: p),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorStateWidget(
          message: 'Could not load profile',
          onRetry: () => ref.invalidate(customerProfileProvider),
        ),
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 3),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final CustomerProfile profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        _AvatarHeader(profile: profile),
        const SizedBox(height: 8),
        _FinancialSummaryCard(profile: profile),
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Account',
          items: [
            _MenuItem(
              icon: Icons.store_rounded,
              label: 'My Shops',
              onTap: () => context.push(AppRoutes.linkedShops),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'Invoice History',
              onTap: () => context.push(AppRoutes.invoices),
            ),
            _MenuItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ledger',
              onTap: () => context.push(AppRoutes.ledger),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Settings',
          items: [
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notification Settings',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.security_outlined,
              label: 'Security',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Support',
          items: [
            _MenuItem(
              icon: Icons.help_outline_rounded,
              label: 'Help & FAQ',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Contact Support',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE53935)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmationBottomSheet.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      cancelLabel: 'Cancel',
      confirmColor: const Color(0xFFE53935),
      icon: Icons.logout_rounded,
    );
    if (confirmed && context.mounted) {
      await ref.read(customerSessionProvider.notifier).signOut();
    }
  }
}

class _AvatarHeader extends StatelessWidget {
  final CustomerProfile profile;
  const _AvatarHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: profile.photoUrl != null
                ? NetworkImage(profile.photoUrl!)
                : null,
            child: profile.photoUrl == null
                ? Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '+91 ${profile.phone}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (profile.email != null)
            Text(
              profile.email!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final CustomerProfile profile;
  const _FinancialSummaryCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomerBalanceCard(
        totalDue: profile.totalDue,
        totalPaid: profile.totalPaid,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _SectionCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: items
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < items.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0: context.go(AppRoutes.home);
          case 1: context.go(AppRoutes.invoices);
          case 2: context.go(AppRoutes.ledger);
          case 3: context.go(AppRoutes.profile);
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Invoices'),
        NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Ledger'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}
