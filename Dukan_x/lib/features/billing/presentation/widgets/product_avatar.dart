// ============================================================================
// PRODUCT AVATAR WIDGET
// ============================================================================
// Renders a 32Ã—32 rounded square with:
//   1. S3 presigned image (if item.presignedImageUrl is set)
//   2. Category-resolved icon from BillTokens.categoryIconMap
//   3. Business-type fallback icon
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/bill.dart';
import 'bill_creation_tokens.dart';

class ProductAvatar extends StatelessWidget {
  final BillItem item;
  final double size;

  const ProductAvatar({
    super.key,
    required this.item,
    this.size = BillTokens.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Presigned S3 URL available â†’ CachedNetworkImage
    final imageUrl = item.presignedImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _iconFallback(),
          errorWidget: (context, url, error) => _iconFallback(),
        ),
      );
    }

    // 2. Resolve icon by category / name
    return _iconFallback();
  }

  Widget _iconFallback() {
    final resolved = _resolveCategory();
    final icon = BillTokens.categoryIconMap[resolved] ??
        BillTokens.categoryIconMap['default']!;
    final color = BillTokens.categoryColorMap[resolved] ??
        BillTokens.categoryColorMap['default']!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }

  String _resolveCategory() {
    // Check product name / category for known keywords
    final nameLower = item.productName.toLowerCase();

    for (final key in BillTokens.categoryIconMap.keys) {
      if (key == 'default') continue;
      if (nameLower.contains(key)) return key;
    }

    return 'default';
  }
}
