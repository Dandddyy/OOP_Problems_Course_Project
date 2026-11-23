import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

/// Reveals content from the top with the same size/fade motion as car actions.
class AnimatedReveal extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedReveal({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    final content = visible
        ? KeyedSubtree(key: const ValueKey(true), child: child)
        : const SizedBox.shrink(key: ValueKey(false));
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: MediaQuery.disableAnimationsOf(context)
            ? content
            : AnimatedSwitcher(
                duration: AppDurations.fast,
                switchInCurve: const Cubic(0.65, 0, 0.35, 1),
                switchOutCurve: const Cubic(0.65, 0, 0.35, 1),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: AlignmentDirectional.topStart,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) => ClipRect(
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: AlignmentDirectional.topStart,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                ),
                child: content,
              ),
      ),
    );
  }
}
