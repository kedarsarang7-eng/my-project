// Avatar Display Widget
// Reusable widget to display vendor avatar
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:flutter/material.dart';
import '../../../core/constants/avatar_constants.dart';
import '../../../models/vendor_profile.dart';

class AvatarDisplayWidget extends StatelessWidget {
  final AvatarData? avatar;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const AvatarDisplayWidget({
    super.key,
    this.avatar,
    this.size = 50,
    this.showBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine asset path
    // If no avatar is selected, we can show a default one or initials
    // For now, using the default avatar from constants
    final assetPath =
        avatar?.assetPath ?? AvatarConstants.defaultAvatar.assetPath;

    Widget image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback if asset missing (during development or if file deleted)
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Colors.grey.shade400,
          ),
        );
      },
    );

    if (showBorder) {
      image = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        ),
        child: ClipOval(child: image),
      );
    } else {
      image = ClipOval(child: image);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: image);
    }

    return image;
  }
}
