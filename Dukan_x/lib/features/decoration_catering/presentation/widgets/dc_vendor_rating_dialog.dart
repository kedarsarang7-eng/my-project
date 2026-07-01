// ============================================================================
// DC Vendor Rating Dialog
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dc_models.dart';

class DcVendorRatingDialog extends ConsumerStatefulWidget {
  final DcVendor vendor;
  final Function(double rating, String comment) onSubmit;

  const DcVendorRatingDialog({
    super.key,
    required this.vendor,
    required this.onSubmit,
  });

  @override
  ConsumerState<DcVendorRatingDialog> createState() =>
      _DcVendorRatingDialogState();
}

class _DcVendorRatingDialogState extends ConsumerState<DcVendorRatingDialog> {
  double _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.vendor.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category: ${widget.vendor.category}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Star rating
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    onPressed: () =>
                        setState(() => _rating = starValue.toDouble()),
                    tooltip: 'Rate $starValue star${starValue > 1 ? 's' : ''}',
                    icon: Icon(
                      starValue <= _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
            ),
            Center(
              child: Text(
                _rating > 0 ? '${_rating.toInt()}/5 Stars' : 'Tap to rate',
                style: TextStyle(
                  color: _rating > 0
                      ? const Color(0xFF0D9488)
                      : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Comment field
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comments (Optional)',
                hintText: 'Share your experience with this vendor...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: (_rating == 0 || _submitting) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: Text(_submitting ? 'Submitting...' : 'Submit Rating'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_rating, _commentCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ============================================================================
// Vendor Rating Display Widget
// ============================================================================
class DcVendorRatingStars extends StatelessWidget {
  final double rating;
  final int? ratingCount;
  final double size;
  final bool showCount;

  const DcVendorRatingStars({
    super.key,
    required this.rating,
    this.ratingCount,
    this.size = 16,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final fullStars = rating.floor();
            final hasHalfStar = rating - fullStars >= 0.5;

            IconData icon;
            Color color;
            if (index < fullStars) {
              icon = Icons.star;
              color = Colors.amber;
            } else if (index == fullStars && hasHalfStar) {
              icon = Icons.star_half;
              color = Colors.amber;
            } else {
              icon = Icons.star_border;
              color = const Color(0xFFD1D5DB);
            }

            return Icon(icon, color: color, size: size);
          }),
        ),
        if (showCount && ratingCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($ratingCount)',
            style: TextStyle(
              fontSize: size * 0.75,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }
}
