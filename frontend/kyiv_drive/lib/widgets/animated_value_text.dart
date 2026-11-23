import 'package:flutter/material.dart';

import 'animated_value_switcher.dart';

/// Animates changes to a displayed value.
class AnimatedValueText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final AlignmentGeometry alignment;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AnimatedValueText(
    this.text, {
    super.key,
    required this.style,
    this.alignment = AlignmentDirectional.centerStart,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) => AnimatedValueSwitcher(
    alignment: alignment,
    child: Text(
      text,
      key: ValueKey(text),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    ),
  );
}
