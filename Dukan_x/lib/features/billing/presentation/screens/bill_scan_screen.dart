import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/document_scanner/screens/document_scanner_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BillScanScreen extends ConsumerWidget {
  const BillScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redirect immediately to the new Enterprise Scanner
    // In production, this might verify permissions first or show an intro.
    return const DocumentScannerScreen();
  }
}
