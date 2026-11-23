import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'app_scrollbar.dart';

class KeyboardAwareScrollView extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final double visibilityPadding;
  final Duration scrollDuration;
  final Curve scrollCurve;
  final Duration keyboardTransitionDuration;
  final Duration focusTransitionDelay;

  /// Pins the focused field to a viewport whose height is animated by an
  /// ancestor such as AnimatedKeyboardInset.
  final bool synchronizeFocusedFieldWithViewport;
  final EdgeInsetsGeometry? scrollbarPadding;
  final double scrollbarMainAxisMargin;

  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.controller,
    this.physics,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.visibilityPadding = AppDimens.gapLg,
    this.scrollDuration = const Duration(milliseconds: 220),
    this.scrollCurve = Curves.easeOutCubic,
    this.keyboardTransitionDuration = const Duration(milliseconds: 280),
    this.focusTransitionDelay = const Duration(milliseconds: 120),
    this.synchronizeFocusedFieldWithViewport = false,
    this.scrollbarPadding,
    this.scrollbarMainAxisMargin = 0,
  });

  static void handleFocusChange(BuildContext context, bool hasFocus) {
    final scope = context
        .getInheritedWidgetOfExactType<_KeyboardAwareScrollScope>();
    scope?.onFocusChanged(context, hasFocus);
  }

  @override
  State<KeyboardAwareScrollView> createState() =>
      _KeyboardAwareScrollViewState();
}

class _KeyboardAwareScrollViewState extends State<KeyboardAwareScrollView> {
  final GlobalKey _viewportKey = GlobalKey();

  late ScrollController _scrollController;
  BuildContext? _focusedContext;
  Timer? _keyboardTransitionTimer;
  double _keyboardInset = 0;
  bool _ensureVisibleScheduled = false;
  bool _scheduledEnsureShouldAnimate = true;
  bool _focusedFieldPinnedToBottom = false;
  bool _suppressImplicitScrolling = false;

  // Prevent viewport synchronization from replacing a focus animation with a
  // jump while the target field is being revealed.
  bool _focusRevealActive = false;
  int _focusRevealGeneration = 0;
  int _focusRevealRevision = 0;
  bool _focusRevealAnimating = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
  }

  @override
  void didUpdateWidget(covariant KeyboardAwareScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);

    _suppressImplicitScrolling =
        widget.synchronizeFocusedFieldWithViewport && _focusedContext != null;

    if (oldWidget.controller == widget.controller) return;

    _cancelFocusReveal();
    if (oldWidget.controller == null) {
      _scrollController.dispose();
    }
    _scrollController = widget.controller ?? ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _updateKeyboardInset(MediaQuery.viewInsetsOf(context).bottom);
  }

  void _updateKeyboardInset(double keyboardInset) {
    final previousKeyboardInset = _keyboardInset;
    if (previousKeyboardInset == keyboardInset) return;

    _keyboardInset = keyboardInset;
    if (keyboardInset <= 0) {
      _keyboardTransitionTimer?.cancel();
      _cancelFocusReveal();
      _focusedFieldPinnedToBottom = false;
      return;
    }

    if (_focusedContext == null) return;

    if (widget.synchronizeFocusedFieldWithViewport) {
      if (_focusRevealActive) {
        _retargetFocusReveal();
        return;
      }

      _keyboardTransitionTimer?.cancel();
      _scheduleEnsureVisible(animate: false);
      return;
    }

    if (previousKeyboardInset <= 0) {
      _scheduleEnsureVisibleAfter(widget.keyboardTransitionDuration);
    } else if (!(_keyboardTransitionTimer?.isActive ?? false)) {
      _scheduleEnsureVisibleAfter(widget.focusTransitionDelay);
    }
  }

  void _handleFocusChange(BuildContext targetContext, bool hasFocus) {
    if (!hasFocus) {
      if (identical(_focusedContext, targetContext)) {
        _focusedContext = null;
        _focusedFieldPinnedToBottom = false;
        _setImplicitScrollingSuppressed(false);
        _keyboardTransitionTimer?.cancel();
        _cancelFocusReveal();
      }
      return;
    }

    final focusedTargetChanged = !identical(_focusedContext, targetContext);
    if (focusedTargetChanged) {
      _focusedFieldPinnedToBottom = false;
    }
    _focusedContext = targetContext;
    _setImplicitScrollingSuppressed(widget.synchronizeFocusedFieldWithViewport);
    if (widget.synchronizeFocusedFieldWithViewport && _keyboardInset > 0) {
      if (focusedTargetChanged) {
        _scheduleAnimatedFocusReveal(targetContext);
      } else if (_focusRevealActive) {
        _retargetFocusReveal();
      } else {
        _scheduleEnsureVisible(animate: false);
      }
      return;
    }

    final delay = _keyboardInset > 0
        ? widget.focusTransitionDelay
        : widget.keyboardTransitionDuration;
    _scheduleEnsureVisibleAfter(delay);
  }

  void _scheduleAnimatedFocusReveal(BuildContext targetContext) {
    _keyboardTransitionTimer?.cancel();
    _cancelFocusReveal();

    final generation = _focusRevealGeneration;
    _focusRevealActive = true;

    // EditableText schedules its implicit caret reveal in this frame as well.
    // Start the complete-field reveal after all post-frame callbacks so it
    // replaces that scroll activity before another frame can paint it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(
        () => _runAnimatedFocusReveal(generation, targetContext),
      );
    });
  }

  Future<void> _runAnimatedFocusReveal(
    int generation,
    BuildContext targetContext,
  ) async {
    if (!_isCurrentFocusReveal(generation, targetContext)) {
      if (generation == _focusRevealGeneration) {
        _focusRevealActive = false;
      }
      return;
    }

    try {
      _focusRevealAnimating = true;
      final startedAt = WidgetsBinding.instance.currentSystemFrameTimeStamp;

      while (mounted) {
        if (!targetContext.mounted ||
            !_isCurrentFocusReveal(generation, targetContext)) {
          break;
        }

        final revision = _focusRevealRevision;
        final elapsed =
            WidgetsBinding.instance.currentSystemFrameTimeStamp - startedAt;
        final remainingDuration = widget.scrollDuration - elapsed;

        if (remainingDuration <= Duration.zero) {
          await _ensureFocusedFieldVisible(
            animate: false,
            useKeyboardInsetBoundary: true,
          );
          break;
        }

        await _ensureFocusedFieldVisible(
          animate: true,
          duration: remainingDuration,
          useKeyboardInsetBoundary: true,
        );
        if (revision == _focusRevealRevision) break;
      }
    } finally {
      if (mounted && generation == _focusRevealGeneration) {
        _focusRevealAnimating = false;
        _focusRevealActive = false;
      }
    }
  }

  bool _isCurrentFocusReveal(int generation, BuildContext targetContext) {
    return mounted &&
        targetContext.mounted &&
        generation == _focusRevealGeneration &&
        _focusRevealActive &&
        identical(_focusedContext, targetContext);
  }

  void _cancelFocusReveal() {
    if (_focusRevealAnimating && _scrollController.hasClients) {
      final position = _scrollController.position;
      position.jumpTo(position.pixels);
    }

    _focusRevealGeneration++;
    _focusRevealRevision++;
    _focusRevealAnimating = false;
    _focusRevealActive = false;
  }

  void _retargetFocusReveal() {
    _focusRevealRevision++;
    if (_focusRevealAnimating && _scrollController.hasClients) {
      final position = _scrollController.position;
      position.jumpTo(position.pixels);
    }
  }

  void _setImplicitScrollingSuppressed(bool value) {
    if (_suppressImplicitScrolling == value) return;

    setState(() {
      _suppressImplicitScrolling = value;
    });
  }

  void _scheduleEnsureVisibleAfter(Duration delay) {
    _keyboardTransitionTimer?.cancel();
    _keyboardTransitionTimer = Timer(delay, () => _scheduleEnsureVisible());
  }

  void _scheduleEnsureVisible({bool animate = true}) {
    if (_focusRevealActive) return;

    if (_ensureVisibleScheduled) {
      if (!animate) {
        _scheduledEnsureShouldAnimate = false;
      }
      return;
    }

    _ensureVisibleScheduled = true;
    _scheduledEnsureShouldAnimate = animate;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shouldAnimate = _scheduledEnsureShouldAnimate;
      _ensureVisibleScheduled = false;
      _scheduledEnsureShouldAnimate = true;
      if (mounted && !_focusRevealActive) {
        await _ensureFocusedFieldVisible(animate: shouldAnimate);
      }
    });
  }

  Future<void> _ensureFocusedFieldVisible({
    required bool animate,
    Duration? duration,
    bool useKeyboardInsetBoundary = false,
  }) async {
    final targetContext = _focusedContext;
    if (_keyboardInset <= 0 ||
        targetContext == null ||
        !targetContext.mounted ||
        !_scrollController.hasClients) {
      return;
    }

    final targetRenderObject = targetContext.findRenderObject();
    final viewportRenderObject = _viewportKey.currentContext
        ?.findRenderObject();
    if (targetRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox ||
        !targetRenderObject.attached ||
        !viewportRenderObject.attached) {
      return;
    }

    final targetTopLeft = targetRenderObject.localToGlobal(Offset.zero);
    final targetRect = targetTopLeft & targetRenderObject.size;

    final viewportTopLeft = viewportRenderObject.localToGlobal(Offset.zero);
    final viewportRect = viewportTopLeft & viewportRenderObject.size;
    final keyboardTop = MediaQuery.sizeOf(context).height - _keyboardInset;
    final unobscuredViewportBottom = widget.synchronizeFocusedFieldWithViewport
        ? useKeyboardInsetBoundary
              ? math.min(viewportRect.bottom, keyboardTop)
              : viewportRect.bottom
        : math.min(viewportRect.bottom, keyboardTop);

    final visibleTop = viewportRect.top + widget.visibilityPadding;
    final visibleBottom = unobscuredViewportBottom - widget.visibilityPadding;
    if (visibleBottom <= visibleTop) return;

    double scrollDelta = 0;
    if (targetRect.bottom > visibleBottom) {
      scrollDelta = targetRect.bottom - visibleBottom;
      if (widget.synchronizeFocusedFieldWithViewport) {
        _focusedFieldPinnedToBottom = true;
      }
    } else if (widget.synchronizeFocusedFieldWithViewport &&
        _focusedFieldPinnedToBottom &&
        targetRect.bottom < visibleBottom) {
      scrollDelta = targetRect.bottom - visibleBottom;
    } else if (targetRect.top < visibleTop) {
      scrollDelta = targetRect.top - visibleTop;
    }

    if (scrollDelta.abs() < 0.5) return;

    final position = _scrollController.position;
    final targetOffset = (position.pixels + scrollDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 0.5) return;

    if (animate) {
      await _scrollController.animateTo(
        targetOffset,
        duration: duration ?? widget.scrollDuration,
        curve: widget.scrollCurve,
      );
    } else {
      position.jumpTo(targetOffset);
    }
  }

  @override
  void dispose() {
    _keyboardTransitionTimer?.cancel();
    _cancelFocusReveal();
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.synchronizeFocusedFieldWithViewport &&
        _keyboardInset > 0 &&
        _focusedContext != null &&
        !_focusRevealActive) {
      _scheduleEnsureVisible(animate: false);
    }

    final media = MediaQuery.of(context);
    final scrollPhysics = _suppressImplicitScrolling
        ? _NoImplicitScrollingPhysics(parent: widget.physics)
        : widget.physics;
    final scrollbarPadding =
        widget.scrollbarPadding ??
        EdgeInsets.fromLTRB(
          media.padding.left,
          media.padding.top + AppDimens.gapSm,
          media.padding.right,
          math.max(media.viewInsets.bottom, media.padding.bottom) +
              AppDimens.gapLg,
        );

    return _KeyboardAwareScrollScope(
      onFocusChanged: _handleFocusChange,
      child: SizedBox(
        key: _viewportKey,
        child: AppScrollbar(
          controller: _scrollController,
          mainAxisMargin: widget.scrollbarMainAxisMargin,
          padding: scrollbarPadding,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: scrollPhysics,
            padding: widget.padding,
            clipBehavior: widget.clipBehavior,
            keyboardDismissBehavior: widget.keyboardDismissBehavior,
            child: Overlay.wrap(
              // Keep field menus in the scrolling paint subtree so fixed
              // headers and footers outside this viewport remain above them.
              clipBehavior: Clip.none,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoImplicitScrollingPhysics extends ScrollPhysics {
  const _NoImplicitScrollingPhysics({super.parent});

  @override
  bool get allowImplicitScrolling => false;

  @override
  _NoImplicitScrollingPhysics applyTo(ScrollPhysics? ancestor) {
    return _NoImplicitScrollingPhysics(parent: buildParent(ancestor));
  }
}

class _KeyboardAwareScrollScope extends InheritedWidget {
  final void Function(BuildContext context, bool hasFocus) onFocusChanged;

  const _KeyboardAwareScrollScope({
    required this.onFocusChanged,
    required super.child,
  });

  @override
  bool updateShouldNotify(_KeyboardAwareScrollScope oldWidget) => false;
}
