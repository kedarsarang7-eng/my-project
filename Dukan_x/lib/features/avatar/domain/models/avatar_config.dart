/// Configuration constants for the Avatar System.
/// Defines the available options for each customizable part.
/// In a production system, this might be loaded from a remote JSON manifest.
class AvatarConfig {
  static const List<String> skinTones = [
    'light_01',
    'light_02',
    'medium_01',
    'medium_02',
    'dark_01',
    'dark_02',
  ];

  static const List<String> faceShapes = [
    'oval_01',
    'round_01',
    'square_01',
    'heart_01',
  ];

  static const List<String> hairStyles = [
    'short_01',
    'short_02',
    'medium_01',
    'long_01',
    'curly_01',
    'bald',
  ];

  static const List<String> hairColors = [
    'black',
    'brown',
    'blonde',
    'red',
    'grey',
    'white',
    'blue',
    'pink',
  ];

  static const List<String> eyes = ['round_01', 'almond_01', 'narrow_01'];

  static const List<String> eyebrows = [
    'natural_01',
    'thick_01',
    'thin_01',
    'arched_01',
  ];

  static const List<String> noses = ['medium_01', 'broad_01', 'pointed_01'];

  static const List<String> mouths = ['smile_01', 'neutral_01', 'open_01'];

  static const List<String> facialHair = [
    'none',
    'beard_light',
    'beard_full',
    'mustache_01',
  ];

  static const List<String> glasses = [
    'none',
    'rect_black',
    'round_gold',
    'sunglasses',
  ];

  static const List<String> tops = [
    'tshirt_white',
    'tshirt_black',
    'hoodie_grey',
    'jacket_denim',
    'shirt_formal',
  ];

  static const List<String> bottoms = [
    'jeans_blue',
    'jeans_black',
    'shorts_khaki',
    'joggers_grey',
    'trousers_formal',
  ];

  static const List<String> shoes = [
    'sneakers_white',
    'boots_brown',
    'shoes_formal_black',
    'sandals',
  ];

  static const List<String> accessories = [
    'none',
    'hat_cap',
    'hat_beanie',
    'necklace_gold',
  ];

  // Helper maps for UI labels
  static const Map<String, String> categoryLabels = {
    'skin': 'Skin',
    'face': 'Face',
    'hair': 'Hair',
    'eyes': 'Eyes',
    'brows': 'Brows',
    'nose': 'Nose',
    'mouth': 'Lips',
    'beard': 'Beard',
    'glasses': 'Glasses',
    'top': 'Top',
    'bottom': 'Pants',
    'shoes': 'Shoes',
    'acc': 'Extras',
  };
}
