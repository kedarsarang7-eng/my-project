class AgingBucket {
  final String label;
  final double amount;
  final int startDay;
  final int endDay; // -1 for infinity

  AgingBucket({
    required this.label,
    required this.amount,
    required this.startDay,
    required this.endDay,
  });
}

class AgingReport {
  final String partyId;
  final String partyName;
  final double totalDue;
  final List<AgingBucket> buckets;
  final DateTime generatedAt;

  AgingReport({
    required this.partyId,
    required this.partyName,
    required this.totalDue,
    required this.buckets,
    required this.generatedAt,
  });

  // Helper to get specific bucket amount
  double get zeroToThirty => _getAmount(0, 30);
  double get thirtyToSixty => _getAmount(31, 60);
  double get sixtyToNinety => _getAmount(61, 90);
  double get ninetyPlus => _getAmount(91, -1);

  double _getAmount(int start, int end) {
    return buckets
        .firstWhere(
          (b) => b.startDay == start && b.endDay == end,
          orElse: () =>
              AgingBucket(label: '', amount: 0, startDay: 0, endDay: 0),
        )
        .amount;
  }
}
