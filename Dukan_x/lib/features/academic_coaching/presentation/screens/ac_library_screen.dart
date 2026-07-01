// ============================================================================
// SCHOOL ERP — LIBRARY MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcLibraryScreen extends StatefulWidget {
  const AcLibraryScreen({super.key});

  @override
  State<AcLibraryScreen> createState() => _AcLibraryScreenState();
}

class _AcLibraryScreenState extends State<AcLibraryScreen>
    with SingleTickerProviderStateMixin {
  late AcRepository _repository;
  late TabController _tabController;

  List<AcBook> _books = [];
  List<AcBookIssue> _activeIssues = [];
  List<AcBookIssue> _overdueIssues = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _teal = Color(0xFF0D9488);
  static const _bg = Color(0xFFF0FDFA);
  final _fmt = DateFormat('dd MMM');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.listBooks(),
        _repository.listActiveIssues(),
        _repository.listOverdueIssues(),
      ]);
      setState(() {
        _books = results[0] as List<AcBook>;
        _activeIssues = results[1] as List<AcBookIssue>;
        _overdueIssues = results[2] as List<AcBookIssue>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<AcBook> get _filteredBooks {
    if (_searchQuery.isEmpty) return _books;
    final q = _searchQuery.toLowerCase();
    return _books
        .where(
          (b) =>
              b.title.toLowerCase().contains(q) ||
              b.author.toLowerCase().contains(q) ||
              (b.isbn ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildStats(),
          _buildSearch(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBooksCatalog(),
                      _buildActiveIssues(),
                      _buildOverdueIssues(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookDialog,
        backgroundColor: _teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Book',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      color: _bg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_library_outlined,
              color: _teal,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${_books.length} books · ${_activeIssues.length} issued',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: _teal),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _statCard(
            'Total Books',
            '${_books.length}',
            Icons.menu_book_outlined,
            _teal,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Issued',
            '${_activeIssues.length}',
            Icons.outbox_outlined,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Overdue',
            '${_overdueIssues.length}',
            Icons.warning_amber_outlined,
            Colors.orange,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Available',
            '${_books.fold(0, (s, b) => s + b.availableCopies)}',
            Icons.check_circle_outline,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search books by title, author or ISBN...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: [
          const Tab(text: 'Catalog'),
          Tab(text: 'Issued (${_activeIssues.length})'),
          Tab(text: 'Overdue (${_overdueIssues.length})'),
        ],
      ),
    );
  }

  Widget _buildBooksCatalog() {
    final books = _filteredBooks;
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_library_outlined,
              size: 56,
              color: _teal.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No books in library yet'
                  : 'No books found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildBookCard(books[i]),
    );
  }

  Widget _buildBookCard(AcBook book) {
    final isLow = book.availableCopies <= 1;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 56,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.book_outlined, color: _teal),
        ),
        title: Text(
          book.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.author,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            if (book.isbn != null)
              Text(
                'ISBN: ${book.isbn}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLow ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${book.availableCopies}/${book.totalCopies}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isLow ? Colors.orange.shade700 : Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.outbox_outlined,
                    size: 18,
                    color: _teal,
                  ),
                  tooltip: 'Issue Book',
                  onPressed: book.availableCopies > 0
                      ? () => _showIssueBookDialog(book)
                      : null,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  tooltip: 'Remove',
                  onPressed: () => _confirmDeleteBook(book),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildActiveIssues() {
    if (_activeIssues.isEmpty) {
      return const Center(
        child: Text(
          'No books currently issued',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: _activeIssues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildIssueCard(_activeIssues[i], false),
    );
  }

  Widget _buildOverdueIssues() {
    if (_overdueIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Colors.green.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'No overdue books! 🎉',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: _overdueIssues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildIssueCard(_overdueIssues[i], true),
    );
  }

  Widget _buildIssueCard(AcBookIssue issue, bool isOverdue) {
    final daysOverdue = isOverdue
        ? DateTime.now().difference(issue.dueDate).inDays
        : 0;
    final fine = daysOverdue * (issue.finePerDay ?? 2.0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isOverdue ? Border.all(color: Colors.orange.shade300) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOverdue
                    ? Colors.orange.shade50
                    : _teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.book_outlined,
                color: isOverdue ? Colors.orange : _teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.bookTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    issue.studentName,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Issued: ${_fmt.format(issue.issuedDate)} · Due: ${_fmt.format(issue.dueDate)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  if (isOverdue)
                    Text(
                      '$daysOverdue days overdue · Fine: ₹${fine.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _returnBook(issue, fine),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOverdue ? Colors.orange : _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Return'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBookDialog() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();
    final copiesCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Book to Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(titleCtrl, 'Book Title *', Icons.menu_book_outlined),
              const SizedBox(height: 12),
              _dialogField(authorCtrl, 'Author *', Icons.person_outline),
              const SizedBox(height: 12),
              _dialogField(isbnCtrl, 'ISBN (optional)', Icons.qr_code_outlined),
              const SizedBox(height: 12),
              _dialogField(
                copiesCtrl,
                'Number of Copies',
                Icons.copy_outlined,
                inputType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty ||
                  authorCtrl.text.trim().isEmpty)
                return;
              Navigator.pop(ctx);
              try {
                await _repository.addBook(
                  title: titleCtrl.text.trim(),
                  author: authorCtrl.text.trim(),
                  isbn: isbnCtrl.text.trim().isEmpty
                      ? null
                      : isbnCtrl.text.trim(),
                  copies: int.tryParse(copiesCtrl.text) ?? 1,
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Add Book'),
          ),
        ],
      ),
    );
  }

  void _showIssueBookDialog(AcBook book) {
    final studentCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 14));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Issue: ${book.title}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: studentCtrl,
                decoration: InputDecoration(
                  labelText: 'Student Name / ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setDialogState(() => dueDate = d);
                },
                icon: const Icon(Icons.date_range),
                label: Text('Due Date: ${_fmt.format(dueDate)}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (studentCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _repository.issueBook(
                    bookId: book.id,
                    studentName: studentCtrl.text.trim(),
                    dueDate: dueDate,
                  );
                  _loadData();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Book issued successfully'),
                        backgroundColor: Color(0xFF0D9488),
                      ),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              },
              child: const Text('Issue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _returnBook(AcBookIssue issue, double fine) async {
    try {
      await _repository.returnBook(
        issueId: issue.id,
        fineCollected: fine > 0 ? fine : null,
      );
      _loadData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fine > 0
                  ? 'Book returned. Fine: ₹${fine.toStringAsFixed(0)} collected.'
                  : 'Book returned successfully.',
            ),
            backgroundColor: _teal,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }

  void _confirmDeleteBook(AcBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Book?', style: TextStyle(color: Colors.red)),
        content: Text('Remove "${book.title}" from the library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteBook(bookId: book.id);
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? inputType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
      ),
    );
  }
}
