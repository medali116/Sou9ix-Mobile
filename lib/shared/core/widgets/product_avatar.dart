import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';

/// Shows a product's real photo when available, falling back to its emoji
/// placeholder inside a rounded tinted square — used everywhere a product
/// is listed (POS grid, catalogue, cart rows, stock).
class ProductAvatar extends StatelessWidget {
  final String emoji;
  final Uint8List? photoBytes;
  final double size;
  final double emojiScale;

  const ProductAvatar({
    super.key,
    required this.emoji,
    this.photoBytes,
    this.size = 44,
    this.emojiScale = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size >= 40 ? AppRadius.sm : AppRadius.xs;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: photoBytes != null
            ? Image.memory(photoBytes!, fit: BoxFit.cover)
            : Container(
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: size * emojiScale),
                ),
              ),
      ),
    );
  }
}
