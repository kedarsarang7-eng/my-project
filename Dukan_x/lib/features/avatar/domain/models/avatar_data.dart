import 'package:equatable/equatable.dart';

/// Data model representing the state of a user's avatar.
/// Stored as a JSON string in the database.
class AvatarData extends Equatable {
  final String skinTone;
  final String faceShape;
  final String hairStyle;
  final String hairColor;
  final String eyes;
  final String eyebrows;
  final String nose;
  final String mouth;
  final String? glasses;
  final String? facialHair;
  final String outfitTop;
  final String outfitBottom;
  final String outfitShoes;
  final String? outfitAccessories;

  const AvatarData({
    required this.skinTone,
    required this.faceShape,
    required this.hairStyle,
    required this.hairColor,
    required this.eyes,
    required this.eyebrows,
    required this.nose,
    required this.mouth,
    this.glasses,
    this.facialHair,
    required this.outfitTop,
    required this.outfitBottom,
    required this.outfitShoes,
    this.outfitAccessories,
  });

  /// Default avatar configuration
  factory AvatarData.initial() {
    return const AvatarData(
      skinTone: 'light_01',
      faceShape: 'oval_01',
      hairStyle: 'short_01',
      hairColor: 'black',
      eyes: 'round_01',
      eyebrows: 'natural_01',
      nose: 'medium_01',
      mouth: 'smile_01',
      outfitTop: 'tshirt_white',
      outfitBottom: 'jeans_blue',
      outfitShoes: 'sneakers_white',
    );
  }

  factory AvatarData.fromJson(Map<String, dynamic> json) {
    return AvatarData(
      skinTone: json['skinTone'] as String? ?? 'light_01',
      faceShape: json['faceShape'] as String? ?? 'oval_01',
      hairStyle: json['hairStyle'] as String? ?? 'short_01',
      hairColor: json['hairColor'] as String? ?? 'black',
      eyes: json['eyes'] as String? ?? 'round_01',
      eyebrows: json['eyebrows'] as String? ?? 'natural_01',
      nose: json['nose'] as String? ?? 'medium_01',
      mouth: json['mouth'] as String? ?? 'smile_01',
      glasses: json['glasses'] as String?,
      facialHair: json['facialHair'] as String?,
      outfitTop: json['outfitTop'] as String? ?? 'tshirt_white',
      outfitBottom: json['outfitBottom'] as String? ?? 'jeans_blue',
      outfitShoes: json['outfitShoes'] as String? ?? 'sneakers_white',
      outfitAccessories: json['outfitAccessories'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skinTone': skinTone,
      'faceShape': faceShape,
      'hairStyle': hairStyle,
      'hairColor': hairColor,
      'eyes': eyes,
      'eyebrows': eyebrows,
      'nose': nose,
      'mouth': mouth,
      'glasses': glasses,
      'facialHair': facialHair,
      'outfitTop': outfitTop,
      'outfitBottom': outfitBottom,
      'outfitShoes': outfitShoes,
      'outfitAccessories': outfitAccessories,
    };
  }

  @override
  List<Object?> get props => [
    skinTone,
    faceShape,
    hairStyle,
    hairColor,
    eyes,
    eyebrows,
    nose,
    mouth,
    glasses,
    facialHair,
    outfitTop,
    outfitBottom,
    outfitShoes,
    outfitAccessories,
  ];

  AvatarData copyWith({
    String? skinTone,
    String? faceShape,
    String? hairStyle,
    String? hairColor,
    String? eyes,
    String? eyebrows,
    String? nose,
    String? mouth,
    String? glasses,
    String? facialHair,
    String? outfitTop,
    String? outfitBottom,
    String? outfitShoes,
    String? outfitAccessories,
  }) {
    return AvatarData(
      skinTone: skinTone ?? this.skinTone,
      faceShape: faceShape ?? this.faceShape,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyes: eyes ?? this.eyes,
      eyebrows: eyebrows ?? this.eyebrows,
      nose: nose ?? this.nose,
      mouth: mouth ?? this.mouth,
      glasses: glasses ?? this.glasses,
      facialHair: facialHair ?? this.facialHair,
      outfitTop: outfitTop ?? this.outfitTop,
      outfitBottom: outfitBottom ?? this.outfitBottom,
      outfitShoes: outfitShoes ?? this.outfitShoes,
      outfitAccessories: outfitAccessories ?? this.outfitAccessories,
    );
  }
}
