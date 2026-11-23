import 'package:flutter/material.dart';

class PinPainter extends CustomPainter {
  final Color color;
  final Color holeColor;

  PinPainter({required this.color, required this.holeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const double headRadius = 16.0;
    const double stickWidth = 4.0;

    final double centerX = size.width / 2;

    final RRect stick = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX - (stickWidth / 2),
        headRadius,
        stickWidth,
        size.height - headRadius,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(stick, paint);

    final Offset headCenter = Offset(centerX, headRadius);
    canvas.drawCircle(headCenter, headRadius, paint);

    final Paint holePaint = Paint()
      ..color = holeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(headCenter, 5, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}