// ============================================================================
// RATE & REVIEW SCREEN (CUSTOMER)
// ============================================================================
// Allows customers to rate their dining experience

import 'package:flutter/material.dart';

import '../../../../../core/theme/futuristic_colors.dart';
import '../../../data/repositories/food_order_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RateReviewScreen extends StatefulWidget {
  final String orderId;
  final String restaurantName;

  const RateReviewScreen({
    super.key,
    required this.orderId,
    required this.restaurantName,
    this.review,
  });

  final Map<String, dynamic>? review;

  @override
  State<RateReviewScreen> createState() => _RateReviewScreenState();
}

class _RateReviewScreenState extends State<RateReviewScreen> {
  final FoodOrderRepository _orderRepo = FoodOrderRepository();

  // Rating values (1-5)
  int _overallRating = 0;
  int _foodRating = 0;
  int _serviceRating = 0;
  int _ambienceRating = 0;

  // Review text
  final _reviewController = TextEditingController();

  // Selected tags
  final Set<String> _selectedTags = {};

  bool _isSubmitting = false;

  final List<String> _positiveTags = [
    'Great food',
    'Quick service',
    'Friendly staff',
    'Clean & hygienic',
    'Good ambience',
    'Value for money',
    'Will visit again',
    'Perfect portions',
    'Like it',
    'Will visit again',
    'Perfect portions',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.review != null) {
      _overallRating = (widget.review!['rating'] as num?)?.toInt() ?? 0;
      _reviewController.text = widget.review!['text'] as String? ?? '';
    }
  }

  final List<String> _improvementTags = [
    'Slow service',
    'Could be cleaner',
    'Too spicy',
    'Too salty',
    'Small portions',
    'Overpriced',
    'Noisy',
    'Wait time',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant name
            Center(
              child: Column(
                children: [
                  const Icon(Icons.restaurant, size: 48, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    widget.restaurantName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How was your experience?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Overall rating
            _buildRatingSection(
              title: 'Overall Experience',
              rating: _overallRating,
              onRatingChanged: (rating) =>
                  setState(() => _overallRating = rating),
              size: 48,
              isMain: true,
            ),

            const SizedBox(height: 24),

            // Detailed ratings
            _buildRatingSection(
              title: 'Food Quality',
              icon: Icons.restaurant_menu,
              rating: _foodRating,
              onRatingChanged: (rating) => setState(() => _foodRating = rating),
            ),
            const SizedBox(height: 16),
            _buildRatingSection(
              title: 'Service',
              icon: Icons.room_service,
              rating: _serviceRating,
              onRatingChanged: (rating) =>
                  setState(() => _serviceRating = rating),
            ),
            const SizedBox(height: 16),
            _buildRatingSection(
              title: 'Ambience',
              icon: Icons.chair_alt,
              rating: _ambienceRating,
              onRatingChanged: (rating) =>
                  setState(() => _ambienceRating = rating),
            ),

            const SizedBox(height: 24),

            // Quick feedback tags
            if (_overallRating > 0) ...[
              Text(
                _overallRating >= 4
                    ? 'What did you love?'
                    : 'What could be improved?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (_overallRating >= 4 ? _positiveTags : _improvementTags)
                        .map((tag) => _buildTag(tag))
                        .toList(),
              ),
            ],

            const SizedBox(height: 24),

            // Review text
            Text(
              'Write a review (optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _overallRating > 0 && !_isSubmitting
                    ? _submitReview
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SUBMIT REVIEW',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Skip button
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    IconData? icon,
    required int rating,
    required ValueChanged<int> onRatingChanged,
    double size = 32,
    bool isMain = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: isMain
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: isMain
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: List.generate(5, (index) {
            final starRating = index + 1;
            return GestureDetector(
              onTap: () => onRatingChanged(starRating),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    starRating <= rating ? Icons.star : Icons.star_outline,
                    size: size,
                    color: starRating <= rating
                        ? _getStarColor(rating)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          }),
        ),
        if (isMain && rating > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                _getRatingLabel(rating),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getStarColor(rating),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTag(String tag) {
    final isSelected = _selectedTags.contains(tag);
    return FilterChip(
      label: Text(tag),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTags.add(tag);
          } else {
            _selectedTags.remove(tag);
          }
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Color _getStarColor(int rating) {
    if (rating >= 4) return FuturisticColors.success;
    if (rating == 3) return Colors.orange;
    return FuturisticColors.error;
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return 'Excellent! 🌟';
      case 4:
        return 'Great! 😊';
      case 3:
        return 'Good 👍';
      case 2:
        return 'Fair 😐';
      case 1:
        return 'Poor 😞';
      default:
        return '';
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    try {
      // Create review data
      final review = {
        'orderId': widget.orderId,
        'overallRating': _overallRating,
        'foodRating': _foodRating,
        'serviceRating': _serviceRating,
        'ambienceRating': _ambienceRating,
        'tags': _selectedTags.toList(),
        'reviewText': _reviewController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Submit review (would be saved to database)
      await _orderRepo.submitOrderReview(widget.orderId, review);

      if (mounted) {
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! 🎉'),
            backgroundColor: FuturisticColors.success,
          ),
        );

        // Navigate back
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: FuturisticColors.error,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// Quick rating dialog for simple feedback
class QuickRatingDialog extends StatefulWidget {
  final String orderId;
  final String restaurantName;

  const QuickRatingDialog({
    super.key,
    required this.orderId,
    required this.restaurantName,
  });

  @override
  State<QuickRatingDialog> createState() => _QuickRatingDialogState();

  static Future<int?> show(
    BuildContext context, {
    required String orderId,
    required String restaurantName,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) =>
          QuickRatingDialog(orderId: orderId, restaurantName: restaurantName),
    );
  }
}

class _QuickRatingDialogState extends State<QuickRatingDialog> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'How was your meal?',
            style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starRating = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starRating),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starRating <= _rating ? Icons.star : Icons.star_outline,
                    size: 40,
                    color: starRating <= _rating
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _rating > 0
              ? () {
                  Navigator.pop(context, _rating);
                  // If low rating, open full review screen
                  if (_rating < 4) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RateReviewScreen(
                          orderId: widget.orderId,
                          restaurantName: widget.restaurantName,
                        ),
                      ),
                    );
                  }
                }
              : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
