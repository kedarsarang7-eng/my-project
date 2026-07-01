import 'package:flutter/material.dart';

enum IDCardTemplate { standard, modern, compact, premium }

enum PhotoMode { existing, upload, camera }

enum IDCodeType { none, qr, barcode, both }

enum CardSize { standard, compact, lanyard }

class IDCardSettings {
  final IDCardTemplate template;
  final PhotoMode photoMode;
  final String? photoPath;
  final IDCodeType codeType;
  final Color primaryColor;
  final CardSize cardSize;

  const IDCardSettings({
    this.template = IDCardTemplate.standard,
    this.photoMode = PhotoMode.existing,
    this.photoPath,
    this.codeType = IDCodeType.qr,
    this.primaryColor = const Color(0xFF1E3A5F),
    this.cardSize = CardSize.standard,
  });

  IDCardSettings copyWith({
    IDCardTemplate? template,
    PhotoMode? photoMode,
    String? photoPath,
    IDCodeType? codeType,
    Color? primaryColor,
    CardSize? cardSize,
  }) {
    return IDCardSettings(
      template: template ?? this.template,
      photoMode: photoMode ?? this.photoMode,
      photoPath: photoPath ?? this.photoPath,
      codeType: codeType ?? this.codeType,
      primaryColor: primaryColor ?? this.primaryColor,
      cardSize: cardSize ?? this.cardSize,
    );
  }
}
