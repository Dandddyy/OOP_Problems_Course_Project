import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/app_ui_tokens.dart';

/// Keeps lift feedback on the card itself, inside the row's transparent margins.
class WaypointDragFeedback extends StatefulWidget {
  final Animation<double> animation;
  final VoidCallback onRemoved;
  final Widget child;

  const WaypointDragFeedback({
    super.key,
    required this.animation,
    required this.onRemoved,
    required this.child,
  });

  @override
  State<WaypointDragFeedback> createState() => _WaypointDragFeedbackState();
}

class _WaypointDragFeedbackState extends State<WaypointDragFeedback> {
  @override
  void dispose() {
    widget.onRemoved();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    child: widget.child,
    builder: (context, child) => WaypointDragAppearance(
      progress: MediaQuery.disableAnimationsOf(context)
          ? (widget.animation.status == AnimationStatus.reverse ? 0 : 1)
          : Curves.easeInOut.transform(widget.animation.value),
      child: child!,
    ),
  );
}

class WaypointDragAppearance extends InheritedWidget {
  final double progress;

  const WaypointDragAppearance({
    super.key,
    required this.progress,
    required super.child,
  });

  static double progressOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WaypointDragAppearance>()
          ?.progress ??
      0;

  @override
  bool updateShouldNotify(WaypointDragAppearance oldWidget) =>
      progress != oldWidget.progress;
}

/// Register only attached render boxes: lazy rows can be inactive for a frame
/// while their GlobalKeys still have a context.
class WaypointDragEntry extends SingleChildRenderObjectWidget {
  final String id;
  final Map<String, RenderBox> entries;

  const WaypointDragEntry({
    super.key,
    required this.id,
    required this.entries,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _WaypointDragEntryBox(id, entries);
}

class _WaypointDragEntryBox extends RenderProxyBox {
  final String id;
  final Map<String, RenderBox> entries;

  _WaypointDragEntryBox(this.id, this.entries);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    entries[id] = this;
  }

  @override
  void detach() {
    if (identical(entries[id], this)) entries.remove(id);
    super.detach();
  }
}

/// Follows the native insertion gaps, including offscreen rows in a long list.
class WaypointDragGapPainter extends CustomPainter {
  final GlobalKey viewportKey;
  final GlobalKey listKey;
  final Map<String, RenderBox> entries;
  final String draggedId;
  final Rect? Function() visibleViewport;

  WaypointDragGapPainter({
    required this.viewportKey,
    required this.listKey,
    required this.entries,
    required this.draggedId,
    required this.visibleViewport,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = viewportKey.currentContext?.findRenderObject();
    final sliver = listKey.currentContext?.findRenderObject();
    final dragged = entries[draggedId];
    final visible = visibleViewport();
    if (viewport is! RenderBox ||
        sliver is! RenderSliver ||
        sliver.geometry == null ||
        visible == null ||
        visible.isEmpty ||
        dragged == null ||
        !dragged.attached) {
      return;
    }
    // The row can return to the list a frame before the proxy is disposed.
    for (
      RenderObject? parent = dragged.parent;
      parent != null;
      parent = parent.parent
    ) {
      if (identical(parent, sliver)) return;
    }
    final origin =
        MatrixUtils.transformPoint(
          sliver.getTransformTo(viewport),
          Offset.zero,
        ).dy -
        sliver.constraints.scrollOffset;
    final end = origin + sliver.geometry!.scrollExtent;
    final rows = <Rect>[];
    for (final entry in entries.entries) {
      if (entry.key == draggedId) continue;
      final row = entry.value;
      if (!row.attached || !row.hasSize) continue;
      final top = viewport.globalToLocal(row.localToGlobal(Offset.zero)).dy;
      rows.add(Rect.fromLTWH(0, top, size.width, row.size.height));
    }
    rows.sort((a, b) => a.top.compareTo(b.top));
    canvas.save();
    canvas.clipRect(
      Rect.fromPoints(
        viewport.globalToLocal(visible.topLeft),
        viewport.globalToLocal(visible.bottomRight),
      ),
    );
    var bottom = origin;
    for (final row in rows) {
      _paintGap(canvas, size.width, bottom, row.top);
      bottom = math.max(bottom, row.bottom);
    }
    _paintGap(canvas, size.width, bottom, end);
    canvas.restore();
  }

  void _paintGap(Canvas canvas, double width, double top, double bottom) {
    final rect = Rect.fromLTRB(
      AppDimens.pagePadding,
      top + AppDimens.gapSm,
      width - AppDimens.pagePadding,
      bottom - AppDimens.gapSm,
    );
    if (rect.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.medium)),
      Paint()..color = AppColors.surfaceDisabled,
    );
  }

  @override
  bool shouldRepaint(WaypointDragGapPainter oldDelegate) =>
      draggedId != oldDelegate.draggedId ||
      entries != oldDelegate.entries ||
      viewportKey != oldDelegate.viewportKey ||
      listKey != oldDelegate.listKey;
}
