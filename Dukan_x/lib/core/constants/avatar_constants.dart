// Avatar Constants
// Defines the professional avatar collection for Indian vendors
//
// Created: 2024-12-26
// Author: DukanX Team

class AvatarConstants {
  static const String assetPath = 'assets/avatars';

  // Categories
  static const String categoryMale = 'male';
  static const String categoryFemale = 'female';
  static const String categoryNeutral = 'neutral';

  // Avatars List
  static const List<AvatarDefinition> avatars = [
    // Male Avatars (10)
    AvatarDefinition(
      id: 'm_01',
      category: categoryMale,
      label: 'Professional 1',
    ),
    AvatarDefinition(
      id: 'm_02',
      category: categoryMale,
      label: 'Professional 2',
    ),
    AvatarDefinition(id: 'm_03', category: categoryMale, label: 'Shop Owner 1'),
    AvatarDefinition(id: 'm_04', category: categoryMale, label: 'Shop Owner 2'),
    AvatarDefinition(id: 'm_05', category: categoryMale, label: 'Trader 1'),
    AvatarDefinition(id: 'm_06', category: categoryMale, label: 'Trader 2'),
    AvatarDefinition(id: 'm_07', category: categoryMale, label: 'Manager 1'),
    AvatarDefinition(id: 'm_08', category: categoryMale, label: 'Manager 2'),
    AvatarDefinition(id: 'm_09', category: categoryMale, label: 'Executive 1'),
    AvatarDefinition(id: 'm_10', category: categoryMale, label: 'Executive 2'),

    // Female Avatars (10)
    AvatarDefinition(
      id: 'f_01',
      category: categoryFemale,
      label: 'Professional 1',
    ),
    AvatarDefinition(
      id: 'f_02',
      category: categoryFemale,
      label: 'Professional 2',
    ),
    AvatarDefinition(
      id: 'f_03',
      category: categoryFemale,
      label: 'Shop Owner 1',
    ),
    AvatarDefinition(
      id: 'f_04',
      category: categoryFemale,
      label: 'Shop Owner 2',
    ),
    AvatarDefinition(id: 'f_05', category: categoryFemale, label: 'Trader 1'),
    AvatarDefinition(id: 'f_06', category: categoryFemale, label: 'Trader 2'),
    AvatarDefinition(id: 'f_07', category: categoryFemale, label: 'Manager 1'),
    AvatarDefinition(id: 'f_08', category: categoryFemale, label: 'Manager 2'),
    AvatarDefinition(
      id: 'f_09',
      category: categoryFemale,
      label: 'Executive 1',
    ),
    AvatarDefinition(
      id: 'f_10',
      category: categoryFemale,
      label: 'Executive 2',
    ),

    // Neutral/Brand Avatars (10)
    AvatarDefinition(id: 'n_01', category: categoryNeutral, label: 'Store 1'),
    AvatarDefinition(id: 'n_02', category: categoryNeutral, label: 'Store 2'),
    AvatarDefinition(id: 'n_03', category: categoryNeutral, label: 'Market 1'),
    AvatarDefinition(id: 'n_04', category: categoryNeutral, label: 'Market 2'),
    AvatarDefinition(id: 'n_05', category: categoryNeutral, label: 'Brand 1'),
    AvatarDefinition(id: 'n_06', category: categoryNeutral, label: 'Brand 2'),
    AvatarDefinition(
      id: 'n_07',
      category: categoryNeutral,
      label: 'Abstract 1',
    ),
    AvatarDefinition(
      id: 'n_08',
      category: categoryNeutral,
      label: 'Abstract 2',
    ),
    AvatarDefinition(id: 'n_09', category: categoryNeutral, label: 'Icon 1'),
    AvatarDefinition(id: 'n_10', category: categoryNeutral, label: 'Icon 2'),
  ];

  /// Get avatar asset path
  static String getAssetPath(String id, String category) {
    // Format: assets/avatars/male_m_01.png or similar convention
    // Simplified: assets/avatars/m_01.png
    // Based on user request: "av_m_03"
    // Let's standardise on: assets/avatars/{id}.png as IDs are unique (m_01, f_01 etc)
    return '$assetPath/$id.png';
  }

  /// Get default avatar
  static const AvatarDefinition defaultAvatar = AvatarDefinition(
    id: 'n_01',
    category: categoryNeutral,
    label: 'Default',
  );
}

class AvatarDefinition {
  final String id;
  final String category;
  final String label;

  const AvatarDefinition({
    required this.id,
    required this.category,
    required this.label,
  });

  String get assetPath => AvatarConstants.getAssetPath(id, category);
}
