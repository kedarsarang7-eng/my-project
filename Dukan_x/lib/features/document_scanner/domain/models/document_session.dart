import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'scanned_page.dart';

/// Document Session State - Holds current scanning session data
class DocumentSessionState {
  final List<ScannedPage> pages;

  const DocumentSessionState({this.pages = const []});

  DocumentSessionState copyWith({List<ScannedPage>? pages}) {
    return DocumentSessionState(pages: pages ?? this.pages);
  }
}

/// Document Scanning Session State Manager
/// Uses Riverpod 3.x Notifier pattern
class DocumentSessionNotifier extends Notifier<DocumentSessionState> {
  @override
  DocumentSessionState build() => const DocumentSessionState();

  void addPage(String originalPath) {
    final id = const Uuid().v4();
    final page = ScannedPage(id: id, originalImagePath: originalPath);
    state = state.copyWith(pages: [...state.pages, page]);
  }

  void removePage(String id) {
    state = state.copyWith(
      pages: state.pages.where((p) => p.id != id).toList(),
    );
  }

  void updatePage(ScannedPage updatedPage) {
    state = state.copyWith(
      pages: [
        for (final page in state.pages)
          if (page.id == updatedPage.id) updatedPage else page,
      ],
    );
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = [...state.pages];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(pages: items);
  }

  void clear() {
    state = const DocumentSessionState();
  }
}

final documentSessionProvider =
    NotifierProvider<DocumentSessionNotifier, DocumentSessionState>(
      DocumentSessionNotifier.new,
    );
