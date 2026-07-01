import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ScanImageService {
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  Future<String?> pickImage(ImageSource source) async {
    // For Desktop (Windows/macOS) and Web, file_picker is often more reliable
    if (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isMacOS))) {
      if (source == ImageSource.gallery) {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        return result?.files.single.path;
      }
      // On Web/Desktop, Camera source via image_picker might work,
      // but let's stick to image_picker for now as it handles the UI if possible.
    }

    final XFile? file = await _picker.pickImage(source: source);
    return file?.path;
  }

  Future<String?> cropImage(String path, BuildContext context) async {
    final croppedFile = await _cropper.cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Bill',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Bill'),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 520),
        ),
      ],
    );
    return croppedFile?.path;
  }
}
