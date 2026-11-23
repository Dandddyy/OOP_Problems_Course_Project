import 'package:flutter/material.dart';

class KeyboardDismissOnBackgroundTap
    extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnBackgroundTap({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: child,
    );
  }
}