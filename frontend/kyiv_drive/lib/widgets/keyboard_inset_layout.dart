import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps its child inside the unobscured viewport by following the keyboard's
/// system-provided inset without adding another animation on top of it.
class KeyboardInsetLayout extends StatelessWidget {
  final LayoutWidgetBuilder builder;

  /// Bottom space already excluded from the available layout height.
  final double? reservedBottomInset;

  const KeyboardInsetLayout({
    super.key,
    required this.builder,
    this.reservedBottomInset,
  }) : assert(reservedBottomInset == null || reservedBottomInset >= 0);

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final persistentBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomInset = reservedBottomInset ?? persistentBottomInset;
    final effectiveKeyboardInset = math.max(0.0, keyboardInset - bottomInset);

    return Padding(
      padding: EdgeInsets.only(bottom: effectiveKeyboardInset),
      child: LayoutBuilder(builder: builder),
    );
  }
}
