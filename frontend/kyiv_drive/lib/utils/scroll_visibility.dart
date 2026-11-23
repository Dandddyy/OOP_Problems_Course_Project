import 'dart:math' as math;
import 'dart:ui';

double calculateMinimalRevealScrollDelta({
  required Rect targetRect,
  required Rect visibleRect,
  double projectedBottomDelta = 0,
}) {
  if (visibleRect.height <= 0) return 0;

  final effectiveTargetRect = Rect.fromLTRB(
    targetRect.left,
    targetRect.top,
    targetRect.right,
    math.max(targetRect.top, targetRect.bottom + projectedBottomDelta),
  );

  if (effectiveTargetRect.top >= visibleRect.top &&
      effectiveTargetRect.bottom <= visibleRect.bottom) {
    return 0;
  }

  if (effectiveTargetRect.height <= visibleRect.height) {
    if (effectiveTargetRect.bottom > visibleRect.bottom) {
      return effectiveTargetRect.bottom - visibleRect.bottom;
    }

    if (effectiveTargetRect.top < visibleRect.top) {
      return effectiveTargetRect.top - visibleRect.top;
    }

    return 0;
  }

  if (effectiveTargetRect.top < visibleRect.top) {
    return effectiveTargetRect.top - visibleRect.top;
  }

  if (effectiveTargetRect.bottom > visibleRect.bottom) {
    final bottomOverflow = effectiveTargetRect.bottom - visibleRect.bottom;
    final distanceToVisibleTop = effectiveTargetRect.top - visibleRect.top;
    return bottomOverflow.clamp(0.0, distanceToVisibleTop).toDouble();
  }

  return 0;
}
