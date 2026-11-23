import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

/// Changes field text color without delaying the actual input lock.
class AnimatedFieldTextColor extends StatelessWidget {
  final Color color;
  final Widget Function(Color color) builder;

  const AnimatedFieldTextColor({
    super.key,
    required this.color,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    duration: AppDurations.fieldState,
    curve: Curves.linear,
    tween: ColorTween(begin: color, end: color),
    builder: (context, animatedColor, _) => builder(animatedColor ?? color),
  );
}
