import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// MICRO TOOLBAR
// ============================================================================
// Minimalist floating toolbar for flash, grid, etc.
class MicroToolbar extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final bool isAutoCapture;
  final VoidCallback onToggleAuto;

  const MicroToolbar({
    super.key,
    required this.isFlashOn,
    required this.onToggleFlash,
    required this.isAutoCapture,
    required this.onToggleAuto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIcon(
            icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
            isActive: isFlashOn,
            onTap: onToggleFlash,
          ),
          // Grid toggle removed - feature not implemented
          GestureDetector(
            onTap: onToggleAuto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isAutoCapture
                    ? Colors.cyan.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAutoCapture ? Colors.cyan : Colors.white30,
                  width: 1,
                ),
              ),
              child: Text(
                isAutoCapture ? "AUTO" : "MANUAL",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isAutoCapture ? Colors.cyan : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 20,
        color: isActive ? Colors.yellowAccent : Colors.white,
      ),
    );
  }
}

// ============================================================================
// SHUTTER BUTTON
// ============================================================================
// Futuristic ring shutter button
class ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isProcessing;

  const ShutterButton({
    super.key,
    required this.onTap,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.transparent,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isProcessing ? 24 : 58,
            height: isProcessing ? 24 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isProcessing
                  ? Colors.white
                  : Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }
}
