import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models/document_session.dart';

class EditorView extends ConsumerWidget {
  const EditorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(documentSessionProvider);
    final pages = session.pages;

    if (pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No pages to edit",
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "Capture or import images first",
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: pages.length,
      itemBuilder: (context, index) {
        final page = pages[index];
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
                image: DecorationImage(
                  image: FileImage(File(page.displayPath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "#${index + 1}",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  ref
                      .read(documentSessionProvider.notifier)
                      .removePage(page.id);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
