import 'package:equatable/equatable.dart';

enum PageFilter { original, grayScale, blackAndWhite, magicColor }

class ScannedPage extends Equatable {
  final String id;
  final String originalImagePath;
  final String? processedImagePath; // After crop/filter
  final PageFilter filter;
  final List<double>? cropPoints; // Normalized 4 points [TL, TR, BR, BL]

  const ScannedPage({
    required this.id,
    required this.originalImagePath,
    this.processedImagePath,
    this.filter = PageFilter.original,
    this.cropPoints,
  });

  String get displayPath => processedImagePath ?? originalImagePath;

  ScannedPage copyWith({
    String? processedImagePath,
    PageFilter? filter,
    List<double>? cropPoints,
  }) {
    return ScannedPage(
      id: id,
      originalImagePath: originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      filter: filter ?? this.filter,
      cropPoints: cropPoints ?? this.cropPoints,
    );
  }

  @override
  List<Object?> get props => [
    id,
    originalImagePath,
    processedImagePath,
    filter,
    cropPoints,
  ];
}
