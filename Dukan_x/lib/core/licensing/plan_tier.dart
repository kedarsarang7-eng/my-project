/// Normalizes plan labels from the backend (Super Admin / Dynamo) for ordering.
int planTierRank(String raw) {
  final p = raw.trim().toLowerCase();
  switch (p) {
    case 'basic':
    case 'starter':
    case 'free':
      return 0;
    case 'pro':
    case 'professional':
    case 'standard':
      return 1;
    case 'premium':
    case 'business':
      return 2;
    case 'enterprise':
    case 'ultimate':
      return 3;
    default:
      return 0;
  }
}

bool planMeetsOrExceeds(String currentPlan, String requiredPlan) {
  return planTierRank(currentPlan) >= planTierRank(requiredPlan);
}
