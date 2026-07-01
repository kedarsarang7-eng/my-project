import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/di/service_locator.dart';
import '../services/connection_service.dart';
import '../core/session/session_manager.dart';

/// Customer Link Shop Screen - Scanner or Manual Entry
/// Allows customers to link to a vendor's shop via QR code or Owner ID
class CustomerLinkShopScreen extends StatefulWidget {
  final String? scannedQrData; // Optional: Pre-populated from QR scan

  const CustomerLinkShopScreen({super.key, this.scannedQrData});

  @override
  State<CustomerLinkShopScreen> createState() => _CustomerLinkShopScreenState();
}

class _CustomerLinkShopScreenState extends State<CustomerLinkShopScreen>
    with SingleTickerProviderStateMixin {
  final _ownerIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLinking = false;
  Map<String, dynamic>? _foundVendor;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Theme
  static const _primaryPurple = Color(0xFF8B5CF6);
  static const _bgDark = Color(0xFF0A0E21);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    // If QR data provided, parse and link
    if (widget.scannedQrData != null) {
      _handleQrData(widget.scannedQrData!);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _ownerIdController.dispose();
    super.dispose();
  }

  void _handleQrData(String qrData) async {
    // Parse QR logic consistent with ConnectionService
    // Format: v1:vendorId OR v1:vendorId:customerId:digest
    // We just want vendorId (which is the Owner ID usually)
    try {
      final parts = qrData.split(':');
      if (parts.length >= 2 && parts[0] == 'v1') {
        final vendorId = parts[1];
        _ownerIdController.text = vendorId;
        await _searchVendor();
      }
    } catch (e) {
      debugPrint('QR Parse error: $e');
    }
  }

  Future<void> _searchVendor() async {
    final ownerId = _ownerIdController.text.trim();
    if (ownerId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundVendor = null;
    });

    try {
      final shops = await sl<ConnectionService>().searchShops(ownerId);

      if (shops.isNotEmpty) {
        setState(() {
          _foundVendor = shops.first;
          // Ensure keys match what we expect
          // searchShops returns {id: ..., ownerId: ..., shopName: ..., ...}
          // Mapping for display:
          if (!_foundVendor!.containsKey('vendorName') &&
              _foundVendor!.containsKey('shopName')) {
            _foundVendor!['vendorName'] = _foundVendor!['shopName'];
          }
          if (!_foundVendor!.containsKey('uid')) {
            _foundVendor!['uid'] = _foundVendor!['id'];
          }
        });
      } else {
        _showError("No shop found with this Owner ID");
      }
    } catch (e) {
      _showError("Error searching: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkToVendor() async {
    if (_foundVendor == null) return;

    final customerUid = sl<SessionManager>().userId;
    if (customerUid == null || customerUid.isEmpty) {
      _showError("Please login first");
      return;
    }

    setState(() => _isLinking = true);

    try {
      final vendorId =
          _foundVendor!['uid'] ??
          _foundVendor!['id']; // ID of the shop (vendor UID)

      // Use ConnectionService to link
      await sl<ConnectionService>().linkShop(vendorId);

      _showSuccess("Request sent to ${_foundVendor!['vendorName']}!");
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop(true); // Return success
        });
      }
    } catch (e) {
      _showError("Error linking: $e");
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Link to Shop",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ResponsiveContainer(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 40),

                // QR Scan Button
                _buildQrScanButton(),
                const SizedBox(height: 24),

                // Or Divider
                _buildDivider(),
                const SizedBox(height: 24),

                // Manual Entry
                _buildManualEntry(),

                // Found Vendor Card
                if (_foundVendor != null) ...[
                  const SizedBox(height: 32),
                  _buildVendorCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_primaryPurple.withOpacity(0.2), Colors.transparent],
            ),
            border: Border.all(
              color: _primaryPurple.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          "Connect to a Shop",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Scan QR code or enter Shop Owner ID",
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildQrScanButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_primaryPurple.withOpacity(0.2), Colors.transparent],
        ),
        border: Border.all(color: _primaryPurple.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Navigate to QR scanner
            final result = await context.push<String>('/qr_scanner');
            if (result is String) {
              _handleQrData(result);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryPurple.withOpacity(0.3),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Scan QR Code",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Scan the shop's QR code to connect",
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _primaryPurple.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "OR",
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter Owner ID",
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ownerIdController,
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: "DX-VND-XXXXXXXXXX-XXXX",
              hintStyle: GoogleFonts.shareTechMono(
                color: Colors.white24,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: _primaryPurple.withOpacity(0.7),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryPurple.withOpacity(0.5)),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return "Required";
              // We've loosened the format slightly or we can assume searchShops handles validation logic
              // if (!val.startsWith("DX-VND-")) return "Invalid Owner ID format";
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _searchVendor();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Search Shop",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00FF88).withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF00FF88),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _foundVendor!['vendorName'] ?? 'Shop',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _foundVendor!['ownerId'] ?? '',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.verified,
                    color: Color(0xFF00FF88),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLinking ? null : _linkToVendor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF0A0E21),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLinking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFF0A0E21),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Link to This Shop",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
