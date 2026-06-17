import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: 'Library',
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(schoolRepoProvider).getLibraryInfo(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
                padding: EdgeInsets.all(20),
                child: Column(children: [
                  ShimmerBox(height: 120, radius: 16),
                  SizedBox(height: 16),
                  ShimmerBox(height: 200, radius: 16)
                ]));
          }
          if (snap.hasError) return ErrorState(message: snap.error.toString());
          final data = snap.data ?? {};
          final issuedBooks = (data['issuedBooks'] as List?) ?? [];
          final catalog = (data['catalog'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My issued books
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_library_rounded,
                        color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Library Card',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(
                              '${issuedBooks.length} book${issuedBooks.length == 1 ? '' : 's'} issued',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18)),
                        ]),
                  ]),
                ),
                const SectionHeader(title: 'Currently Issued'),
                if (issuedBooks.isEmpty)
                  const EmptyState(
                      message: 'No books currently issued',
                      icon: Icons.book_outlined)
                else
                  ...issuedBooks.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _IssuedBookTile(book: b as Map<String, dynamic>),
                      )),
                if (catalog.isNotEmpty) ...[
                  const SectionHeader(title: 'Search Catalog'),
                  ...catalog.take(10).map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CatalogTile(book: b as Map<String, dynamic>),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IssuedBookTile extends StatelessWidget {
  final Map<String, dynamic> book;
  const _IssuedBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final title = book['title'] ?? 'Book';
    final author = book['author'] ?? '';
    final dueDate = book['dueDate'] ?? '';
    final isOverdue = book['isOverdue'] == true;

    return InfoTile(
      icon: Icons.menu_book_rounded,
      title: title,
      subtitle: '${author.isNotEmpty ? '$author · ' : ''}Due: $dueDate',
      iconColor: isOverdue ? AppTheme.error : AppTheme.success,
      trailing: isOverdue
          ? const StatusBadge(label: 'OVERDUE', color: AppTheme.error)
          : null,
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final Map<String, dynamic> book;
  const _CatalogTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final title = book['title'] ?? '';
    final author = book['author'] ?? '';
    final available = book['availableCopies'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        const Icon(Icons.book_outlined, color: AppTheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (author.isNotEmpty)
            Text(author,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
        ])),
        Text('$available avail.',
            style: TextStyle(
                fontSize: 11,
                color: available > 0 ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
