// Filter Screen
//
// Swipeable filter selection with live preview.
// Futuristic UI with minimal controls.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/p2d_theme.dart';
import '../widgets/widgets.dart';
import '../../logic/image_filters.dart';
import 'p2d_ocr_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class P2DFilterScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final bool autoEnhance;

  const P2DFilterScreen({
    super.key,
    required this.imageBytes,
    this.autoEnhance = true,
  });

  @override
  State<P2DFilterScreen> createState() => _P2DFilterScreenState();
}

class _P2DFilterScreenState extends State<P2DFilterScreen> {
  P2DFilter _selectedFilter = P2DFilter.digitalClean;
  Uint8List? _processedImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoEnhance) {
      _applyFilter(P2DFilter.digitalClean);
    } else {
      _processedImage = widget.imageBytes;
    }
  }

  Future<void> _applyFilter(P2DFilter filter) async {
    setState(() {
      _selectedFilter = filter;
      _isProcessing = true;
    });

    try {
      final imageFilter = switch (filter) {
        P2DFilter.reality => ImageFilter.reality,
        P2DFilter.digitalClean => ImageFilter.digitalClean,
        P2DFilter.ultraBW => ImageFilter.ultraBW,
        P2DFilter.receiptBoost => ImageFilter.receiptBoost,
        P2DFilter.sharpPro => ImageFilter.sharpPro,
      };

      final result = await ImageFilters.apply(widget.imageBytes, imageFilter);

      if (mounted) {
        setState(() {
          _processedImage = result ?? widget.imageBytes;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Filter error: $e');
      if (mounted) {
        setState(() {
          _processedImage = widget.imageBytes;
          _isProcessing = false;
        });
      }
    }
  }

  void _proceed() {
    if (_processedImage == null) return;

    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2DOcrScreen(imageBytes: _processedImage!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kP2DBackground,
      body: Center(
        child: BoundedBox(
          maxWidth: 600,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image preview
              if (_processedImage != null)
                Center(
                  child: AnimatedOpacity(
                    opacity: _isProcessing ? 0.5 : 1.0,
                    duration: kP2DAnimationFast,
                    child: Image.memory(_processedImage!, fit: BoxFit.contain),
                  ),
                ),

              // Processing indicator
              if (_isProcessing)
                const Center(
                  child: CircularProgressIndicator(color: kP2DAccentCyan),
                ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kP2DBackground, kP2DBackground.withOpacity(0)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NeonButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Enhance',
                        style: TextStyle(
                          color: kP2DTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      NeonButton(
                        icon: Icons.arrow_forward_rounded,
                        onTap: _isProcessing ? () {} : _proceed,
                        isActive: !_isProcessing,
                        color: kP2DGlowSuccess,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom filter carousel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    top: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [kP2DBackground, kP2DBackground.withOpacity(0)],
                    ),
                  ),
                  child: FilterCarousel(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: _applyFilter,
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
