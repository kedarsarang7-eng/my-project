/// Collision-free cell-key encoding for variant grid cells.
///
/// Uses length-prefixed encoding so any two distinct (color, size) pairs yield
/// distinct keys — including values containing '_' (e.g., "Off_White").
///
/// Format: `{color.length}:{color}:{size}`
///   e.g., variantCellKey("Off_White", "S") → "9:Off_White:S"
///         variantCellKey("Off", "White_S")  → "3:Off:White_S"
///
/// These two keys are guaranteed distinct because the length prefix differs.
library;

/// Produces a collision-free key for a (color, size) pair.
///
/// The encoding is injective: distinct inputs always produce distinct outputs.
String variantCellKey(String color, String size) =>
    '${color.length}:$color:$size';

/// Parses a cell key produced by [variantCellKey] back into (color, size).
///
/// Returns a record `(String color, String size)` or throws [FormatException]
/// if the key is malformed.
({String color, String size}) parseVariantCellKey(String key) {
  final colonIdx = key.indexOf(':');
  if (colonIdx < 1) {
    throw FormatException(
      'Malformed variant cell key: missing length prefix',
      key,
    );
  }

  final lengthStr = key.substring(0, colonIdx);
  final colorLength = int.tryParse(lengthStr);
  if (colorLength == null || colorLength < 0) {
    throw FormatException(
      'Malformed variant cell key: invalid length prefix',
      key,
    );
  }

  // After the first colon, the next `colorLength` characters are the color,
  // followed by a colon separator, then the remainder is the size.
  final afterPrefix = colonIdx + 1;
  if (key.length < afterPrefix + colorLength + 1) {
    throw FormatException(
      'Malformed variant cell key: key too short for declared color length',
      key,
    );
  }

  final color = key.substring(afterPrefix, afterPrefix + colorLength);
  final separatorIdx = afterPrefix + colorLength;

  if (key[separatorIdx] != ':') {
    throw FormatException(
      'Malformed variant cell key: expected colon after color',
      key,
    );
  }

  final size = key.substring(separatorIdx + 1);
  return (color: color, size: size);
}
