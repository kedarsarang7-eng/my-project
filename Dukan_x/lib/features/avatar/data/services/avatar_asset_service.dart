import 'package:dukanx/features/avatar/domain/models/avatar_data.dart';

/// Service to handle avatar asset paths and layering logic.
class AvatarAssetService {
  static const String _basePath = 'assets/avatar';

  /// Returns a list of asset paths sorted by Z-index (back to front).
  ///
  /// Layer Order:
  /// 1. Body Base (Skin)
  /// 2. Face Shape
  /// 3. Eyes
  /// 4. Eyebrows
  /// 5. Nose
  /// 6. Mouth
  /// 7. Facial Hair (Optional)
  /// 8. Bottom Wear (Pants often go under shirts)
  /// 9. Top Wear (Shirts)
  /// 10. Shoes
  /// 11. Hair (Rear/Front handling simplified for now)
  /// 12. Glasses
  /// 13. Accessories
  List<String> getLayeredAssets(AvatarData data) {
    final layers = <String>[];

    // 1. Body/Skin Base
    layers.add('$_basePath/skin/${data.skinTone}.png');

    // 2. Face Shape (if distinct from base, otherwise part of skin)
    // Assuming face shape modifies the head outline
    layers.add('$_basePath/face/${data.faceShape}_${data.skinTone}.png');

    // 3. Eyes
    layers.add('$_basePath/eyes/${data.eyes}.png');

    // 4. Eyebrows
    layers.add('$_basePath/eyebrows/${data.eyebrows}.png');

    // 5. Nose
    layers.add('$_basePath/nose/${data.nose}_${data.skinTone}.png');

    // 6. Mouth
    layers.add('$_basePath/mouth/${data.mouth}.png');

    // 7. Facial Hair
    if (data.facialHair != null && data.facialHair!.isNotEmpty) {
      layers.add('$_basePath/facial_hair/${data.facialHair}.png');
    }

    // 8. Bottom Wear
    layers.add('$_basePath/clothes/bottom/${data.outfitBottom}.png');

    // 9. Top Wear
    layers.add('$_basePath/clothes/top/${data.outfitTop}.png');

    // 10. Shoes
    layers.add('$_basePath/clothes/shoes/${data.outfitShoes}.png');

    // 11. Hair
    // Note: Hair color is applied via color filter in the widget typically,
    // or we load pre-colored assets. For now, assuming pre-colored or mask.
    // If separate HairColor is needed, the widget will handle tinting.
    layers.add('$_basePath/hair/${data.hairStyle}.png');

    // 12. Glasses
    if (data.glasses != null && data.glasses!.isNotEmpty) {
      layers.add('$_basePath/accessories/glasses/${data.glasses}.png');
    }

    // 13. Accessories
    if (data.outfitAccessories != null && data.outfitAccessories!.isNotEmpty) {
      layers.add('$_basePath/accessories/misc/${data.outfitAccessories}.png');
    }

    return layers;
  }

  /// Returns color hex code for hair if dynamic tinting is used
  // String getHairColor(String colorName) { ... }
}
