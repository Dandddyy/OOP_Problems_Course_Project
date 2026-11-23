import 'dart:math' as math;
import 'dart:ui';

import '../core/constants/app_ui_tokens.dart';

const dashedRouteLineWidth = 2.0;

void paintDashedRouteLine(Canvas canvas, Offset start, Offset end) {
  const dashLength = 3.0;
  const gapLength = 4.0;
  final delta = end - start;
  final length = delta.distance;
  if (length == 0) return;

  final direction = delta / length;
  final paint = Paint()
    ..color = AppColors.iconMuted
    ..strokeWidth = dashedRouteLineWidth;
  for (var offset = 0.0; offset < length; offset += dashLength + gapLength) {
    canvas.drawLine(
      start + direction * offset,
      start + direction * math.min(offset + dashLength, length),
      paint,
    );
  }
}
