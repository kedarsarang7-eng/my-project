import 'package:flutter/material.dart';
import 'package:dukanx/features/avatar/domain/models/avatar_data.dart';
import 'package:dukanx/features/avatar/data/services/avatar_asset_service.dart';

/// A widget that renders the avatar based on the provided AvatarData.
/// Uses a 2.5D layered approach with a Stack.
class AvatarPreviewWidget extends StatelessWidget {
  final AvatarData avatarData;
  final double width;
  final double height;
  final Color backgroundColor;

  /// Service to resolve asset paths and layering.
  /// In a production app with Riverpod, this might be passed via reference or provider.
  final AvatarAssetService _assetService = AvatarAssetService();

  AvatarPreviewWidget({
    super.key,
    required this.avatarData,
    this.width = 300,
    this.height = 300,
    this.backgroundColor = const Color(0xFFF0F0F0),
  });

  @override
  Widget build(BuildContext context) {
    final assetLayers = _assetService.getLayeredAssets(avatarData);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      // RepaintBoundary improves performance by isolating the avatar repaint
      // from the rest of the UI (useful when scrubbing lists below it).
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: assetLayers.map((assetPath) {
            return _buildAssetLayer(assetPath);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAssetLayer(String assetPath) {
    // Determine if it's SVG or PNG based on extension, though our service mostly returns PNGs currently.
    // Ideally we use Image.asset or SvgPicture.asset.
    // For now, scaling entire avatar to fit container.
    return Positioned.fill(
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        // Graceful error handling during development when assets are missing
        errorBuilder: (context, error, stackTrace) {
          // If in debug/dev mode, we might want to suppress error noise
          // or show a placeholder for critical parts like Body.
          // For now, return empty sized box to avoid ugly crash/error icon layers.
          // EXCEPT if it's the base skin, maybe show something?
          if (assetPath.contains('skin')) {
            return const Center(
              child: Icon(Icons.person, size: 48, color: Colors.grey),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
