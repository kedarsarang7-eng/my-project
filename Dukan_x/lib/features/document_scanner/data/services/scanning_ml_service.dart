import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ScanningMlService {
  late ObjectDetector _objectDetector;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    // Use 'single' mode for stream for stability or stream mode
    // We want broad detection of 'document' like objects
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);
    _isInitialized = true;
  }

  Future<DetectedObject?> detectDocument(InputImage inputImage) async {
    if (!_isInitialized) initialize();

    try {
      final objects = await _objectDetector.processImage(inputImage);
      if (objects.isNotEmpty) {
        // Return the largest object (most likely the document)
        // Sort by area size?
        if (objects.length == 1) return objects.first;

        objects.sort(
          (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
            a.boundingBox.width * a.boundingBox.height,
          ),
        );
        return objects.first;
      }
    } catch (e) {
      // Ignore errors in stream
    }
    return null;
  }

  void dispose() {
    if (_isInitialized) {
      _objectDetector.close();
      _isInitialized = false;
    }
  }
}
