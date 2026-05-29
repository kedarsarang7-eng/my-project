import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryProvider);

    return PageScaffold(
      title: 'Library',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(libraryProvider),
        child: async.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120), SizedBox(height: 16), ShimmerBox(height: 200)])),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(libraryProvider)),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
                children: [
                  StatCard(label: 'Total Books', value: '${data['totalBooks'] ?? 0}', icon: Icons.book_rounded, color: const Color(0xFF7C3AED)),
                  StatCard(label: 'Issued', value: '${data['issuedBooks'] ?? 0}', icon: Icons.library_books_rounded, color: AppTheme.primary),
                  StatCard(label: 'Available', value: '${data['availableBooks'] ?? 0}', icon: Icons.check_circle_rounded, color: AppTheme.success),
                  StatCard(label: 'Overdue', value: '${data['overdueBooks'] ?? 0}', icon: Icons.warning_rounded, color: AppTheme.error),
                ],
              ),
              const SectionHeader(title: 'Recently Issued'),
              ...((data['recentIssues'] as List?) ?? []).take(5).map((b) {
                final book = b as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(book['bookTitle'] ?? book['title'] ?? 'Book', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('By: ${book['studentName'] ?? '—'} · Due: ${book['dueDate'] ?? '—'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ])),
                      if (book['isOverdue'] == true) const StatusBadge(label: 'OVERDUE', color: AppTheme.error),
                    ]),
                  ),
                );
              }),
            ]),
          ),
        ),
      ),
    );
  }
}
