import 'package:flutter/material.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';

/// The four gold corner brackets used to frame a barcode scan target.
class ScanCornerMarks extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;

  const ScanCornerMarks({
    super.key,
    this.color = AppColors.gold,
    this.size = 26,
    this.thickness = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(4, (i) {
        final isTop = i < 2;
        final isLeft = i.isEven;
        return Positioned(
          top: isTop ? -3 : null,
          bottom: isTop ? null : -3,
          left: isLeft ? -3 : null,
          right: isLeft ? null : -3,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: isTop
                    ? BorderSide(color: color, width: thickness)
                    : BorderSide.none,
                bottom: !isTop
                    ? BorderSide(color: color, width: thickness)
                    : BorderSide.none,
                left: isLeft
                    ? BorderSide(color: color, width: thickness)
                    : BorderSide.none,
                right: !isLeft
                    ? BorderSide(color: color, width: thickness)
                    : BorderSide.none,
              ),
            ),
          ),
        );
      }),
    );
  }
}
