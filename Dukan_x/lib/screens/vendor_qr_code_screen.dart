import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/di/service_locator.dart';
import '../services/connection_service.dart';
import '../core/session/session_manager.dart';

/// Vendor QR Code Screen - Display QR code for customers to scan
class VendorQRCodeScreen extends StatefulWidget {
  const VendorQRCodeScreen({super.key});

  @override
  State<VendorQRCodeScreen> createState() => _VendorQRCodeScreenState();
}

class _VendorQRCodeScreenState extends State<VendorQRCodeScreen> {
  String? _vendorUid;
  String? _vendorName;
  String? _qrData;
  bool _isLoading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  Future<void> _loadVendorData() async {
    try {
      final session = sl<SessionManager>();
      _vendorUid = session.userId;

      if (_vendorUid == null || _vendorUid!.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Use SessionManager for profile info
      final sessionData = session.currentSession;

      // If we are OWNER, we use our own ID.
      // If we are CUSTOMER, we typically don't have a "Shop QR",
      // but if this screen is accessible, maybe we do?
      // Assuming this screen is for VENDORS (Owners).

      _vendorName = sessionData.displayName ?? 'Shop';

      // Generate Generic Shop QR
      _qrData = sl<ConnectionService>().generateShopQr(_vendorUid!);
    } catch (e) {
      debugPrint('Error loading vendor data: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQRCode() async {
    if (_qrData == null || _vendorName == null) return;

    setState(() => _isSharing = true);

    try {
      // Generate QR image using qr_flutter's QrPainter
      final qrPainter = QrPainter(
        data: _qrData!,
        version: QrVersions.auto,
        gapless: true,
        color: const Color(0xFF0A0E21),
        emptyColor: Colors.white,
      );

      // Get image as ByteData (PNG format)
      final pictureData = await qrPainter.toImageData(300);
      if (pictureData == null) throw Exception('Failed to generate QR image');

      // pictureData is already ByteData in PNG format
      final bytes = Uint8List.view(pictureData.buffer);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shop_qr_code.png');
      await file.writeAsBytes(bytes);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code to connect with $_vendorName on DukanX!',
        subject: '$_vendorName - Shop QR Code',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Shop QR Code",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            )
          : ResponsiveContainer(child: _buildContent(isMobile)),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_qrData == null || _vendorUid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 64),
              const SizedBox(height: 24),
              Text(
                "Unable to generate QR Code",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Please ensure you're logged in as a vendor.",
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final shopName = Text(
      _vendorName ?? 'Shop',
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );

    final referenceTag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4FF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D4FF).withOpacity(0.3),
        ),
      ),
      child: Text(
        _vendorUid!,
        style: GoogleFonts.shareTechMono(
          color: const Color(0xFF00D4FF),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final qrCard = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: QrImageView(
            data: _qrData!,
            version: QrVersions.auto,
            size: 250,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0A0E21),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0A0E21),
            ),
          ),
        ),
      ),
    );

    final instructionsBox = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF00D4FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Share this QR code with customers",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionStep("1", "Customer opens dukanX app"),
          const SizedBox(height: 8),
          _buildInstructionStep(
            "2",
            "Scans this QR code from their dashboard",
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            "3",
            "Gets automatically linked to your shop",
          ),
        ],
      ),
    );

    final shareButton = SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSharing ? null : _shareQRCode,
        icon: _isSharing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.share_rounded),
        label: Text(
          _isSharing ? "Sharing..." : "Share QR Code",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D4FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: isMobile
          ? Column(
              children: [
                const SizedBox(height: 20),
                shopName,
                const SizedBox(height: 8),
                referenceTag,
                const SizedBox(height: 40),
                qrCard,
                const SizedBox(height: 40),
                instructionsBox,
                const SizedBox(height: 24),
                shareButton,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      shopName,
                      const SizedBox(height: 8),
                      referenceTag,
                      const SizedBox(height: 40),
                      qrCard,
                      const SizedBox(height: 24),
                      shareButton,
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      instructionsBox,
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
