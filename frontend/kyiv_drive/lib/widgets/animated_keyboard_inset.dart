import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedKeyboardInset extends StatelessWidget {
  final LayoutWidgetBuilder builder;
  final Duration duration;
  final Curve curve;

  /// Bottom space already excluded from the available layout height.
  final double? reservedBottomInset;

  const AnimatedKeyboardInset({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
    this.reservedBottomInset,
  }) : assert(reservedBottomInset == null || reservedBottomInset >= 0);

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final persistentBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomInset = reservedBottomInset ?? persistentBottomInset;
    final animatedInset = math.max(0.0, keyboardInset - bottomInset);

    return AnimatedPadding(
      duration: duration,
      curve: curve,
      padding: EdgeInsets.only(bottom: animatedInset),
      child: LayoutBuilder(builder: builder),
    );
  }
}
