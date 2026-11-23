import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

bool isMapLayerVisible(BuildContext context, GlobalKey layerKey) {
  final box = layerKey.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) {
    return false;
  }
  var rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  final view = View.of(context);
  final ratio = view.devicePixelRatio;
  rect = rect.intersect(
    Rect.fromLTRB(
      0,
      view.padding.top / ratio,
      view.physicalSize.width / ratio,
      (view.physicalSize.height - view.viewInsets.bottom) / ratio,
    ),
  );
  RenderObject? ancestor = box.parent;
  while (ancestor != null && !rect.isEmpty) {
    if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
      final viewport = ancestor as RenderBox;
      rect = rect.intersect(
        MatrixUtils.transformRect(
          viewport.getTransformTo(null),
          Offset.zero & viewport.size,
        ),
      );
    }
    ancestor = ancestor.parent;
  }
  return !rect.isEmpty;
}
