/// Allergy↔Prescription Contraindication Check Service
///
/// Cross-references prescribed drug names against a patient's recorded
/// allergies and returns any contraindications found. Used in the Rx-save
/// path to warn or block before persisting a potentially harmful prescription.
///
/// Requirement: 2.12 — warn/block on contraindication; non-contraindicated
/// drugs save unchanged.
library;

/// A single contraindication finding linking a medicine to an allergy.
class ContraindicationMatch {
  /// The prescribed medicine name that triggered the match.
  final String medicineName;

  /// The allergy entry from the patient record that matches.
  final String allergyEntry;

  const ContraindicationMatch({
    required this.medicineName,
    required this.allergyEntry,
  });

  @override
  String toString() =>
      'ContraindicationMatch(medicine: $medicineName, allergy: $allergyEntry)';
}

/// Result of a contraindication check.
class ContraindicationResult {
  /// List of all matches found. Empty means the prescription is safe.
  final List<ContraindicationMatch> matches;

  const ContraindicationResult({required this.matches});

  /// Whether any contraindications were detected.
  bool get hasContraindications => matches.isNotEmpty;

  /// Whether the prescription is safe (no contraindications).
  bool get isSafe => matches.isEmpty;
}

/// Known drug-family aliases. If a patient is allergic to a family name (key),
/// any member drug (values) is also contraindicated. Case-insensitive matching.
const Map<String, List<String>> _drugFamilyAliases = {
  'penicillin': [
    'amoxicillin',
    'ampicillin',
    'penicillin v',
    'penicillin g',
    'piperacillin',
    'nafcillin',
    'oxacillin',
    'dicloxacillin',
    'flucloxacillin',
    'augmentin',
    'amoxiclav',
    'co-amoxiclav',
  ],
  'sulfa': [
    'sulfamethoxazole',
    'sulfasalazine',
    'sulfadiazine',
    'trimethoprim-sulfamethoxazole',
    'bactrim',
    'cotrimoxazole',
    'septran',
  ],
  'nsaid': [
    'ibuprofen',
    'naproxen',
    'aspirin',
    'diclofenac',
    'ketorolac',
    'piroxicam',
    'indomethacin',
    'meloxicam',
    'celecoxib',
  ],
  'cephalosporin': [
    'cephalexin',
    'cefazolin',
    'ceftriaxone',
    'cefuroxime',
    'cefixime',
    'cefdinir',
    'ceftazidime',
    'cefpodoxime',
  ],
  'fluoroquinolone': [
    'ciprofloxacin',
    'levofloxacin',
    'moxifloxacin',
    'ofloxacin',
    'norfloxacin',
  ],
  'macrolide': [
    'azithromycin',
    'erythromycin',
    'clarithromycin',
    'roxithromycin',
  ],
  'statin': [
    'atorvastatin',
    'rosuvastatin',
    'simvastatin',
    'pravastatin',
    'lovastatin',
  ],
  'ace inhibitor': [
    'enalapril',
    'lisinopril',
    'ramipril',
    'captopril',
    'perindopril',
  ],
};

/// Checks prescribed medicines against a patient's allergy string.
///
/// [allergiesRaw] — the free-text allergies field from the patient record,
///   e.g. "Penicillin, Sulfa drugs". Comma/semicolon separated.
/// [medicineNames] — list of medicine names being prescribed.
///
/// Returns a [ContraindicationResult] containing all matches found.
/// An empty allergies field or empty medicine list always yields safe.
ContraindicationResult checkContraindications({
  required String? allergiesRaw,
  required List<String> medicineNames,
}) {
  if (allergiesRaw == null || allergiesRaw.trim().isEmpty) {
    return const ContraindicationResult(matches: []);
  }
  if (medicineNames.isEmpty) {
    return const ContraindicationResult(matches: []);
  }

  // Parse allergies: split on comma, semicolon, or newline; trim; lowercase.
  final allergyEntries = allergiesRaw
      .split(RegExp(r'[,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (allergyEntries.isEmpty) {
    return const ContraindicationResult(matches: []);
  }

  final matches = <ContraindicationMatch>[];

  for (final medicineName in medicineNames) {
    final medLower = medicineName.toLowerCase().trim();
    if (medLower.isEmpty) continue;

    for (final allergy in allergyEntries) {
      final allergyLower = allergy.toLowerCase();

      // 1. Direct substring match (either direction):
      //    - Patient allergic to "Penicillin" → "Penicillin V" matches
      //    - Patient allergic to "Amoxicillin" → "Amoxicillin" matches
      if (medLower.contains(allergyLower) || allergyLower.contains(medLower)) {
        matches.add(
          ContraindicationMatch(
            medicineName: medicineName,
            allergyEntry: allergy,
          ),
        );
        break; // One match per medicine is enough
      }

      // 2. Drug-family alias check:
      //    - Patient allergic to "Penicillin" → medicine "Amoxicillin" matches
      //      via the penicillin family.
      bool familyMatched = false;
      for (final entry in _drugFamilyAliases.entries) {
        final familyName = entry.key;
        final members = entry.value;

        // Does the allergy match this family?
        final allergyMatchesFamily =
            allergyLower.contains(familyName) ||
            familyName.contains(allergyLower);

        if (allergyMatchesFamily) {
          // Check if the medicine is a member of this family
          for (final member in members) {
            if (medLower.contains(member) || member.contains(medLower)) {
              matches.add(
                ContraindicationMatch(
                  medicineName: medicineName,
                  allergyEntry: allergy,
                ),
              );
              familyMatched = true;
              break;
            }
          }
        }

        if (familyMatched) break;

        // Reverse: does the allergy match a specific member? Then medicine
        // matching the family or another member is NOT automatically flagged
        // (we only expand family→members, not member→family for safety).
      }

      if (familyMatched) break;
    }
  }

  return ContraindicationResult(matches: matches);
}
