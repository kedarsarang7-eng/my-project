import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Small product thumbnail for bill items
/// Displays 40x40 cached image with fallback placeholder
class ProductThumbnail extends StatelessWidget {
  final String? presignedImageUrl;
  final String productName;
  final String businessType;
  final double size;

  const ProductThumbnail({
    super.key,
    this.presignedImageUrl,
    required this.productName,
    required this.businessType,
    this.size = 40,
  });

  /// Get placeholder icon based on business type
  IconData _getPlaceholderIcon() {
    switch (businessType.toLowerCase()) {
      case 'pharmacy':
        return Icons.medication;
      case 'restaurant':
        return Icons.restaurant;
      case 'clothing':
        return Icons.checkroom;
      case 'electronics':
      case 'mobile_shop':
        return Icons.phone_android;
      case 'computer_shop':
        return Icons.computer;
      case 'jewelry':
      case 'jewellery':
        return Icons.diamond;
      case 'book_store':
        return Icons.book;
      case 'auto_parts':
        return Icons.build;
      default:
        return Icons.shopping_bag;
    }
  }

  /// Get placeholder color based on business type
  Color _getPlaceholderColor() {
    switch (businessType.toLowerCase()) {
      case 'pharmacy':
        return const Color(0xFFE91E63); // Pink
      case 'restaurant':
        return const Color(0xFFFF6F00); // Orange
      case 'clothing':
        return const Color(0xFFDB2777); // Pink
      case 'electronics':
      case 'mobile_shop':
        return const Color(0xFF1976D2); // Blue
      case 'computer_shop':
        return const Color(0xFF3B82F6); // Light Blue
      case 'jewelry':
      case 'jewellery':
        return const Color(0xFFFFD700); // Gold
      case 'book_store':
        return const Color(0xFF8B4513); // Brown
      case 'auto_parts':
        return const Color(0xFF424242); // Grey
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (presignedImageUrl == null || presignedImageUrl!.isEmpty) {
      // Placeholder
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _getPlaceholderColor().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _getPlaceholderColor().withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            _getPlaceholderIcon(),
            size: size * 0.6,
            color: _getPlaceholderColor(),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: presignedImageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheKey: presignedImageUrl.hashCode.toString(),
      placeholder: (context, url) => _buildShimmer(),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      memCacheHeight: (size * 2).toInt(),
      memCacheWidth: (size * 2).toInt(),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getPlaceholderColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getPlaceholderColor().withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          _getPlaceholderIcon(),
          size: size * 0.5,
          color: _getPlaceholderColor(),
        ),
      ),
    );
  }
}
