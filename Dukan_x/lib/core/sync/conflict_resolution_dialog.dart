// ============================================================================
// CONFLICT RESOLUTION DIALOG
// ============================================================================
// UI for manual sync conflict resolution
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'sync_conflict.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Show conflict resolution dialog
Future<ConflictChoice?> showConflictResolutionDialog(
  BuildContext context,
  SyncConflict conflict,
) {
  return showDialog<ConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictResolutionDialog(conflict: conflict),
  );
}

/// Conflict Resolution Dialog Widget
class ConflictResolutionDialog extends StatelessWidget {
  final SyncConflict conflict;

  const ConflictResolutionDialog({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, hh:mm a');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Issue',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Data conflict in ${conflict.collection}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- COMPARISON ---
            IntrinsicHeight(
              child: Row(
                children: [
                  // Local Version
                  Expanded(
                    child: _buildVersionColumn(
                      context,
                      title: 'Your Version',
                      subtitle: 'Last Save',
                      time: dateFormat.format(conflict.localModifiedAt),
                      icon: Icons.phone_android_rounded,
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  // Server Version
                  Expanded(
                    child: _buildVersionColumn(
                      context,
                      title: 'Cloud Version',
                      subtitle: 'Server Time',
                      time: dateFormat.format(conflict.serverModifiedAt),
                      icon: Icons.cloud_done_rounded,
                      color: Colors.purple,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- DIFFERENCES ---
            if (conflict.differingFields.isNotEmpty) ...[
              Text(
                'Conflicting Fields (${conflict.differingFields.length})',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A35) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: conflict.differingFields.length.clamp(
                    0,
                    4,
                  ), // Max 4 lines
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                  ),
                  itemBuilder: (context, index) {
                    final field = conflict.differingFields[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              field,
                              style: GoogleFonts.robotoMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    _truncate(
                                      conflict.localData[field].toString(),
                                      10,
                                    ),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    _truncate(
                                      conflict.serverData[field].toString(),
                                      10,
                                    ),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 12,
                                      color: Colors.purple,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (conflict.differingFields.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '+ ${conflict.differingFields.length - 4} other fields',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 32),

            // --- ACTIONS ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, ConflictChoice.keepLocal),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Keep Mine',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, ConflictChoice.keepServer),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Use Cloud',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ConflictChoice.merge),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.merge_type_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Smart Merge (Recommended)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionColumn(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
        ),
        Text(
          time,
          style: GoogleFonts.robotoMono(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _truncate(String? text, int maxLength) {
    if (text == null) return 'null';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

/// Conflict Resolution Service
class ConflictResolutionService {
  static final ConflictResolutionService _instance =
      ConflictResolutionService._internal();
  factory ConflictResolutionService() => _instance;
  ConflictResolutionService._internal();

  /// Merge two data versions intelligently
  Map<String, dynamic> mergeData({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    required DateTime localModifiedAt,
    required DateTime serverModifiedAt,
  }) {
    final merged = <String, dynamic>{};

    // Start with server data (authoritative base)
    merged.addAll(serverData);

    // For each local field, decide whether to use it
    for (final entry in localData.entries) {
      if (entry.key.startsWith('_')) continue; // Skip metadata

      if (!serverData.containsKey(entry.key)) {
        // New field only in local - keep it
        merged[entry.key] = entry.value;
      } else if (localModifiedAt.isAfter(serverModifiedAt)) {
        // Local is newer - prefer local for non-critical fields
        if (!_isCriticalField(entry.key)) {
          merged[entry.key] = entry.value;
        }
      }
    }

    // Update version
    final localVersion = localData['_version'] as int? ?? 0;
    final serverVersion = serverData['_version'] as int? ?? 0;
    merged['_version'] =
        (localVersion > serverVersion ? localVersion : serverVersion) + 1;
    merged['_mergedAt'] = DateTime.now().toIso8601String();
    merged['_conflictResolved'] = true;

    return merged;
  }

  /// Check if field is critical (should prefer server version)
  bool _isCriticalField(String fieldName) {
    // Critical fields that should prefer server version to prevent data loss
    // during concurrent updates. These are financial/status fields where
    // the server is considered authoritative.
    const criticalFields = <String>[
      'grandTotal', // Financial totals must be consistent
      'paidAmount', // Payment amounts are critical for reconciliation
      'status', // Order/bill status should be authoritative
      'paymentStatus', // Payment status affects business logic
      'balance', // Customer balance must be accurate
    ];
    return criticalFields.contains(fieldName);
  }
}
