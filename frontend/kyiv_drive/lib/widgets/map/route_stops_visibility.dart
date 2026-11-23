import 'package:flutter/material.dart';

/// A single fade for the stop layer, independent of the route drawing timeline.
class RouteStopsVisibility extends StatelessWidget {
  static const duration = Duration(milliseconds: 300);

  final bool visible;
  final Widget child;

  const RouteStopsVisibility({
    super.key,
    required this.visible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : duration,
        curve: Curves.easeInOut,
        child: child,
      ),
    ),
  );
}
