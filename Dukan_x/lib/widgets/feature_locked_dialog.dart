// ============================================================================
// Feature Locked Dialog — Plan Comparison + Upgrade CTA
// ============================================================================
// Shown when user taps a feature gated behind a higher plan tier.
// Displays current plan vs required plan with feature comparison.
// ============================================================================

import 'package:flutter/material.dart';

import '../guards/plan_tier_guard.dart';

class FeatureLockedDialog extends StatelessWidget {
  final PlanTier requiredTier;

  const FeatureLockedDialog({
    super.key,
    required this.requiredTier,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade700,
                    Colors.orange.shade600,
                  ],
                ),
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),

            Text(
              '${requiredTier.displayName} Feature',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature requires the ${requiredTier.displayName} plan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Plan comparison table
            _buildPlanComparison(context),
            const SizedBox(height: 24),

            // Upgrade CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Contact your administrator to upgrade your plan.',
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Upgrade to ${requiredTier.displayName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanComparison(BuildContext context) {
    final plans = [
      _PlanInfo(
        tier: PlanTier.basic,
        features: ['Billing', 'Inventory', 'Products', 'Customers'],
        color: Colors.grey,
      ),
      _PlanInfo(
        tier: PlanTier.premium,
        features: [
          'Everything in Basic',
          'Reports & Insights',
          'Multi-device',
          'GST Compliance',
          'WhatsApp Invoice',
        ],
        color: Colors.blueAccent,
      ),
      _PlanInfo(
        tier: PlanTier.enterprise,
        features: [
          'Everything in Premium',
          'Multi-branch',
          'API Access',
          'Audit Logs',
          'Advanced Analytics',
          'Priority Support',
        ],
        color: Colors.amber,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children:
            plans.where((p) => p.tier.index >= PlanTier.basic.index).map((
              plan,
            ) {
          final isRequired = plan.tier == requiredTier;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isRequired ? plan.color : Colors.transparent,
                width: isRequired ? 2 : 0,
              ),
              borderRadius: BorderRadius.circular(10),
              color: isRequired
                  ? plan.color.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(plan.tier.icon, color: plan.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      plan.tier.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isRequired ? 16 : 14,
                      ),
                    ),
                    if (isRequired) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: plan.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: Colors.green[400],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          f,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PlanInfo {
  final PlanTier tier;
  final List<String> features;
  final Color color;

  _PlanInfo({
    required this.tier,
    required this.features,
    required this.color,
  });
}
