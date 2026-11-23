import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppScrollbar extends StatelessWidget {
  static const double minimumScreenEdgeInset = 16;

  final ScrollController controller;
  final Widget child;
  final double mainAxisMargin;
  final double crossAxisMargin;
  final EdgeInsetsGeometry padding;
  final double topFadeExtent;

  const AppScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.mainAxisMargin = 16,
    this.crossAxisMargin = 2,
    this.padding = EdgeInsets.zero,
    this.topFadeExtent = 0,
  }) : assert(topFadeExtent >= 0);

  static double screenBottomInsetOf(
    BuildContext context, {
    double clearance = 0,
  }) {
    final media = MediaQuery.of(context);
    final systemInset = math.max(
      media.viewPadding.bottom,
      media.systemGestureInsets.bottom,
    );

    return math.max(systemInset, minimumScreenEdgeInset) + clearance;
  }

  static double screenRightInsetOf(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).right;
  }

  @visibleForTesting
  static LinearGradient topFadeGradientFor({
    required double viewportExtent,
    required double fadeExtent,
  }) {
    final fadeStop = viewportExtent <= 0
        ? 1.0
        : math.min(1.0, fadeExtent / viewportExtent);

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Colors.transparent, Colors.white, Colors.white],
      stops: [0, fadeStop, 1],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = topFadeExtent == 0
        ? child
        : ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return topFadeGradientFor(
                viewportExtent: bounds.height,
                fadeExtent: topFadeExtent,
              ).createShader(bounds);
            },
            child: child,
          );

    return RawScrollbar(
      controller: controller,
      thumbColor: Colors.white.withValues(alpha: 0.2),
      thickness: 4,
      radius: const Radius.circular(8),
      interactive: false,
      timeToFade: const Duration(milliseconds: 200),
      fadeDuration: const Duration(milliseconds: 150),
      mainAxisMargin: mainAxisMargin,
      crossAxisMargin: crossAxisMargin,
      padding: padding,
      child: scrollable,
    );
  }
}
