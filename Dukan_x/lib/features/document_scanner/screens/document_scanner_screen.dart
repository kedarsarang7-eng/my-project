import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../ml/ml_services/ocr_service.dart';
import '../../purchase/screens/add_purchase_screen.dart';

// Screens / Sub-widgets
import 'image_capture_view.dart';
import 'gallery_import_view.dart';
import 'editor_view.dart';

// State Management
import '../domain/models/document_session.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DocumentScannerScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const DocumentScannerScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<DocumentScannerScreen> createState() =>
      _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends ConsumerState<DocumentScannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _processDocuments() async {
    final session = ref.read(documentSessionProvider);
    final imagePaths = session.pages;
    if (imagePaths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No documents to process")));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final ocrService = sl<MLKitOcrService>();

      // Process first page for Vendor/Total (assuming first page is summary)
      // In future: Merge results from all pages
      final firstPagePath = imagePaths.first.displayPath;
      final result = await ocrService.recognizeTextAutoDetect(firstPagePath);

      // Map to PurchaseOrder
      final purchaseItems = result.items
          .map(
            (e) => PurchaseItem(
              id: const Uuid().v4(),
              productId: null,
              productName: e.name,
              quantity: e.quantity,
              unit: 'kg', // Default
              costPrice: e.price,
              taxRate: 0,
              totalAmount: e.amount,
            ),
          )
          .toList();

      final purchaseOrder = PurchaseOrder(
        id: const Uuid().v4(),
        userId: '', // Set by AddPurchaseScreen or Repo
        vendorName: result.shopName,
        invoiceNumber: '', // OCR might extract specific bill no.
        items: purchaseItems,
        totalAmount: result.totalAmount,
        purchaseDate: result.billDate ?? DateTime.now(),
        createdAt: DateTime.now(),
        paymentMode: 'Credit',
      );

      if (!mounted) return;

      // Navigate to AddPurchaseScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddPurchaseScreen(initialBill: purchaseOrder),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Processing failed: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(documentSessionProvider);
    final sessionImages = session.pages;
    final showFab = sessionImages.isNotEmpty && !_isProcessing;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text(
          "Scan & Edit",
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: "Camera"),
            Tab(icon: Icon(Icons.photo_library), text: "Import"),
            Tab(icon: Icon(Icons.edit), text: "Edit"),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : TabBarView(
              controller: _tabController,
              physics:
                  const NeverScrollableScrollPhysics(), // Prevent swipe to avoid conflict with gesture editors
              children: [
                ImageCaptureView(
                  onImageCaptured: (file) {
                    ref
                        .read(documentSessionProvider.notifier)
                        .addPage(file.path);
                    _tabController.animateTo(2); // Auto go to Edit
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Image captured!")),
                    );
                  },
                ),
                GalleryImportView(
                  onImagesImported: (files) {
                    for (var f in files) {
                      ref
                          .read(documentSessionProvider.notifier)
                          .addPage(f.path);
                    }
                    if (files.isNotEmpty) {
                      _tabController.animateTo(2); // Auto go to Edit
                    }
                  },
                ),
                const EditorView(),
              ],
            ),
      ),

      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _processDocuments,
              backgroundColor: Colors.cyan,
              icon: const Icon(Icons.check),
              label: const Text("FINISH & PROCESS"),
            )
          : null,
    );
  }
}
