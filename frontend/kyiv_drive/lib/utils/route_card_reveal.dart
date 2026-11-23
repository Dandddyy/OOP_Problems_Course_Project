import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/top_bar_widget.dart';
import 'scroll_visibility.dart';

/// Prefer the whole card; for an oversized card reveal its lower portion so
/// the refresh action stays visible instead of pinning only the button on top.
Rect calculateRouteCardRevealTargetRect({
  required Rect cardRect,
  required Rect visibleRect,
}) {
  return Rect.fromLTRB(
    cardRect.left,
    math.max(cardRect.top, cardRect.bottom - math.max(0.0, visibleRect.height)),
    cardRect.right,
    cardRect.bottom,
  );
}

void scheduleRouteCardReveal({
  required BuildContext context,
  required ScrollController scrollController,
  required GlobalKey cardKey,
  required GlobalKey viewportKey,
  required double bottomClearance,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !scrollController.hasClients) return;

    final card = cardKey.currentContext?.findRenderObject();
    final viewport = viewportKey.currentContext?.findRenderObject();
    if (card is! RenderBox ||
        viewport is! RenderBox ||
        !card.attached ||
        !viewport.attached) {
      return;
    }

    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    final visibleRect = Rect.fromLTRB(
      viewportRect.left,
      viewportRect.top +
          AppTopBarOverlayLayout.contentInsetOf(viewportKey.currentContext!),
      viewportRect.right,
      viewportRect.bottom - bottomClearance,
    );
    if (visibleRect.height <= 0) return;

    final cardRect = card.localToGlobal(Offset.zero) & card.size;
    final targetRect = calculateRouteCardRevealTargetRect(
      cardRect: cardRect,
      visibleRect: visibleRect,
    );
    final delta = calculateMinimalRevealScrollDelta(
      targetRect: targetRect,
      visibleRect: visibleRect,
    );
    if (delta.abs() < 0.5) return;

    final position = scrollController.position;
    final targetOffset = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 0.5) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      scrollController.jumpTo(targetOffset);
    } else {
      unawaited(
        scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  });
}
