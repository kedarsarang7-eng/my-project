/// Atomic artifact store using temp-write + rename for the Certification_System.
///
/// Provides safe, atomic writes for persistent artifacts (traceability matrix,
/// production-readiness checklist, etc.). A failed or interrupted write leaves
/// the last good artifact intact and returns an error identifying the failed
/// update. Entries are append-preserved — prior content is never lost on update.
///
/// The write strategy:
/// 1. Write new content to a `.tmp` file in the same directory as the target.
/// 2. Rename `.tmp` to the target path (atomic on most filesystems).
/// 3. If step 1 or 2 fails, catch the error, clean up `.tmp` if it exists,
///    and return an error result. The original file is never partially modified.
///
/// Requirements: 13.6, 15.3
library;

import 'dart:io';

/// Result of an artifact write operation.
///
/// On success, [success] is true and [error] is null.
/// On failure, [success] is false and [error] identifies the failed update.
class ArtifactWriteResult {
  /// Whether the write completed successfully.
  final bool success;

  /// Non-null on failure — identifies the failed update operation and reason.
  final String? error;

  /// A successful write result.
  const ArtifactWriteResult.ok() : success = true, error = null;

  /// A failed write result with an error description.
  const ArtifactWriteResult.failed(String reason)
    : success = false,
      error = reason;
}

/// Atomic, append-preserving artifact store.
///
/// Uses temp-write + rename to ensure that a failed or interrupted write never
/// corrupts the last good artifact. Entries are append-preserved: when updating
/// an existing artifact, the new content is appended to the prior content
/// (unless the caller explicitly provides the full desired content).
class ArtifactStore {
  const ArtifactStore();

  /// Writes [content] to [path] atomically using temp-write + rename.
  ///
  /// If [append] is true (default), appends [content] to the existing artifact.
  /// If [append] is false, replaces the entire artifact with [content].
  ///
  /// On success, returns [ArtifactWriteResult.ok].
  /// On failure, the last good artifact at [path] remains intact and the result
  /// identifies the failed update with the error reason.
  Future<ArtifactWriteResult> write(
    String path,
    String content, {
    bool append = true,
  }) async {
    final targetFile = File(path);
    final tmpPath = '$path.tmp';
    final tmpFile = File(tmpPath);

    try {
      // Build final content: preserve prior entries when appending.
      String finalContent;
      if (append && await targetFile.exists()) {
        final existing = await targetFile.readAsString();
        finalContent = existing + content;
      } else {
        finalContent = content;
      }

      // Step 1: Write to .tmp file in the same directory.
      // Ensure the parent directory exists.
      final parentDir = tmpFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await tmpFile.writeAsString(finalContent, flush: true);

      // Step 2: Rename .tmp to the target path (atomic on most filesystems).
      await tmpFile.rename(path);

      return const ArtifactWriteResult.ok();
    } catch (e) {
      // Clean up .tmp if it exists — original file remains intact.
      await _cleanupTmp(tmpPath);

      return ArtifactWriteResult.failed(
        'Failed to write artifact at "$path": $e',
      );
    }
  }

  /// Reads the current content at [path], or null if the file does not exist.
  Future<String?> read(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  /// Attempts to delete a leftover .tmp file. Swallows errors — this is
  /// best-effort cleanup and must not throw.
  Future<void> _cleanupTmp(String tmpPath) async {
    try {
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (_) {
      // Best-effort cleanup — ignore failures.
    }
  }
}
