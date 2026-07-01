// ============================================================================
// ACADEMIC COACHING — DEBOUNCED SEARCH WIDGET
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

class DebouncedSearchField extends StatefulWidget {
  final String hintText;
  final IconData? prefixIcon;
  final ValueChanged<String> onSearch;
  final Duration debounceDuration;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  const DebouncedSearchField({
    super.key,
    this.hintText = 'Search...',
    this.prefixIcon = Icons.search,
    required this.onSearch,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.controller,
    this.onClear,
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  String _lastSearch = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (value != _lastSearch) {
        _lastSearch = value;
        widget.onSearch(value);
      }
    });
  }

  void _clearSearch() {
    _controller.clear();
    _onSearchChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// Mixin for debouncing search in stateful widgets
mixin DebouncedSearchMixin<T extends StatefulWidget> on State<T> {
  Timer? _searchDebounceTimer;
  String _lastSearchQuery = '';

  void debouncedSearch(String query, VoidCallback searchCallback) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query != _lastSearchQuery) {
        _lastSearchQuery = query;
        searchCallback();
      }
    });
  }

  void cancelSearchDebounce() {
    _searchDebounceTimer?.cancel();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}

/// Hook-style debounce for Riverpod/functional approach
class SearchDebounceController extends ChangeNotifier {
  Timer? _timer;
  String _query = '';
  String get query => _query;

  void setQuery(String value, VoidCallback onExecute) {
    _query = value;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), onExecute);
    notifyListeners();
  }

  void executeImmediately(VoidCallback onExecute) {
    _timer?.cancel();
    onExecute();
  }

  void cancel() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
