import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

/// Cross-fades the content of a bounded screen area.
class AppContentSwitcher extends StatelessWidget {
  final Widget child;
  final Duration Function(Key? from, Key? to)? durationForTransition;

  const AppContentSwitcher({
    super.key,
    required this.child,
    this.durationForTransition,
  });

  @override
  Widget build(BuildContext context) {
    final duration = durationForTransition;
    if (duration != null) {
      return _TimedContentSwitcher(
        durationForTransition: duration,
        child: child,
      );
    }
    return AnimatedSwitcher(
      duration: AppDurations.screenCrossFade,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final outgoing in previous) _layer(outgoing, outgoing: true),
          if (current != null) _layer(current, outgoing: false),
        ],
      ),
      child: child,
    );
  }

  static Widget _layer(Widget child, {required bool outgoing}) => IgnorePointer(
    key: child.key,
    ignoring: outgoing,
    child: ExcludeFocus(
      excluding: outgoing,
      child: ExcludeSemantics(excluding: outgoing, child: child),
    ),
  );
}

class _TimedContentSwitcher extends StatefulWidget {
  final Duration Function(Key? from, Key? to) durationForTransition;
  final Widget child;

  const _TimedContentSwitcher({
    required this.durationForTransition,
    required this.child,
  });

  @override
  State<_TimedContentSwitcher> createState() => _TimedContentSwitcherState();
}

class _TimedContentSwitcherState extends State<_TimedContentSwitcher>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, value: 1)
    ..addStatusListener((status) {
      if (status.isCompleted) setState(_outgoing.clear);
    });
  late _ContentEntry _current = _ContentEntry(widget.child, 1);
  final _outgoing = <_ContentEntry>[];

  @override
  void didUpdateWidget(_TimedContentSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.child;
    if (Widget.canUpdate(_current.child, next)) {
      _current.child = next;
      return;
    }

    // Both sides of a transition use the same clock. If a new state arrives
    // during a fade, continue from the opacities already on screen.
    final from = _current.child.key;
    final progress = _fade.value;
    for (final entry in _outgoing) {
      entry.startOpacity *= 1 - progress;
    }
    _current.startOpacity += (1 - _current.startOpacity) * progress;
    if (_current.startOpacity > 0) _outgoing.add(_current);

    final returning = _outgoing.indexWhere(
      (entry) => Widget.canUpdate(entry.child, next),
    );
    _current = returning < 0
        ? _ContentEntry(next, 0)
        : (_outgoing.removeAt(returning)..child = next);
    _outgoing.removeWhere((entry) => entry.startOpacity == 0);

    _fade.duration = widget.durationForTransition(from, next.key);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Widget _buildLayer(_ContentEntry entry, {required bool outgoing}) =>
      AppContentSwitcher._layer(
        FadeTransition(
          key: ObjectKey(entry),
          opacity: _fade.drive(
            Tween<double>(begin: entry.startOpacity, end: outgoing ? 0 : 1),
          ),
          child: entry.child,
        ),
        outgoing: outgoing,
      );

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final entry in _outgoing) _buildLayer(entry, outgoing: true),
      _buildLayer(_current, outgoing: false),
    ],
  );
}

class _ContentEntry {
  Widget child;
  double startOpacity;

  _ContentEntry(this.child, this.startOpacity);
}
