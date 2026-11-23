import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

/// Matches the disabled color-selector treatment without blocking its scrollable.
class AnimatedControlLock extends StatelessWidget {
  static const disabledOpacity = 0.45;
  static const duration = AppDurations.fieldState;

  final bool isEnabled;
  final Widget child;

  const AnimatedControlLock({
    super.key,
    required this.isEnabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: isEnabled,
    child: IgnorePointer(
      ignoring: !isEnabled,
      child: AnimatedOpacity(
        opacity: isEnabled ? 1 : disabledOpacity,
        duration: duration,
        curve: Curves.easeOut,
        child: child,
      ),
    ),
  );
}
