import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/constants/app_ui_tokens.dart';
import 'keyboard_motion_coordinator.dart';

class KeyboardRevealController {
  _KeyboardRevealTargetState? _target;
  bool _isDisposed = false;

  void reveal() {
    assert(!_isDisposed, 'Cannot use a disposed KeyboardRevealController.');
    _target?._requestExplicitReveal();
  }

  void _attach(_KeyboardRevealTargetState target) {
    assert(!_isDisposed, 'Cannot attach a disposed KeyboardRevealController.');
    _target = target;
  }

  void _detach(_KeyboardRevealTargetState target) {
    if (identical(_target, target)) {
      _target = null;
    }
  }

  void dispose() {
    _isDisposed = true;
    _target = null;
  }
}

/// Expands an EditableText show-on-screen request to the whole decorated field.
///
/// Flutter already issues these requests when focus changes and while the
/// keyboard moves. Keeping that native request as the single scroll owner
/// avoids a second delayed correction for the field's visual margin.
/// If the whole field cannot fit, reveal the requested caret with that margin.
class KeyboardRevealTarget extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final KeyboardRevealController? controller;
  final bool revealOnFocus;
  final EdgeInsets visibilityPadding;

  /// Optional padding for the closed viewport restoration target. When null,
  /// [visibilityPadding] is used for both reveal and restoration.
  final EdgeInsets? restoreVisibilityPadding;
  final Duration focusRevealDuration;
  final Curve focusRevealCurve;

  const KeyboardRevealTarget({
    super.key,
    required this.focusNode,
    required this.child,
    this.controller,
    this.revealOnFocus = false,
    this.visibilityPadding = const EdgeInsets.all(AppDimens.gapLg),
    this.restoreVisibilityPadding,
    this.focusRevealDuration = const Duration(milliseconds: 280),
    this.focusRevealCurve = Curves.easeOutQuad,
  });

  @override
  State<KeyboardRevealTarget> createState() => _KeyboardRevealTargetState();
}

class _KeyboardRevealTargetState extends State<KeyboardRevealTarget> {
  final GlobalKey _renderTargetKey = GlobalKey();

  var _focusGeneration = 0;
  var _capturedFocusGeneration = 0;
  var _restoreOffsetReportedGeneration = 0;
  var _keyboardWasVisibleOnFocus = false;
  var _sizeMeasurementScheduled = false;
  Size? _lastTargetSize;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    widget.focusNode.addListener(_handleFocusChange);
    if (widget.focusNode.hasFocus) {
      _focusGeneration = 1;
      if (widget.revealOnFocus) {
        _reportRestoreOffsetCorrection();
        _scheduleReveal(animate: true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant KeyboardRevealTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.focusNode == widget.focusNode) {
      if (!oldWidget.revealOnFocus &&
          widget.revealOnFocus &&
          widget.focusNode.hasFocus) {
        _scheduleReveal(animate: true);
      }
      return;
    }

    oldWidget.focusNode.removeListener(_handleFocusChange);
    widget.focusNode.addListener(_handleFocusChange);
    if (widget.focusNode.hasFocus) {
      _focusGeneration++;
      if (widget.revealOnFocus) {
        _reportRestoreOffsetCorrection();
        _scheduleReveal(animate: true);
      }
    }
  }

  void _handleFocusChange() {
    if (!mounted || !widget.focusNode.hasFocus) return;

    setState(() => _focusGeneration++);
    if (widget.revealOnFocus) {
      _reportRestoreOffsetCorrection();
      _scheduleReveal(animate: true);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _requestExplicitReveal() {
    _scheduleReveal(animate: true);
  }

  void _scheduleReveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) return;

      _reportRestoreOffsetCorrection();

      final renderObject = _renderTargetKey.currentContext?.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;

      final animationsDisabled = MediaQuery.disableAnimationsOf(context);
      renderObject.showOnScreen(
        duration: animate && !animationsDisabled
            ? widget.focusRevealDuration
            : Duration.zero,
        curve: widget.focusRevealCurve,
      );
    });
  }

  void _reportRestoreOffsetCorrection() {
    if (_restoreOffsetReportedGeneration == _focusGeneration) return;

    final renderObject = _renderTargetKey.currentContext?.findRenderObject();
    if (renderObject is! _RenderKeyboardRevealTarget ||
        !renderObject.attached) {
      return;
    }

    _restoreOffsetReportedGeneration = _focusGeneration;
    renderObject.reportRestoreOffsetCorrection();
  }

  bool _handleTargetSizeChanged(SizeChangedLayoutNotification notification) {
    _scheduleTargetSizeMeasurement();
    return false;
  }

  void _scheduleTargetSizeMeasurement() {
    if (_sizeMeasurementScheduled) return;
    _sizeMeasurementScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sizeMeasurementScheduled = false;
      if (!mounted) return;

      final renderBox =
          _renderTargetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
        return;
      }

      final previousSize = _lastTargetSize;
      final currentSize = renderBox.size;
      _lastTargetSize = currentSize;

      if (previousSize != null &&
          currentSize.height > previousSize.height + 0.01 &&
          widget.controller != null &&
          widget.focusNode.hasFocus) {
        // Keep following an animated validation message with the same paced
        // reveal used for a manual focus change. A zero-duration correction
        // here cancels the in-flight scroll animation and makes validation
        // appear to jump directly to the field.
        _scheduleReveal(animate: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleTargetSizeMeasurement();

    if (_capturedFocusGeneration != _focusGeneration) {
      _capturedFocusGeneration = _focusGeneration;
      _keyboardWasVisibleOnFocus = MediaQuery.viewInsetsOf(context).bottom > 0;
    }

    return _KeyboardRevealRenderWidget(
      key: _renderTargetKey,
      focusGeneration: _focusGeneration,
      keyboardWasVisibleOnFocus: _keyboardWasVisibleOnFocus,
      visibilityPadding: widget.visibilityPadding,
      restoreVisibilityPadding:
          widget.restoreVisibilityPadding ?? widget.visibilityPadding,
      focusRevealDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : widget.focusRevealDuration,
      focusRevealCurve: widget.focusRevealCurve,
      onFocusRevealStarted:
          KeyboardMotionCoordinator.focusRevealStartedCallbackOf(context),
      onRestoreOffsetCorrection:
          KeyboardMotionCoordinator.restoreOffsetCorrectionCallbackOf(context),
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: _handleTargetSizeChanged,
        child: SizeChangedLayoutNotifier(child: widget.child),
      ),
    );
  }
}

class _KeyboardRevealRenderWidget extends SingleChildRenderObjectWidget {
  final int focusGeneration;
  final bool keyboardWasVisibleOnFocus;
  final EdgeInsets visibilityPadding;
  final EdgeInsets restoreVisibilityPadding;
  final Duration focusRevealDuration;
  final Curve focusRevealCurve;
  final ValueChanged<Duration>? onFocusRevealStarted;
  final ValueChanged<double>? onRestoreOffsetCorrection;

  const _KeyboardRevealRenderWidget({
    super.key,
    required this.focusGeneration,
    required this.keyboardWasVisibleOnFocus,
    required this.visibilityPadding,
    required this.restoreVisibilityPadding,
    required this.focusRevealDuration,
    required this.focusRevealCurve,
    required this.onFocusRevealStarted,
    required this.onRestoreOffsetCorrection,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderKeyboardRevealTarget(
      focusGeneration: focusGeneration,
      keyboardWasVisibleOnFocus: keyboardWasVisibleOnFocus,
      visibilityPadding: visibilityPadding,
      restoreVisibilityPadding: restoreVisibilityPadding,
      focusRevealDuration: focusRevealDuration,
      focusRevealCurve: focusRevealCurve,
      onFocusRevealStarted: onFocusRevealStarted,
      onRestoreOffsetCorrection: onRestoreOffsetCorrection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderKeyboardRevealTarget renderObject,
  ) {
    renderObject
      ..focusGeneration = focusGeneration
      ..keyboardWasVisibleOnFocus = keyboardWasVisibleOnFocus
      ..visibilityPadding = visibilityPadding
      ..restoreVisibilityPadding = restoreVisibilityPadding
      ..focusRevealDuration = focusRevealDuration
      ..focusRevealCurve = focusRevealCurve
      ..onFocusRevealStarted = onFocusRevealStarted
      ..onRestoreOffsetCorrection = onRestoreOffsetCorrection;
  }
}

class _RenderKeyboardRevealTarget extends RenderProxyBox {
  _RenderKeyboardRevealTarget({
    required int focusGeneration,
    required bool keyboardWasVisibleOnFocus,
    required EdgeInsets visibilityPadding,
    required EdgeInsets restoreVisibilityPadding,
    required Duration focusRevealDuration,
    required Curve focusRevealCurve,
    required ValueChanged<Duration>? onFocusRevealStarted,
    required ValueChanged<double>? onRestoreOffsetCorrection,
  }) : _focusGeneration = focusGeneration,
       _keyboardWasVisibleOnFocus = keyboardWasVisibleOnFocus,
       _visibilityPadding = visibilityPadding,
       _restoreVisibilityPadding = restoreVisibilityPadding,
       _focusRevealDuration = focusRevealDuration,
       _focusRevealCurve = focusRevealCurve,
       _onFocusRevealStarted = onFocusRevealStarted,
       _onRestoreOffsetCorrection = onRestoreOffsetCorrection;

  int _focusGeneration;
  int _handledFocusGeneration = 0;
  int? _protectedFocusGeneration;
  Duration? _protectedFocusStartedAt;
  bool _keyboardWasVisibleOnFocus;
  EdgeInsets _visibilityPadding;
  EdgeInsets _restoreVisibilityPadding;
  Duration _focusRevealDuration;
  Curve _focusRevealCurve;
  ValueChanged<Duration>? _onFocusRevealStarted;
  ValueChanged<double>? _onRestoreOffsetCorrection;

  set focusGeneration(int value) {
    if (_focusGeneration != value) {
      _protectedFocusGeneration = null;
      _protectedFocusStartedAt = null;
    }
    _focusGeneration = value;
  }

  set keyboardWasVisibleOnFocus(bool value) {
    _keyboardWasVisibleOnFocus = value;
  }

  set visibilityPadding(EdgeInsets value) {
    _visibilityPadding = value;
  }

  set restoreVisibilityPadding(EdgeInsets value) {
    _restoreVisibilityPadding = value;
  }

  set focusRevealDuration(Duration value) {
    _focusRevealDuration = value;
  }

  set focusRevealCurve(Curve value) {
    _focusRevealCurve = value;
  }

  set onFocusRevealStarted(ValueChanged<Duration>? value) {
    _onFocusRevealStarted = value;
  }

  set onRestoreOffsetCorrection(ValueChanged<double>? value) {
    _onRestoreOffsetCorrection = value;
  }

  void reportRestoreOffsetCorrection() {
    final callback = _onRestoreOffsetCorrection;
    final viewport = RenderAbstractViewport.maybeOf(this);
    if (callback == null || viewport == null) return;

    final paddedTargetInViewport = MatrixUtils.transformRect(
      getTransformTo(viewport as RenderObject),
      _targetRectForViewport(viewport, _restoreVisibilityPadding),
    );
    final viewportBounds = viewport.paintBounds;

    if (paddedTargetInViewport.bottom > viewportBounds.bottom) {
      callback(paddedTargetInViewport.bottom - viewportBounds.bottom);
    } else if (paddedTargetInViewport.top < viewportBounds.top) {
      callback(paddedTargetInViewport.top - viewportBounds.top);
    }
  }

  Rect _targetRectForViewport(
    RenderAbstractViewport viewport,
    EdgeInsets visibilityPadding, {
    Rect? requestedRect,
  }) {
    final viewportHeight = viewport.paintBounds.height;
    final paddedField = visibilityPadding.inflateRect(paintBounds);
    if (paddedField.height <= viewportHeight) return paddedField;

    // A long multiline field cannot be shown in full. Follow Flutter's caret
    // request instead of dropping the clearance from the fixed screen chrome.
    final targetBounds = requestedRect ?? paintBounds;
    final paddedTarget = visibilityPadding.inflateRect(targetBounds);
    if (paddedTarget.height <= viewportHeight) return paddedTarget;

    final maxCombinedVerticalPadding = math.max(
      0.0,
      viewportHeight - targetBounds.height,
    );
    final targetInViewport = MatrixUtils.transformRect(
      getTransformTo(viewport as RenderObject),
      targetBounds,
    );
    final topOverflow =
        viewport.paintBounds.top + visibilityPadding.top - targetInViewport.top;
    final bottomOverflow =
        targetInViewport.bottom -
        (viewport.paintBounds.bottom - visibilityPadding.bottom);

    final double topPadding;
    final double bottomPadding;
    if (topOverflow >= bottomOverflow) {
      topPadding = math.min(visibilityPadding.top, maxCombinedVerticalPadding);
      bottomPadding = maxCombinedVerticalPadding - topPadding;
    } else {
      bottomPadding = math.min(
        visibilityPadding.bottom,
        maxCombinedVerticalPadding,
      );
      topPadding = maxCombinedVerticalPadding - bottomPadding;
    }

    return EdgeInsets.fromLTRB(
      visibilityPadding.left,
      topPadding,
      visibilityPadding.right,
      bottomPadding,
    ).inflateRect(targetBounds);
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final isFirstRevealForFocus = _handledFocusGeneration != _focusGeneration;
    final shouldAnimateFocusReveal =
        isFirstRevealForFocus &&
        _focusRevealDuration > Duration.zero &&
        (duration > Duration.zero || _keyboardWasVisibleOnFocus);

    var effectiveDuration = duration;
    var effectiveCurve = curve;

    if (isFirstRevealForFocus) {
      _handledFocusGeneration = _focusGeneration;
    }

    // Replacing one open keyboard layout with another can emit zero-duration
    // caret reveals around the normal animated focus reveal. Keep all requests
    // for that handoff on one deadline so none of them can jump the viewport.
    if (shouldAnimateFocusReveal) {
      effectiveDuration = _focusRevealDuration;
      effectiveCurve = _focusRevealCurve;

      if (_keyboardWasVisibleOnFocus) {
        _protectedFocusGeneration = _focusGeneration;
        _protectedFocusStartedAt =
            SchedulerBinding.instance.currentSystemFrameTimeStamp;
      }
    } else if (_protectedFocusGeneration == _focusGeneration &&
        _protectedFocusStartedAt != null) {
      final elapsed =
          SchedulerBinding.instance.currentSystemFrameTimeStamp -
          _protectedFocusStartedAt!;
      final remaining = _focusRevealDuration - elapsed;

      if (remaining > Duration.zero) {
        effectiveDuration = remaining;
        effectiveCurve = _focusRevealCurve;
      } else {
        _protectedFocusGeneration = null;
        _protectedFocusStartedAt = null;
      }
    }

    final viewport = RenderAbstractViewport.maybeOf(this);
    Rect? requestedRect;
    if (descendant is RenderEditable &&
        descendant.maxLines != 1 &&
        (descendant.selection?.isValid ?? false)) {
      // EditableText's request already includes scroll/selection-handle padding.
      // Apply our chrome clearance to the caret itself, without stacking margins.
      requestedRect = MatrixUtils.transformRect(
        descendant.getTransformTo(this),
        descendant.getLocalRectForCaret(descendant.selection!.extent),
      );
    }
    final targetRect = viewport == null
        ? _visibilityPadding.inflateRect(paintBounds)
        : _targetRectForViewport(
            viewport,
            _visibilityPadding,
            requestedRect: requestedRect,
          );

    super.showOnScreen(
      descendant: this,
      rect: targetRect,
      duration: effectiveDuration,
      curve: effectiveCurve,
    );

    if (shouldAnimateFocusReveal && _keyboardWasVisibleOnFocus) {
      _onFocusRevealStarted?.call(_focusRevealDuration);
    }
  }
}
