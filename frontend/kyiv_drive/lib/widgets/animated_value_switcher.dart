import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

/// Fades and slides between children with distinct keys or widget types.
class AnimatedValueSwitcher extends StatelessWidget {
  static final _slide = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  );

  final Widget child;
  final AlignmentGeometry alignment;
  final Widget? _skeleton;
  final bool _showSkeleton;

  const AnimatedValueSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  }) : _skeleton = null,
       _showSkeleton = false;

  /// Cross-fades the loading skeleton and the value in place.
  const AnimatedValueSwitcher.withSkeleton({
    super.key,
    required this.child,
    required Widget skeleton,
    required bool showSkeleton,
    this.alignment = Alignment.center,
  }) : _skeleton = skeleton,
       _showSkeleton = showSkeleton;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.buttonState;
    final value = _buildSwitcher(child, duration, _transition);
    final skeleton = _skeleton;
    if (skeleton == null) return value;

    return _buildSwitcher(
      KeyedSubtree(
        key: ValueKey(_showSkeleton),
        child: _showSkeleton ? skeleton : value,
      ),
      duration,
      _fade,
    );
  }

  Widget _buildSwitcher(
    Widget child,
    Duration duration,
    AnimatedSwitcherTransitionBuilder transitionBuilder,
  ) => AnimatedSwitcher(
    key: ValueKey(duration),
    duration: duration,
    reverseDuration: duration,
    switchInCurve: Curves.easeInOut,
    switchOutCurve: Curves.easeInOut,
    transitionBuilder: transitionBuilder,
    layoutBuilder: (current, previous) => Stack(
      alignment: alignment,
      children: [
        for (final outgoing in previous)
          ExcludeSemantics(key: outgoing.key, child: outgoing),
        if (current != null)
          ExcludeSemantics(key: current.key, excluding: false, child: current),
      ],
    ),
    child: child,
  );

  static Widget _transition(Widget child, Animation<double> animation) => _fade(
    SlideTransition(position: _slide.animate(animation), child: child),
    animation,
  );

  static Widget _fade(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        alwaysIncludeSemantics: true,
        child: child,
      );
}
