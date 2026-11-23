import 'package:flutter/material.dart';

class AnimatedTouchItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color normalColor;
  final Color pressedColor;
  final double pressedScale;
  final double pressedOpacity;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;

  /// Keeps feedback local when this control is nested in another touch item.
  final bool isolatePressFeedback;

  const AnimatedTouchItem({
    super.key,
    required this.child,
    required this.onTap,
    required this.normalColor,
    required this.pressedColor,
    this.pressedScale = 0.97,
    this.pressedOpacity = 1.0,
    this.borderRadius = BorderRadius.zero,
    this.boxShadow,
    this.isolatePressFeedback = false,
  });

  @override
  State<AnimatedTouchItem> createState() => _AnimatedTouchItemState();
}

class _AnimatedTouchItemState extends State<AnimatedTouchItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final Set<int> _suppressedPointers = {};
  final Map<int, List<_AnimatedTouchItemState>> _isolatedAncestors = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeOut,
          ),
        );

    _opacityAnimation = Tween<double>(begin: 1.0, end: widget.pressedOpacity)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeOut,
          ),
        );
  }

  @override
  void dispose() {
    for (final pointer in _isolatedAncestors.keys.toList()) {
      _releaseAncestors(pointer);
    }
    _controller.dispose();
    super.dispose();
  }

  void _visualDown() {
    if (widget.onTap != null) _controller.forward();
  }

  void _visualUp() {
    if (widget.onTap != null) _controller.reverse();
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.isolatePressFeedback) {
      final ancestors = <_AnimatedTouchItemState>[];
      var ancestor = context.findAncestorStateOfType<_AnimatedTouchItemState>();
      while (ancestor != null) {
        ancestor._suppressedPointers.add(event.pointer);
        ancestors.add(ancestor);
        ancestor = ancestor.context
            .findAncestorStateOfType<_AnimatedTouchItemState>();
      }
      _isolatedAncestors[event.pointer] = ancestors;
    }
    // Pointer listeners run from the hit child towards its ancestors, so an
    // isolated child suppresses this feedback before it can start.
    if (!_suppressedPointers.contains(event.pointer)) _visualDown();
  }

  void _pointerEnd(PointerEvent event) {
    _visualUp();
    _releaseAncestors(event.pointer);
  }

  void _releaseAncestors(int pointer) {
    final ancestors = _isolatedAncestors.remove(pointer);
    if (ancestors == null) return;
    for (final ancestor in ancestors) {
      ancestor._suppressedPointers.remove(pointer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _pointerDown,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      behavior: HitTestBehavior.opaque,

      child: GestureDetector(
        onTap: () {
          widget.onTap?.call();
          _visualUp();
        },
        onTapCancel: () {
          _visualUp();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final currentColor = Color.lerp(
              widget.normalColor,
              widget.pressedColor,
              _controller.value,
            );
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: widget.borderRadius,
                  boxShadow: widget.boxShadow,
                ),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AnimatedListHighlight extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onPressedChanged;
  final Color? pressedBackgroundColor;

  const AnimatedListHighlight({
    super.key,
    required this.child,
    required this.onTap,
    this.onPressedChanged,
    this.pressedBackgroundColor,
  });

  @override
  State<AnimatedListHighlight> createState() => _AnimatedListHighlightState();
}

class _AnimatedListHighlightState extends State<AnimatedListHighlight> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (!mounted || _isPressed == pressed) return;
    setState(() => _isPressed = pressed);
    widget.onPressedChanged?.call(pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) {
        _setPressed(false);
      },
      onPointerCancel: (_) => _setPressed(false),

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _isPressed ? 150 : 300),
          curve: Curves.easeOutCubic,
          color: _isPressed
              ? widget.pressedBackgroundColor ??
                    Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: _isPressed ? 150 : 300),
            opacity: _isPressed ? 0.5 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
