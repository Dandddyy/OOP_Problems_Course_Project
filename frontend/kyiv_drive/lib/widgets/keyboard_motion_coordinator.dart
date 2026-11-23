import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'keyboard_inset_layout.dart';

typedef KeyboardMotionLayoutBuilder =
    Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      ScrollPhysics scrollPhysics,
      double bottomScrollExtent,
    );

/// Coordinates a scrollable with the system keyboard without introducing a
/// second, time-based keyboard animation.
///
/// Opening and focus changes remain owned by Flutter's show-on-screen flow.
/// When the keyboard closes, this widget restores the scroll offset using the
/// system inset as progress. A temporary bottom extent keeps that offset legal
/// until the keyboard has fully disappeared, including the part of the system
/// animation that is already covered by a reserved bottom bar.
class KeyboardMotionCoordinator extends StatefulWidget {
  final ScrollController scrollController;
  final ScrollPhysics? scrollPhysics;
  final KeyboardMotionLayoutBuilder builder;

  /// Whether the coordinator should remove the keyboard inset from the
  /// constraints passed to [builder].
  ///
  /// Bottom sheets can opt out and apply the inset around only their scrolling
  /// viewport. That lets the sheet grow upward until its route constraint is
  /// reached, while the viewport still ends at the physical keyboard edge.
  final bool applyKeyboardInsetToLayout;

  /// Bottom space already excluded from the available layout height.
  final double? reservedBottomInset;

  const KeyboardMotionCoordinator({
    super.key,
    required this.scrollController,
    required this.builder,
    this.scrollPhysics,
    this.reservedBottomInset,
    this.applyKeyboardInsetToLayout = true,
  }) : assert(reservedBottomInset == null || reservedBottomInset >= 0);

  /// Returns the callback used by a descendant [KeyboardRevealTarget]-style
  /// render object after it starts an animated focus reveal.
  static ValueChanged<Duration>? focusRevealStartedCallbackOf(
    BuildContext context,
  ) {
    return context
        .getInheritedWidgetOfExactType<_KeyboardMotionScope>()
        ?.onFocusRevealStarted;
  }

  /// Returns the callback used by a descendant [KeyboardRevealTarget]-style
  /// render object to keep keyboard restoration inside its closed safe area.
  static ValueChanged<double>? restoreOffsetCorrectionCallbackOf(
    BuildContext context,
  ) {
    return context
        .getInheritedWidgetOfExactType<_KeyboardMotionScope>()
        ?.onRestoreOffsetCorrection;
  }

  @override
  State<KeyboardMotionCoordinator> createState() =>
      _KeyboardMotionCoordinatorState();

  /// An explicit form reveal replaces restoration of the previously focused field.
  static VoidCallback? explicitRevealStartedCallbackOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_KeyboardMotionScope>()
        ?.onExplicitRevealStarted;
  }
}

class _KeyboardMotionCoordinatorState extends State<KeyboardMotionCoordinator> {
  static const _insetTolerance = 0.01;
  static const _dimensionChangeSignalExtent = 1.0;

  var _metricsInitialized = false;
  var _keyboardSessionActive = false;
  var _userAdjustedScroll = false;
  var _userDragActive = false;
  var _closing = false;
  var _finishGeneration = 0;
  var _closingReleaseGeneration = 0;
  var _focusHandoffActive = false;
  Timer? _focusHandoffReleaseTimer;

  double _rawKeyboardInset = 0;
  double _effectiveKeyboardInset = 0;
  double? _sessionStartOffset;
  ValueNotifier<bool>? _focusHandoffScrollingNotifier;

  double _closingStartRawInset = 0;
  double _closingStartOffset = 0;
  double _closingTargetOffset = 0;
  double _closedMinScrollExtent = 0;
  double _closedMaxScrollExtent = 0;
  double _closedUnclampedMaxScrollExtent = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handlePrimaryFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final rawKeyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final reservedBottomInset =
        widget.reservedBottomInset ?? MediaQuery.viewPaddingOf(context).bottom;
    final effectiveKeyboardInset = math.max(
      0.0,
      rawKeyboardInset - reservedBottomInset,
    );

    _updateKeyboardMetrics(
      rawKeyboardInset: rawKeyboardInset,
      effectiveKeyboardInset: effectiveKeyboardInset,
    );
  }

  @override
  void didUpdateWidget(covariant KeyboardMotionCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      _resetSession();
      if (_rawKeyboardInset > _insetTolerance && _focusIsWithinCoordinator()) {
        _startKeyboardSession();
      }
    }

    if (oldWidget.reservedBottomInset != widget.reservedBottomInset) {
      final rawKeyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      final reservedBottomInset =
          widget.reservedBottomInset ??
          MediaQuery.viewPaddingOf(context).bottom;
      _updateKeyboardMetrics(
        rawKeyboardInset: rawKeyboardInset,
        effectiveKeyboardInset: math.max(
          0.0,
          rawKeyboardInset - reservedBottomInset,
        ),
      );
    }
  }

  void _updateKeyboardMetrics({
    required double rawKeyboardInset,
    required double effectiveKeyboardInset,
  }) {
    if (!_metricsInitialized) {
      _metricsInitialized = true;
      _rawKeyboardInset = rawKeyboardInset;
      _effectiveKeyboardInset = effectiveKeyboardInset;
      if (rawKeyboardInset > _insetTolerance && _focusIsWithinCoordinator()) {
        _startKeyboardSession();
      }
      return;
    }

    final previousRawKeyboardInset = _rawKeyboardInset;
    final previousEffectiveKeyboardInset = _effectiveKeyboardInset;
    final fullyClosedThisUpdate =
        previousRawKeyboardInset > _insetTolerance &&
        rawKeyboardInset <= _insetTolerance;

    if (previousRawKeyboardInset <= _insetTolerance &&
        rawKeyboardInset > _insetTolerance &&
        !_keyboardSessionActive &&
        _focusIsWithinCoordinator()) {
      _startKeyboardSession();
    }

    if (rawKeyboardInset > previousRawKeyboardInset + _insetTolerance) {
      if (_closing &&
          _canReleaseClosingAt(
            rawKeyboardInset: rawKeyboardInset,
            effectiveKeyboardInset: effectiveKeyboardInset,
          )) {
        _scheduleFinishClosingReversal();
      }
    } else if (rawKeyboardInset < previousRawKeyboardInset - _insetTolerance &&
        !_closing &&
        _keyboardSessionActive &&
        (!_focusHandoffActive || fullyClosedThisUpdate)) {
      if (fullyClosedThisUpdate && _focusHandoffActive) {
        _takeOverFocusHandoffForKeyboardClose();
      }
      _beginClosing(
        startRawInset: previousRawKeyboardInset,
        startEffectiveInset: previousEffectiveKeyboardInset,
      );
    }

    _rawKeyboardInset = rawKeyboardInset;
    _effectiveKeyboardInset = effectiveKeyboardInset;

    if (fullyClosedThisUpdate) {
      _scheduleFinishSession();
    }
  }

  void _handlePrimaryFocusChange() {
    if (!mounted) return;

    if (_focusIsWithinCoordinator()) {
      _startKeyboardSession();
      return;
    }

    _endFocusHandoff();
  }

  void _handleFocusRevealStarted(Duration duration) {
    _endFocusHandoff();

    if (duration <= Duration.zero) return;

    // Even when both fields are already visible, a keyboard-layout replacement
    // can briefly reduce viewInsets. Keep that change from being mistaken for
    // keyboard closing for the same interval as the focus reveal.
    _focusHandoffActive = true;
    _focusHandoffReleaseTimer = Timer(duration, () {
      if (mounted && _focusHandoffActive) _endFocusHandoff();
    });

    if (!widget.scrollController.hasClients) return;

    final scrollingNotifier =
        widget.scrollController.position.isScrollingNotifier;
    if (!scrollingNotifier.value) return;

    _focusHandoffScrollingNotifier = scrollingNotifier;
    scrollingNotifier.addListener(_handleFocusHandoffScrollActivity);
  }

  void _handleExplicitRevealStarted() {
    if (!_keyboardSessionActive && !_closing) return;
    setState(_resetSession);
  }

  void _handleRestoreOffsetCorrection(double scrollDelta) {
    if (scrollDelta.abs() <= _insetTolerance ||
        _rawKeyboardInset > _insetTolerance ||
        !widget.scrollController.hasClients) {
      return;
    }

    _startKeyboardSession();
    if (_userAdjustedScroll) return;

    final position = widget.scrollController.position;
    _sessionStartOffset = (position.pixels + scrollDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  void _handleFocusHandoffScrollActivity() {
    final scrollingNotifier = _focusHandoffScrollingNotifier;
    if (!_focusHandoffActive || scrollingNotifier == null) return;

    if (!scrollingNotifier.value) {
      _endFocusHandoff();
    }
  }

  void _endFocusHandoff() {
    _focusHandoffReleaseTimer?.cancel();
    _focusHandoffReleaseTimer = null;
    _focusHandoffScrollingNotifier?.removeListener(
      _handleFocusHandoffScrollActivity,
    );
    _focusHandoffScrollingNotifier = null;
    _focusHandoffActive = false;
  }

  void _takeOverFocusHandoffForKeyboardClose() {
    final position = widget.scrollController.hasClients
        ? widget.scrollController.position
        : null;

    _endFocusHandoff();

    // A focus reveal owns a DrivenScrollActivity. When the system keyboard is
    // already fully closed, let the closing trajectory take ownership before
    // that activity can restore its stale keyboard-open target.
    if (!_userDragActive && position?.isScrollingNotifier.value == true) {
      position!.jumpTo(position.pixels);
    }
  }

  bool _focusIsWithinCoordinator() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final scope = focusContext
        ?.getInheritedWidgetOfExactType<_KeyboardMotionScope>();
    return identical(scope?.owner, this);
  }

  void _startKeyboardSession() {
    if (_keyboardSessionActive) return;

    final generation = ++_finishGeneration;
    _keyboardSessionActive = true;
    _userAdjustedScroll = false;
    _userDragActive = false;
    _closing = false;
    _sessionStartOffset = widget.scrollController.hasClients
        ? widget.scrollController.position.pixels
        : null;

    if (_sessionStartOffset == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _finishGeneration ||
            !_keyboardSessionActive ||
            _sessionStartOffset != null ||
            !widget.scrollController.hasClients) {
          return;
        }

        _sessionStartOffset = widget.scrollController.position.pixels;
      });
    }
  }

  void _beginClosing({
    required double startRawInset,
    required double startEffectiveInset,
  }) {
    if (startRawInset <= _insetTolerance ||
        !widget.scrollController.hasClients) {
      return;
    }

    final position = widget.scrollController.position;
    _closingReleaseGeneration++;
    _keyboardSessionActive = true;
    _closing = true;
    _closingStartRawInset = startRawInset;
    _closingStartOffset = position.pixels;
    _closedMinScrollExtent = position.minScrollExtent;
    _closedUnclampedMaxScrollExtent =
        position.maxScrollExtent - startEffectiveInset;
    _closedMaxScrollExtent = math.max(
      _closedMinScrollExtent,
      _closedUnclampedMaxScrollExtent,
    );

    final requestedTarget = _userAdjustedScroll
        ? position.pixels
        : _sessionStartOffset ?? position.pixels;
    _closingTargetOffset = _clampToClosedExtent(requestedTarget);
  }

  void _cancelClosing() {
    _closingReleaseGeneration++;
    _closing = false;
    _userDragActive = false;
  }

  void _scheduleFinishClosingReversal() {
    final generation = ++_closingReleaseGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _closingReleaseGeneration ||
          !_closing ||
          !_canReleaseClosingAt(
            rawKeyboardInset: _rawKeyboardInset,
            effectiveKeyboardInset: _effectiveKeyboardInset,
          )) {
        return;
      }

      setState(_cancelClosing);
    });
  }

  bool _canReleaseClosingAt({
    required double rawKeyboardInset,
    required double effectiveKeyboardInset,
  }) {
    if (!_closing) return true;

    final remainingProgress = _closingStartRawInset <= _insetTolerance
        ? 0.0
        : (rawKeyboardInset / _closingStartRawInset).clamp(0.0, 1.0);
    final desiredOffset =
        _closingTargetOffset +
        (_closingStartOffset - _closingTargetOffset) * remainingProgress;
    final naturalMaxScrollExtent = math.max(
      _closedMinScrollExtent,
      _closedUnclampedMaxScrollExtent + effectiveKeyboardInset,
    );
    return desiredOffset <= naturalMaxScrollExtent + _insetTolerance;
  }

  double _clampToClosedExtent(double value) {
    return value
        .clamp(_closedMinScrollExtent, _closedMaxScrollExtent)
        .toDouble();
  }

  double? get _desiredClosingOffset {
    if (!_closing) return null;

    final remainingProgress = _closingStartRawInset <= _insetTolerance
        ? 0.0
        : (_rawKeyboardInset / _closingStartRawInset).clamp(0.0, 1.0);
    return _closingTargetOffset +
        (_closingStartOffset - _closingTargetOffset) * remainingProgress;
  }

  double get _bottomScrollExtent {
    final desiredOffset = _desiredClosingOffset;
    if (desiredOffset == null) return 0;

    if (desiredOffset <= _closedMinScrollExtent + _insetTolerance) return 0;

    final naturalUnclampedMaxScrollExtent =
        _closedUnclampedMaxScrollExtent + _effectiveKeyboardInset;
    final requiredExtent = math.max(
      0.0,
      desiredOffset - naturalUnclampedMaxScrollExtent,
    );
    final remainingProgress = _closingStartRawInset <= _insetTolerance
        ? 0.0
        : (_rawKeyboardInset / _closingStartRawInset).clamp(0.0, 1.0);

    // Below a reserved bottom bar, raw keyboard metrics can keep changing
    // while both the viewport and the natural scroll range stay constant.
    // This tiny extent makes ScrollPosition run its dimension correction for
    // those final system frames as well.
    return requiredExtent + _dimensionChangeSignalExtent * remainingProgress;
  }

  double? _adjustPositionForKeyboardClosing(ScrollMetrics newPosition) {
    if (!_closing) return null;

    if (_userDragActive) {
      // Dimension changes must not move the scroll position under the user's
      // pointer. The closing trajectory is rebased after the drag ends.
      return newPosition.pixels;
    }

    final desiredOffset = _desiredClosingOffset;
    if (desiredOffset == null) return null;

    return desiredOffset
        .clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent)
        .toDouble();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userAdjustedScroll = true;
      _userDragActive = true;
    } else if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification is ScrollEndNotification &&
        _userDragActive) {
      _userDragActive = false;
      if (_closing && _rawKeyboardInset > _insetTolerance) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_closing ||
              _rawKeyboardInset <= _insetTolerance ||
              !widget.scrollController.hasClients) {
            return;
          }

          setState(_rebaseClosingAfterUserScroll);
        });
      }
    }

    return false;
  }

  void _rebaseClosingAfterUserScroll() {
    final currentOffset = widget.scrollController.position.pixels;
    _closingStartRawInset = _rawKeyboardInset;
    _closingStartOffset = currentOffset;
    _closingTargetOffset = _clampToClosedExtent(currentOffset);
  }

  void _scheduleFinishSession() {
    final generation = ++_finishGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _finishGeneration ||
          _rawKeyboardInset > _insetTolerance) {
        return;
      }

      setState(_resetSession);
    });
  }

  void _resetSession() {
    _finishGeneration++;
    _endFocusHandoff();
    _keyboardSessionActive = false;
    _userAdjustedScroll = false;
    _userDragActive = false;
    _closing = false;
    _sessionStartOffset = null;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handlePrimaryFocusChange);
    _endFocusHandoff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollPhysics = _KeyboardMotionScrollPhysics(
      coordinator: this,
      parent: widget.scrollPhysics,
    );
    Widget layoutBuilder(BuildContext context, BoxConstraints constraints) {
      return widget.builder(
        context,
        constraints,
        scrollPhysics,
        _bottomScrollExtent,
      );
    }

    final coordinatedLayout = widget.applyKeyboardInsetToLayout
        ? KeyboardInsetLayout(
            reservedBottomInset: widget.reservedBottomInset,
            builder: layoutBuilder,
          )
        : LayoutBuilder(builder: layoutBuilder);

    return _KeyboardMotionScope(
      owner: this,
      onFocusRevealStarted: _handleFocusRevealStarted,
      onRestoreOffsetCorrection: _handleRestoreOffsetCorrection,
      onExplicitRevealStarted: _handleExplicitRevealStarted,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: coordinatedLayout,
      ),
    );
  }
}

class _KeyboardMotionScrollPhysics extends ScrollPhysics {
  final _KeyboardMotionCoordinatorState coordinator;

  const _KeyboardMotionScrollPhysics({required this.coordinator, super.parent});

  @override
  _KeyboardMotionScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _KeyboardMotionScrollPhysics(
      coordinator: coordinator,
      parent: buildParent(ancestor),
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final coordinatedPosition = coordinator._adjustPositionForKeyboardClosing(
      newPosition,
    );
    if (coordinatedPosition != null) return coordinatedPosition;

    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

class _KeyboardMotionScope extends InheritedWidget {
  final Object owner;
  final ValueChanged<Duration> onFocusRevealStarted;
  final ValueChanged<double> onRestoreOffsetCorrection;
  final VoidCallback onExplicitRevealStarted;

  const _KeyboardMotionScope({
    required this.owner,
    required this.onFocusRevealStarted,
    required this.onRestoreOffsetCorrection,
    required this.onExplicitRevealStarted,
    required super.child,
  });

  @override
  bool updateShouldNotify(_KeyboardMotionScope oldWidget) => false;
}
