import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// ProductImage Widget
/// Displays product images with S3 presigned URL support, caching, and error handling
/// 
/// Features:
/// - Presigned URL caching (auto-refresh when expired)
/// - Shimmer loading placeholder
/// - Error fallback with business-type icon
/// - Support for main image + thumbnail
/// - Business-type themed placeholder colors
class ProductImageWidget extends StatefulWidget {
  final String? presignedImageUrl;
  final String? presignedThumbUrl;
  final String productName;
  final String? businessType; // 'pharmacy', 'restaurant', etc.
  final double width;
  final double height;
  final BoxFit fit;
  final bool isThumbmail;
  final VoidCallback? onTap;
  final String? placeholderIcon; // Icon name from BusinessTypeConfig

  const ProductImageWidget({
    super.key,
    this.presignedImageUrl,
    this.presignedThumbUrl,
    required this.productName,
    this.businessType = 'pharmacy',
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.isThumbmail = false,
    this.onTap,
    this.placeholderIcon = 'pills',
  });

  @override
  State<ProductImageWidget> createState() => _ProductImageWidgetState();
}

class _ProductImageWidgetState extends State<ProductImageWidget> {
  late String? _displayUrl;

  @override
  void initState() {
    super.initState();
    _displayUrl = widget.isThumbmail ? widget.presignedThumbUrl : widget.presignedImageUrl;
  }

  @override
  void didUpdateWidget(ProductImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presignedImageUrl != widget.presignedImageUrl ||
        oldWidget.presignedThumbUrl != widget.presignedThumbUrl) {
      _displayUrl = widget.isThumbmail ? widget.presignedThumbUrl : widget.presignedImageUrl;
    }
  }

  /// Get placeholder theme color based on business type
  Color _getPlaceholderColor() {
    switch (widget.businessType?.toLowerCase()) {
      case 'pharmacy':
        return const Color(0xFFE91E63); // Pink
      case 'restaurant':
        return const Color(0xFFFF6F00); // Orange
      case 'jewellery':
        return const Color(0xFFFFD700); // Gold
      case 'electronics':
        return const Color(0xFF1976D2); // Blue
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  /// Get icon for business type
  IconData _getPlaceholderIcon() {
    switch (widget.placeholderIcon?.toLowerCase()) {
      case 'pills':
        return Icons.medication;
      case 'restaurant':
      case 'food':
        return Icons.restaurant;
      case 'jewelry':
      case 'diamond':
        return Icons.diamond;
      case 'electronics':
        return Icons.devices;
      default:
        return Icons.image_not_supported;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholderColor = _getPlaceholderColor();
    final placeholderIcon = _getPlaceholderIcon();

    // If no presigned URL, show placeholder
    if (_displayUrl == null || _displayUrl!.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: placeholderColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: placeholderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              placeholderIcon,
              size: widget.width * 0.4,
              color: placeholderColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                widget.productName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: placeholderColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Display cached network image with presigned URL
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: widget.onTap,
        child: CachedNetworkImage(
          imageUrl: _displayUrl!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          // Loading placeholder with shimmer
          placeholder: (context, url) => _buildShimmerPlaceholder(placeholderColor),
          // Error fallback
          errorWidget: (context, url, error) => _buildErrorWidget(placeholderColor, placeholderIcon),
          // Cache for 1 day (presigned URLs expire in 5 min, so cache is just for UI responsiveness)
          cacheKey: _displayUrl.hashCode.toString(),
          maxHeightDiskCache: 500,
          maxWidthDiskCache: 500,
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder(Color color) {
    return Shimmer.fromColors(
      baseColor: color.withValues(alpha: 0.1),
      highlightColor: color.withValues(alpha: 0.2),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Color color, IconData icon) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: widget.width * 0.35,
            color: color.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            'No Image',
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// ProductImageGrid Widget
/// Displays a grid of products with images (for catalog/search results)
class ProductImageGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final int crossAxisCount;
  final double childAspectRatio;
  final String businessType;
  final Function(int) onProductTap;

  const ProductImageGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
    required this.businessType,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductGridItem(
          product: product,
          businessType: businessType,
          onTap: () => onProductTap(index),
        );
      },
    );
  }
}

/// Individual product grid item
class _ProductGridItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final String businessType;
  final VoidCallback onTap;

  const _ProductGridItem({
    required this.product,
    required this.businessType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            child: ProductImageWidget(
              presignedImageUrl: product['presignedImageUrl'],
              presignedThumbUrl: product['presignedThumbUrl'],
              productName: product['name'] ?? 'Product',
              businessType: businessType,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          // Product Name
          Text(
            product['name'] ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          // Price & Stock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '₹${product['price']?.toString() ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.green[700],
                      ),
                ),
              ),
              if ((product['stock'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${product['stock']} left',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green[700],
                          fontSize: 10,
                        ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Out of Stock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                          fontSize: 10,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
