import 'package:flutter/material.dart';

/// Foto dengan bingkai membulat. Foto dipotong pas di sudut bingkai lalu
/// bingkainya digambar DI ATAS foto, jadi tidak ada sisa sudut putih di
/// antara foto dan bingkai (Container dengan `decoration` menggeser foto ke
/// dalam setebal bingkai tapi memotongnya di lengkung luar).
class FramedPhoto extends StatelessWidget {
  const FramedPhoto({
    super.key,
    required this.radius,
    required this.borderWidth,
    required this.child,
    this.borderColor = Colors.white,
    this.background,
  });

  final double radius;
  final double borderWidth;
  final Color borderColor;
  final Color? background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: ColoredBox(
          color: background ?? Colors.transparent,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}
