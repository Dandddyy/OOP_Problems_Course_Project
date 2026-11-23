import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

class AnimatedFieldIcon extends StatelessWidget {
  final Color color;
  final Widget Function(Color color) builder;

  const AnimatedFieldIcon({
    super.key,
    required this.color,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      duration: AppDurations.fieldState,
      curve: Curves.linear,
      tween: ColorTween(begin: color, end: color),
      builder: (context, animatedColor, _) {
        return builder(animatedColor ?? color);
      },
    );
  }
}
