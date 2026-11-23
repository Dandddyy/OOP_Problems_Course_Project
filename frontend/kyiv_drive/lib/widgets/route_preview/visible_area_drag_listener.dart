import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../core/constants/app_ui_tokens.dart';

/// Keeps a native reorder drag out of fixed overlays and scrolls at the edges
/// of the usable viewport. The native drag still owns the proxy and row gaps.
class VisibleAreaDragController extends DragBoundaryDelegate<Rect> {
  final Rect? Function() visibleViewport;
  ScrollableState? _scrollable;
  EdgeDraggingAutoScroller? _autoScroller;
  Drag? _nativeDrag;

  VisibleAreaDragController({required this.visibleViewport});

  void attach(ScrollableState? scrollable) {
    if (_scrollable == scrollable) return;
    _stopScrolling();
    _scrollable = scrollable;
    _autoScroller = scrollable == null
        ? null
        : EdgeDraggingAutoScroller(
            scrollable,
            velocityScalar: 50,
            onScrollViewScrolled: () {
              // Re-evaluate the native gaps while the finger stays at an edge.
              _nativeDrag?.update(
                DragUpdateDetails(
                  delta: Offset.zero,
                  globalPosition: Offset.zero,
                ),
              );
            },
          );
  }

  Drag? track(Drag? drag) {
    _nativeDrag = drag;
    return drag == null ? null : _VisibleAreaDrag(drag, _stopDrag);
  }

  void _stopDrag() {
    _nativeDrag = null;
    _stopScrolling();
  }

  void _stopScrolling() {
    final wasScrolling = _autoScroller?.scrolling ?? false;
    _autoScroller?.stopAutoScroll();
    final position = _scrollable?.position;
    if (wasScrolling &&
        _scrollable?.mounted == true &&
        position != null &&
        position.isScrollingNotifier.value &&
        position.userScrollDirection == ScrollDirection.idle) {
      position.jumpTo(position.pixels);
    }
  }

  void dispose() {
    // The descendant Scrollable can already be disposed during parent teardown.
    // Its activity is gone; stop our loop without jumping its old position.
    _nativeDrag = null;
    if (_scrollable?.mounted == true) {
      _stopScrolling();
    } else {
      _autoScroller?.stopAutoScroll();
    }
    _scrollable = null;
    _autoScroller = null;
  }

  Rect? get _viewport {
    final box = _scrollable?.context.findRenderObject();
    return box is RenderBox && box.attached
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  @override
  bool isWithinBoundary(Rect draggedObject) {
    final visible = visibleViewport();
    return visible == null ||
        visible.contains(draggedObject.topLeft) &&
            visible.contains(draggedObject.bottomRight);
  }

  @override
  Rect nearestPositionWithinBoundary(Rect draggedObject) {
    final viewport = _viewport;
    final requested = visibleViewport();
    if (viewport == null || requested == null || requested.isEmpty) {
      return draggedObject;
    }
    final visible = viewport.intersect(requested);
    if (visible.isEmpty) return draggedObject;

    if (_nativeDrag != null) {
      final topOverflow = visible.top + AppDimens.gapXl - draggedObject.top;
      final bottomOverflow =
          draggedObject.bottom - visible.bottom + AppDimens.gapXl;
      final useTop =
          topOverflow > 0 &&
          (bottomOverflow <= 0 || draggedObject.center.dy < visible.center.dy);
      final overflow = (useTop ? topOverflow : bottomOverflow).clamp(0.0, 20.0);
      if (overflow > 0) {
        // A small virtual target makes the framework's edge scroller use the
        // visible edges without changing the proxy's finger tracking.
        _autoScroller?.startAutoScrollIfNecessary(
          Rect.fromLTWH(
            viewport.center.dx,
            useTop ? viewport.top - overflow : viewport.bottom + overflow - 1,
            1,
            1,
          ),
        );
      } else {
        _stopScrolling();
      }
    }

    // An unusually tall row can use the physical viewport as its boundary.
    // Avoid the framework's "rect larger than boundary" exception at large text.
    final bounds = draggedObject.height <= visible.height ? visible : viewport;
    return Rect.fromLTWH(
      draggedObject.left.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - draggedObject.width),
      ),
      draggedObject.top.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - draggedObject.height),
      ),
      draggedObject.width,
      draggedObject.height,
    );
  }
}

class VisibleAreaDragStartListener extends ReorderableDragStartListener {
  final VisibleAreaDragController controller;

  const VisibleAreaDragStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled,
    required this.controller,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      _VisibleAreaDragRecognizer(controller);
}

class _VisibleAreaDragRecognizer extends ImmediateMultiDragGestureRecognizer {
  final VisibleAreaDragController controller;

  _VisibleAreaDragRecognizer(this.controller);

  @override
  set onStart(GestureMultiDragStartCallback? callback) {
    super.onStart = callback == null
        ? null
        : (position) => controller.track(callback(position));
  }
}

class _VisibleAreaDrag extends Drag {
  final Drag delegate;
  final VoidCallback onStop;

  _VisibleAreaDrag(this.delegate, this.onStop);

  @override
  void update(DragUpdateDetails details) => delegate.update(details);

  @override
  void end(DragEndDetails details) {
    onStop();
    delegate.end(details);
  }

  @override
  void cancel() {
    onStop();
    delegate.cancel();
  }
}
