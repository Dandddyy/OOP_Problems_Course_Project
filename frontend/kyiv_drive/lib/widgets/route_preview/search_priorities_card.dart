import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals, ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/rendering.dart' show ViewportOffset, ScrollDirection;

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip_search_preferences.dart';
import '../../utils/scroll_visibility.dart';
import 'visible_area_drag_listener.dart';
import '../address_widgets.dart';
import '../animated_reveal.dart';
import '../animated_touch_templates.dart';
import '../animated_value_switcher.dart';
import '../animated_value_text.dart';
import '../auth_widgets.dart';
import '../dialogs/time_picker_dialog.dart';
import '../shimmer_placeholder.dart';

class SearchPrioritiesCard extends StatefulWidget {
  final TripSearchPreferences value;
  final bool isRegularRide;
  final int routeDurationSeconds;
  final ValueChanged<TripSearchPreferences> onChanged;
  final ValueChanged<bool>? onEditingChanged;
  final bool showSkeleton;

  /// The portion of the surrounding scroll view not covered by fixed controls.
  final Rect? Function()? visibleViewport;

  const SearchPrioritiesCard({
    super.key,
    required this.value,
    required this.isRegularRide,
    required this.routeDurationSeconds,
    required this.onChanged,
    this.onEditingChanged,
    this.visibleViewport,
    this.showSkeleton = false,
  });

  @override
  State<SearchPrioritiesCard> createState() => _SearchPrioritiesCardState();
}

enum _RevealTarget { actions, primary }

enum _SelectionMotion { idle, indicator, promotion, reset }

class _PriorityRowLayout {
  final double height;
  final double contentLeft;
  final double contentRight;
  final double contentTop;
  final double markerCenter;
  final double handleVisibility;
  final double timeDetail;

  const _PriorityRowLayout({
    required this.height,
    required this.contentLeft,
    required this.contentRight,
    required this.contentTop,
    required this.markerCenter,
    required this.handleVisibility,
    required this.timeDetail,
  });

  double get stride => height + AppDimens.dividerThickness;

  _PriorityRowLayout lerp(_PriorityRowLayout target, double t) =>
      _PriorityRowLayout(
        height: lerpDouble(height, target.height, t)!,
        contentLeft: lerpDouble(contentLeft, target.contentLeft, t)!,
        contentRight: lerpDouble(contentRight, target.contentRight, t)!,
        contentTop: lerpDouble(contentTop, target.contentTop, t)!,
        markerCenter: lerpDouble(markerCenter, target.markerCenter, t)!,
        handleVisibility: lerpDouble(
          handleVisibility,
          target.handleVisibility,
          t,
        )!,
        timeDetail: lerpDouble(timeDetail, target.timeDetail, t)!,
      );
}

class _PriorityListFrame {
  final List<TripSearchPriority> order;
  final Map<TripSearchPriority, _PriorityRowLayout> layouts;
  final Map<TripSearchPriority, double> offsets;
  final TripSearchPriority selected;
  final double railTop;
  final double railHeight;

  const _PriorityListFrame({
    required this.order,
    required this.layouts,
    required this.offsets,
    required this.selected,
    required this.railTop,
    required this.railHeight,
  });
}

class _PriorityDragLanding {
  final BorderRadius shape;
  final double contentOpacity;

  const _PriorityDragLanding({
    required this.shape,
    required this.contentOpacity,
  });
}

class _SearchPrioritiesCardState extends State<SearchPrioritiesCard>
    with TickerProviderStateMixin {
  // Match the motion and selection rail of CarSelectorWidget.
  static const _animationDuration = Duration(milliseconds: 300);
  static const _promotionDuration = Duration(milliseconds: 220);
  static const _animationCurve = Cubic(0.65, 0, 0.35, 1);
  static const _timeHeight = 44.0;
  static const _rowVerticalPadding = 10.0;

  TripSearchPreferences? _draft;
  late List<TripSearchPriority> _displayOrder;
  TripSearchPriority? _pendingSelection;
  TripSearchPriority? _promotedPriority;
  _SelectionMotion _motion = _SelectionMotion.idle;
  int _pickerGeneration = 0;
  late final AnimationController _weekdaysMotion;
  late final AnimationController _modeMotion;
  late final AnimationController _dragGapRepaint;
  final _listGeometryKey = GlobalKey();
  final _actionsGeometryKey = GlobalKey();
  final _revealCardKey = GlobalKey();
  final _railKey = GlobalKey();
  final _reorderableKey = GlobalKey<SliverReorderableListState>();
  final _entryKeys = {
    for (final priority in TripSearchPriority.values) priority: GlobalKey(),
  };
  _PriorityListFrame? _lastFrame;
  _PriorityListFrame? _modeFrom;
  TripSearchPriority? _modeRisingPriority;
  Widget? _lastAction;
  Widget? _modeFromAction;
  double _lastActionHeight = 0;
  double _modeFromActionHeight = 0;
  bool _dragging = false;
  int _dragGeneration = 0;
  TripSearchPriority? _draggedPriority;
  ScrollPosition? _dragScrollPosition;
  final _dragLanding = ValueNotifier<_PriorityDragLanding?>(null);
  late final VisibleAreaDragController _visibleDrag;
  ScrollPosition? _revealPosition;
  int? _ownRevealGeneration;
  int _autoScrollGeneration = 0;
  int _revealRequest = 0;
  int? _selectionRevealGeneration;

  bool get _changingMode => _modeFrom != null;
  double _modeProgress(int milliseconds) => _animationCurve.transform(
    (_modeMotion.value * _animationDuration.inMilliseconds / milliseconds)
        .clamp(0.0, 1.0),
  );

  bool get _editing => _draft != null;
  TripSearchPreferences get _value => _draft ?? widget.value;
  bool get _numbered =>
      _editing ||
      (_value.hasCustomOrder && _value.priority != TripSearchPriority.balanced);
  Duration get _motionDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _animationDuration;
  Duration get _rowMotionDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _weekdaysMotion.isAnimating
      ? _animationDuration
      : _promotionDuration;

  @override
  void initState() {
    super.initState();
    _visibleDrag = VisibleAreaDragController(
      visibleViewport: () => widget.visibleViewport?.call(),
    );
    _displayOrder = widget.value.visibleOrder(widget.isRegularRide);
    _weekdaysMotion = AnimationController(
      vsync: this,
      duration: _animationDuration,
      value: widget.isRegularRide ? 1 : 0,
    )..addListener(_rebuildMotion);
    _dragGapRepaint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _modeMotion =
        AnimationController(vsync: this, duration: _animationDuration, value: 1)
          ..addListener(_rebuildMotion)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && _changingMode) {
              setState(() {
                _modeFrom = null;
                _modeFromAction = null;
                _modeRisingPriority = null;
              });
            }
          });
  }

  void _rebuildMotion() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    _visibleDrag.attach(scrollable);
    if (_revealPosition != scrollable?.position) {
      _revealPosition?.removeListener(_handleExternalScroll);
      _revealPosition?.isScrollingNotifier.removeListener(
        _handleExternalScroll,
      );
      _revealPosition = scrollable?.position;
      _revealPosition?.addListener(_handleExternalScroll);
      _revealPosition?.isScrollingNotifier.addListener(_handleExternalScroll);
    }
    if (MediaQuery.disableAnimationsOf(context) &&
        _weekdaysMotion.isAnimating) {
      _weekdaysMotion.value = widget.isRegularRide ? 1 : 0;
    }
    if (MediaQuery.disableAnimationsOf(context) && _modeMotion.isAnimating) {
      _modeMotion.value = 1;
    }
  }

  @override
  void dispose() {
    _revealPosition?.removeListener(_handleExternalScroll);
    _revealPosition?.isScrollingNotifier.removeListener(_handleExternalScroll);
    _cancelAutoReveal(stopScroll: false);
    _visibleDrag.dispose();
    _dragScrollPosition?.removeListener(_refreshDragGap);
    _dragLanding.dispose();
    _dragGapRepaint.dispose();
    _modeMotion.dispose();
    _weekdaysMotion.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchPrioritiesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRegularRide != widget.isRegularRide) {
      _cancelAutoReveal(stopScroll: false);
      _draft = _draft?.forRegularRide(widget.isRegularRide);
      _motion = _SelectionMotion.idle;
      _promotedPriority = null;
      final target = widget.isRegularRide ? 1.0 : 0.0;
      if (MediaQuery.disableAnimationsOf(context)) {
        _weekdaysMotion.value = target;
      } else {
        _weekdaysMotion.animateTo(target, curve: Curves.linear);
      }
    } else if (_motion != _SelectionMotion.idle &&
        widget.value.priority != _pendingSelection) {
      _motion = _SelectionMotion.idle;
      _promotedPriority = null;
    }
    if (_motion == _SelectionMotion.idle) {
      _pendingSelection = null;
      _displayOrder = widget.value.visibleOrder(widget.isRegularRide);
    }
  }

  void _change(TripSearchPreferences value) {
    if (_editing) {
      setState(() => _draft = value);
    } else {
      widget.onChanged(value);
    }
  }

  bool _showsReset(TripSearchPreferences value) =>
      value.hasCustomOrder && value.priority != TripSearchPriority.balanced;

  void _cancelAutoReveal({bool stopScroll = true}) {
    ++_autoScrollGeneration;
    ++_revealRequest;
    final wasRevealing = _ownRevealGeneration != null;
    _ownRevealGeneration = null;
    final position = _revealPosition;
    if (stopScroll &&
        wasRevealing &&
        position != null &&
        position.isScrollingNotifier.value &&
        position.userScrollDirection == ScrollDirection.idle) {
      position.jumpTo(position.pixels);
    }
  }

  void _handleExternalScroll() {
    if (_dragging) return;
    final position = _revealPosition;
    if (position == null) return;
    if (position.userScrollDirection != ScrollDirection.idle ||
        (_ownRevealGeneration == null && position.isScrollingNotifier.value)) {
      _cancelAutoReveal(stopScroll: false);
    }
  }

  void _scheduleReveal(_RevealTarget target, Duration duration) {
    if (widget.visibleViewport == null) return;
    final request = ++_revealRequest;
    final generation = _autoScrollGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          request != _revealRequest ||
          generation != _autoScrollGeneration ||
          _dragging) {
        return;
      }
      unawaited(_revealIfNeeded(target, duration));
    });
  }

  Future<void> _revealIfNeeded(_RevealTarget target, Duration duration) async {
    final visible = widget.visibleViewport?.call();
    final position = _revealPosition;
    final list = _listGeometryKey.currentContext?.findRenderObject();
    final actions = _actionsGeometryKey.currentContext?.findRenderObject();
    final card = _revealCardKey.currentContext?.findRenderObject();
    if (visible == null ||
        visible.isEmpty ||
        position == null ||
        list is! RenderBox ||
        actions is! RenderBox ||
        card is! RenderBox ||
        !list.attached ||
        !actions.attached ||
        !card.attached) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final order = [
      ..._value.visibleOrder(widget.isRegularRide),
      TripSearchPriority.balanced,
    ];
    final layouts = {
      for (final priority in order)
        priority: _layoutFor(priority, list.size.width, l10n),
    };
    final finalListHeight = layouts.values.fold<double>(
      0,
      (height, layout) => height + layout.stride,
    );
    final finalActionsHeight = _actionHeight(l10n, list.size.width);
    final origin = list.localToGlobal(Offset.zero);
    final cardTop = card.localToGlobal(Offset.zero).dy;
    final finalHintHeight =
        _textHeight(
          _editing ? l10n.rankSearchPriorities : l10n.chooseMainSearchPriority,
          AppText.hint,
          list.size.width - 16,
        ) +
        8;
    final hintDelta = finalHintHeight - (origin.dy - cardTop);
    final finalListTop = origin.dy + hintDelta;
    final bottom = finalListTop + finalListHeight + finalActionsHeight;
    final cardRect = Rect.fromLTRB(
      origin.dx,
      cardTop,
      origin.dx + list.size.width,
      bottom,
    );
    final focus = target == _RevealTarget.actions
        ? Rect.fromLTRB(
            cardRect.left,
            math.max(cardTop, bottom - visible.height),
            cardRect.right,
            bottom,
          )
        : Rect.fromLTRB(
            cardRect.left,
            cardTop,
            cardRect.right,
            math.min(
              cardTop + visible.height,
              finalListTop + layouts[order.first]!.height,
            ),
          );
    final targetRect = cardRect.height <= visible.height ? cardRect : focus;
    var delta = calculateMinimalRevealScrollDelta(
      targetRect: targetRect,
      visibleRect: visible,
    );
    // Closing or shrinking a footer should preserve the user's reading position.
    if (target == _RevealTarget.actions) delta = math.max(0, delta);
    if (delta.abs() < 0.5) return;
    final extentDelta =
        finalListHeight +
        finalActionsHeight -
        list.size.height -
        actions.size.height +
        hintDelta;
    final maxExtent = math.max(
      position.minScrollExtent,
      position.maxScrollExtent + extentDelta,
    );
    final offset = (position.pixels + delta)
        .clamp(position.minScrollExtent, maxExtent)
        .toDouble();
    if ((offset - position.pixels).abs() < 0.5) return;
    if (MediaQuery.disableAnimationsOf(context) || duration == Duration.zero) {
      position.jumpTo(offset);
      return;
    }
    final generation = _autoScrollGeneration;
    _ownRevealGeneration = generation;
    await position.animateTo(
      offset,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
    if (_ownRevealGeneration == generation) _ownRevealGeneration = null;
  }

  void _select(TripSearchPriority priority) {
    if (_editing || _changingMode || priority == widget.value.priority) {
      return;
    }
    _cancelAutoReveal();
    _selectionRevealGeneration = _autoScrollGeneration;
    final next = widget.value.select(priority);
    final resetAppears = !_showsReset(widget.value) && _showsReset(next);
    final animate = _motionDuration != Duration.zero;
    final promote =
        next.hasCustomOrder &&
        priority != TripSearchPriority.balanced &&
        priority != _displayOrder.first;
    setState(() {
      _pendingSelection = priority;
      _motion = animate && promote
          ? _SelectionMotion.indicator
          : _SelectionMotion.idle;
      if (!animate) {
        _displayOrder = next.visibleOrder(widget.isRegularRide);
        _pendingSelection = null;
        _promotedPriority = null;
      } else if (!promote) {
        // Without a custom order, selection only moves the indicator.
        _pendingSelection = null;
      }
    });
    // Commit preferences immediately; only their visual order waits for the rail.
    widget.onChanged(next);
    if (promote && !animate) {
      _scheduleReveal(_RevealTarget.primary, Duration.zero);
    } else if (!promote && resetAppears) {
      _scheduleReveal(_RevealTarget.actions, _motionDuration);
    }
  }

  void _indicatorAnimationEnded() {
    if (_motion == _SelectionMotion.idle && _promotedPriority == null) return;
    final priority = _pendingSelection;
    if (_motion == _SelectionMotion.indicator &&
        widget.value.hasCustomOrder &&
        priority != null &&
        priority != TripSearchPriority.balanced &&
        widget.value.priority == priority &&
        _displayOrder.first != priority) {
      setState(() {
        _motion = _SelectionMotion.promotion;
        _promotedPriority = priority;
        _displayOrder = widget.value.visibleOrder(widget.isRegularRide);
      });
      if (_selectionRevealGeneration == _autoScrollGeneration) {
        _scheduleReveal(_RevealTarget.primary, _rowMotionDuration);
      }
    } else {
      setState(() {
        _motion = _SelectionMotion.idle;
        _pendingSelection = null;
        _promotedPriority = null;
      });
    }
  }

  void _beginModeChange() {
    _modeFrom = _motionDuration == Duration.zero ? null : _lastFrame;
    if (_modeFrom != null) {
      // Read the painted positions too, so a quick action can interrupt a rail
      // or mode transition without snapping to its previous destination.
      final box =
          _listGeometryKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final frame = _modeFrom!;
        final offsets = Map<TripSearchPriority, double>.of(frame.offsets);
        for (final priority in frame.order) {
          final rowBox = _entryKeys[priority]!.currentContext
              ?.findRenderObject();
          if (rowBox is RenderBox) {
            offsets[priority] = box
                .globalToLocal(rowBox.localToGlobal(Offset.zero))
                .dy;
          }
        }
        final rail = _railKey.currentContext?.findRenderObject() as RenderBox?;
        _modeFrom = _PriorityListFrame(
          order: frame.order,
          layouts: frame.layouts,
          offsets: offsets,
          selected: frame.selected,
          railTop: rail == null
              ? frame.railTop
              : box.globalToLocal(rail.localToGlobal(Offset.zero)).dy,
          railHeight: rail?.size.height ?? frame.railHeight,
        );
      }
      _modeFromAction = _lastAction;
      _modeFromActionHeight = _lastActionHeight;
      _modeMotion.forward(from: 0);
    }
  }

  void _startEditing() {
    if (_motion != _SelectionMotion.idle || _editing) return;
    _cancelAutoReveal();
    final order = widget.value.visibleOrder(widget.isRegularRide);
    final priority = widget.value.priority;
    if (!widget.value.hasCustomOrder &&
        priority != TripSearchPriority.balanced) {
      order.remove(priority);
      order.insert(0, priority);
    }
    _beginModeChange();
    setState(() {
      _modeRisingPriority = order.first != _displayOrder.first
          ? order.first
          : null;
      _pendingSelection = null;
      _promotedPriority = null;
      _draft = widget.value.withOrder(order);
    });
    widget.onEditingChanged?.call(true);
    _scheduleReveal(_RevealTarget.actions, _motionDuration);
  }

  void _finishEditing({required bool save}) {
    final value = _draft;
    if (value == null || _dragging) return;
    _cancelAutoReveal();
    _reorderableKey.currentState?.cancelReorder();
    _beginModeChange();
    ++_pickerGeneration;
    setState(() {
      _modeRisingPriority = save ? null : widget.value.priority;
      _draft = null;
      _displayOrder = (save ? value : widget.value).visibleOrder(
        widget.isRegularRide,
      );
    });
    if (save) widget.onChanged(value);
    widget.onEditingChanged?.call(false);
    if (save) _scheduleReveal(_RevealTarget.actions, _motionDuration);
  }

  void _reorder(int oldIndex, int newIndex) {
    if (!_editing) return;
    final order = _value.visibleOrder(widget.isRegularRide);
    order.insert(newIndex, order.removeAt(oldIndex));
    _change(_value.withOrder(order));
  }

  void _resetOrder() {
    if (_editing ||
        _changingMode ||
        _motion != _SelectionMotion.idle ||
        !widget.value.hasCustomOrder ||
        widget.value.priority == TripSearchPriority.balanced) {
      return;
    }
    _cancelAutoReveal();
    final next = widget.value.withoutCustomOrder();
    final nextOrder = next.visibleOrder(widget.isRegularRide);
    // A stationary rail has no onEnd callback to release the ordering controls.
    final selectionMoves =
        _displayOrder.indexOf(next.priority) !=
        nextOrder.indexOf(next.priority);
    final animate = selectionMoves && _motionDuration != Duration.zero;
    setState(() {
      _motion = animate ? _SelectionMotion.reset : _SelectionMotion.idle;
      _pendingSelection = animate ? next.priority : null;
      _promotedPriority = animate ? next.priority : null;
      _displayOrder = nextOrder;
    });
    widget.onChanged(next);
  }

  Future<void> _pickTime(TripSearchPriority priority) async {
    _cancelAutoReveal();
    final generation = ++_pickerGeneration;
    final minutes = priority == TripSearchPriority.departure
        ? _value.departureMinutes
        : _value.arrivalMinutes(widget.routeDurationSeconds);
    final picked = await AppTimePicker.showTimePicker(
      context,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
      brandColor: AppColors.passenger,
    );
    if (!mounted || picked == null || generation != _pickerGeneration) return;
    final time = picked.hour * 60 + picked.minute;
    _change(
      priority == TripSearchPriority.departure
          ? _value.withDeparture(time)
          : _value.withArrival(time),
    );
  }

  String _label(TripSearchPriority priority, AppLocalizations l10n) =>
      switch (priority) {
        TripSearchPriority.departure => l10n.priorityDeparture,
        TripSearchPriority.arrival => l10n.priorityArrival,
        TripSearchPriority.walking => l10n.priorityWalking,
        TripSearchPriority.price => l10n.priorityPrice,
        TripSearchPriority.weekdays => l10n.priorityWeekdays,
        TripSearchPriority.balanced => l10n.noSearchPriority,
      };

  IconData _icon(TripSearchPriority priority) => switch (priority) {
    TripSearchPriority.departure => Icons.radio_button_checked,
    TripSearchPriority.arrival => Icons.location_on,
    TripSearchPriority.walking => Icons.directions_walk_rounded,
    TripSearchPriority.price => Icons.payments_outlined,
    TripSearchPriority.weekdays => Icons.calendar_month_rounded,
    TripSearchPriority.balanced => Icons.balance_rounded,
  };

  double _rowOpacity(TripSearchPriority priority) {
    if (_value.priority == priority) return 1;
    if (priority == TripSearchPriority.balanced) return 0.35;
    return _numbered ? 0.75 : 0.45;
  }

  bool _hasTime(TripSearchPriority priority) =>
      priority == TripSearchPriority.departure ||
      priority == TripSearchPriority.arrival;

  String? _dayOffset(TripSearchPriority priority, AppLocalizations l10n) =>
      priority == TripSearchPriority.arrival &&
          _value.arrivalMinutes(widget.routeDurationSeconds) >= 1440
      ? l10n.priorityArrivalDayOffset(
          _value.arrivalMinutes(widget.routeDurationSeconds) ~/ 1440,
        )
      : null;

  TextPainter _textPainter(String text, TextStyle style) => TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.localeOf(context),
  );

  double _textHeight(String text, TextStyle style, double width) {
    final painter = _textPainter(text, style)
      ..layout(maxWidth: math.max(1, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  _PriorityRowLayout _layoutFor(
    TripSearchPriority priority,
    double width,
    AppLocalizations l10n,
  ) {
    // Keep the moving rows and rail aligned when labels wrap or text is scaled.
    final reorderable = _editing && priority != TripSearchPriority.balanced;
    final innerWidth = width - 2 * AppDimens.gapLg;
    final separateHandle = reorderable && innerWidth < 288;
    const markerWidth = 28.0;
    final contentWidth = separateHandle
        ? innerWidth
        : innerWidth - markerWidth - AppDimens.gapMd - (reorderable ? 48 : 0);
    final compactTime = contentWidth < 240;
    var textWidth = contentWidth;
    if (_hasTime(priority)) {
      final painter = _textPainter(
        '00:00',
        AppText.compactButton.copyWith(fontWeight: FontWeight.bold),
      )..layout();
      final timeWidth = painter.width + (compactTime ? 16 : 50);
      painter.dispose();
      textWidth -= timeWidth + AppDimens.gapSm;
    }
    var bodyHeight = _textHeight(
      _label(priority, l10n),
      AppText.listTitle,
      textWidth,
    );
    if (priority == TripSearchPriority.balanced) {
      bodyHeight +=
          AppDimens.gapXs +
          _textHeight(
            l10n.balancedSearchDescription,
            AppText.listSubtitle,
            textWidth,
          );
    } else if (_hasTime(priority)) {
      if (priority == TripSearchPriority.arrival) {
        // Reserve the secondary line inside the label column, beside the time.
        // It fits within the 44px time control at the normal text size.
        final dayOffset = _dayOffset(priority, l10n);
        final subtitleHeight = math.max(
          _textHeight(
            l10n.priorityArrivalDayOffset(1),
            AppText.listSubtitle,
            textWidth,
          ),
          _textHeight(dayOffset ?? '', AppText.listSubtitle, textWidth),
        );
        bodyHeight += AppDimens.gapXs + subtitleHeight;
      }
      bodyHeight = math.max(bodyHeight, _timeHeight);
    }
    return _PriorityRowLayout(
      height: math
          .max(
            AppDimens.rowHeight,
            bodyHeight + 2 * _rowVerticalPadding + (separateHandle ? 52 : 0),
          )
          .ceilToDouble(),
      contentLeft:
          AppDimens.gapLg +
          (separateHandle ? 0 : markerWidth + AppDimens.gapMd),
      contentRight: AppDimens.gapLg + (reorderable && !separateHandle ? 48 : 0),
      contentTop: _rowVerticalPadding + (separateHandle ? 52 : 0),
      markerCenter: separateHandle
          ? _rowVerticalPadding + 24
          : math
                    .max(
                      AppDimens.rowHeight,
                      bodyHeight + 2 * _rowVerticalPadding,
                    )
                    .ceilToDouble() /
                2,
      handleVisibility: reorderable ? 1 : 0,
      timeDetail: compactTime ? 0 : 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: _revealCardKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: _placeholder(
            AnimatedValueText(
              _editing
                  ? l10n.rankSearchPriorities
                  : l10n.chooseMainSearchPriority,
              style: AppText.hint,
            ),
          ),
        ),
        AnimatedContainer(
          key: const ValueKey('search-priorities-card'),
          duration: AppDurations.fieldState,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.formControlBr,
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildContents(l10n),
        ),
      ],
    );
  }

  Widget _placeholder(Widget child) =>
      widget.showSkeleton ? ShimmerPlaceholder(child: child) : child;

  Widget _buildContents(AppLocalizations l10n) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final order = _editing
              ? _value.visibleOrder(widget.isRegularRide)
              : _withExitingWeekdays(_displayOrder);
          final layouts = {
            for (final priority in [...order, TripSearchPriority.balanced])
              priority: _layoutFor(priority, constraints.maxWidth, l10n),
          };
          final entries = [...order, TripSearchPriority.balanced];
          final offsets = _offsetsFor(entries, layouts);
          final selected = _pendingSelection ?? _value.priority;
          final frame = _PriorityListFrame(
            order: entries,
            layouts: layouts,
            offsets: offsets,
            selected: selected,
            railTop: offsets[selected] ?? 0,
            railHeight:
                layouts[selected]?.height ?? layouts[entries.first]!.height,
          );
          final contents = _changingMode
              ? _buildModeList(frame, l10n)
              : _editing
              ? _buildReorderableList(order, layouts, l10n)
              : _buildAnimatedList(order, layouts, l10n);
          if (!_changingMode) _lastFrame = frame;
          return SizedBox(key: _listGeometryKey, child: contents);
        },
      ),
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          key: _actionsGeometryKey,
          child: _buildAction(l10n, constraints.maxWidth),
        ),
      ),
    ],
  );

  Map<TripSearchPriority, double> _offsetsFor(
    List<TripSearchPriority> order,
    Map<TripSearchPriority, _PriorityRowLayout> layouts,
  ) {
    final offsets = <TripSearchPriority, double>{};
    var offset = 0.0;
    for (final priority in order) {
      offsets[priority] = offset;
      offset +=
          layouts[priority]!.stride *
          (priority == TripSearchPriority.weekdays
              ? _animationCurve.transform(_weekdaysMotion.value)
              : 1);
    }
    return offsets;
  }

  Widget _buildModeList(_PriorityListFrame target, AppLocalizations l10n) {
    final from = _modeFrom!;
    final layoutT = _modeProgress(250);
    final rowT = _modeProgress(220);
    final railT = _modeProgress(300);
    final layouts = {
      for (final priority in target.order)
        priority: (from.layouts[priority] ?? target.layouts[priority]!).lerp(
          target.layouts[priority]!,
          layoutT,
        ),
    };
    final fromOrder = [
      ...from.order.where(target.order.contains),
      ...target.order.where((priority) => !from.order.contains(priority)),
    ];
    // Grow the slots with their rows while reordering them. Preserve any
    // remaining displacement when the user reverses an unfinished transition.
    final fromOffsets = _offsetsFor(fromOrder, layouts);
    final originalOffsets = _offsetsFor(from.order, from.layouts);
    final targetOffsets = _offsetsFor(target.order, layouts);
    final offsets = {
      for (final priority in target.order)
        priority:
            lerpDouble(fromOffsets[priority], targetOffsets[priority], rowT)! +
            ((from.offsets[priority] ?? fromOffsets[priority]!) -
                    (originalOffsets[priority] ?? fromOffsets[priority]!)) *
                (1 - rowT),
    };
    final sameSelection = from.selected == target.selected;
    final railTop = sameSelection
        ? offsets[target.selected]! +
              (from.railTop - (from.offsets[target.selected] ?? from.railTop)) *
                  (1 - rowT)
        : lerpDouble(from.railTop, offsets[target.selected], railT)!;
    final railHeight = lerpDouble(
      from.railHeight,
      layouts[target.selected]!.height,
      railT,
    )!;
    _lastFrame = _PriorityListFrame(
      order: target.order,
      layouts: layouts,
      offsets: offsets,
      selected: target.selected,
      railTop: railTop,
      railHeight: railHeight,
    );
    final rising = _modeRisingPriority;
    final paintOrder = [
      ...target.order.where((priority) => priority != rising),
      if (rising != null && target.order.contains(rising)) rising,
    ];
    return SizedBox(
      height: target.order.fold<double>(
        0,
        (height, priority) =>
            height +
            layouts[priority]!.stride *
                (priority == TripSearchPriority.weekdays
                    ? _animationCurve.transform(_weekdaysMotion.value)
                    : 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final priority in paintOrder)
            Positioned(
              left: 0,
              right: 0,
              top: offsets[priority],
              child: _buildMovingEntry(
                priority,
                target.order.indexOf(priority),
                layouts[priority]!,
                l10n,
                priority == rising,
              ),
            ),
          Positioned(
            left: 0,
            top: railTop,
            width: 4,
            height: railHeight,
            child: IgnorePointer(child: _selectionIndicator()),
          ),
        ],
      ),
    );
  }

  List<TripSearchPriority> _withExitingWeekdays(
    List<TripSearchPriority> order,
  ) {
    if (widget.isRegularRide || _weekdaysMotion.value == 0) return order;
    final index = widget.value.order.indexOf(TripSearchPriority.weekdays);
    return [...order]
      ..insert(index.clamp(0, order.length), TripSearchPriority.weekdays);
  }

  Widget _buildAnimatedList(
    List<TripSearchPriority> order,
    Map<TripSearchPriority, _PriorityRowLayout> layouts,
    AppLocalizations l10n,
  ) {
    final entries = [...order, TripSearchPriority.balanced];
    final offsets = <TripSearchPriority, double>{};
    var height = 0.0;
    for (final priority in entries) {
      offsets[priority] = height;
      height +=
          layouts[priority]!.stride *
          (priority == TripSearchPriority.weekdays
              ? _animationCurve.transform(_weekdaysMotion.value)
              : 1);
    }
    final selected = _pendingSelection ?? _value.priority;
    final promoted = _promotedPriority;
    // Let an interrupted promotion finish smoothly while the rail retargets.
    // Keep the rising row above its neighbours until that movement is complete.
    final paintOrder = [
      for (final priority in TripSearchPriority.values)
        if (entries.contains(priority) && priority != promoted) priority,
      ?promoted,
    ];
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final priority in paintOrder)
            AnimatedPositioned(
              key: ValueKey('position-priority-${priority.name}'),
              duration: _weekdaysMotion.isAnimating
                  ? Duration.zero
                  : _rowMotionDuration,
              curve: _animationCurve,
              left: 0,
              right: 0,
              top: offsets[priority],
              child: _buildMovingEntry(
                priority,
                entries.indexOf(priority),
                layouts[priority]!,
                l10n,
                promoted == priority,
              ),
            ),
          AnimatedPositioned(
            duration: _weekdaysMotion.isAnimating
                ? Duration.zero
                : _motion == _SelectionMotion.promotion ||
                      _motion == _SelectionMotion.reset
                ? _rowMotionDuration
                : _motionDuration,
            curve: _animationCurve,
            onEnd: _indicatorAnimationEnded,
            left: 0,
            width: 4,
            top: offsets[selected] ?? 0,
            height: layouts[selected]?.height ?? layouts[entries.first]!.height,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: _motionDuration,
                opacity: offsets.containsKey(selected) ? 1 : 0,
                child: _selectionIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovingEntry(
    TripSearchPriority priority,
    int index,
    _PriorityRowLayout layout,
    AppLocalizations l10n,
    bool promoted,
  ) {
    final child = SizedBox(
      height: layout.stride,
      child: ColoredBox(
        color: promoted ? AppColors.floatingSurface : Colors.transparent,
        child: _buildEntry(priority, index, layout, l10n),
      ),
    );
    if (priority != TripSearchPriority.weekdays) return child;
    final animation = _weekdaysMotion.drive(CurveTween(curve: _animationCurve));
    return IgnorePointer(
      ignoring: !widget.isRegularRide,
      child: ExcludeSemantics(
        excluding: !widget.isRegularRide,
        child: ClipRect(
          child: SizeTransition(
            sizeFactor: animation,
            alignment: AlignmentDirectional.topStart,
            child: FadeTransition(opacity: animation, child: child),
          ),
        ),
      ),
    );
  }

  Widget _selectionIndicator() => KeyedSubtree(
    key: _railKey,
    child: widget.showSkeleton
        ? const ShimmerBlock(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 4,
          )
        : AnimatedOpacity(
            key: const ValueKey('priority-rail-drag-visibility'),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            opacity: _dragging ? 0 : 1,
            child: Container(
              key: const ValueKey('priority-selection-indicator'),
              decoration: const BoxDecoration(
                color: AppColors.passengerAccent,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
  );

  BorderRadius _rowShape(int index) => index == 0
      ? const BorderRadius.vertical(top: Radius.circular(AppRadius.control))
      : BorderRadius.zero;

  void _dragEnded(int insertionIndex) {
    final priority = _draggedPriority;
    if (priority == null) return;
    final originalIndex = _value
        .visibleOrder(widget.isRegularRide)
        .indexOf(priority);
    final targetIndex = insertionIndex > originalIndex
        ? insertionIndex - 1
        : insertionIndex;
    _dragLanding.value = _PriorityDragLanding(
      shape: _rowShape(targetIndex),
      contentOpacity: targetIndex == 0 ? 1 : 0.75,
    );
  }

  void _refreshDragGap() {
    if (_dragging) _dragGapRepaint.forward(from: 0);
  }

  void _dragProxyRemoved(int generation) {
    // The native drop continues after pointer-up. Keep Save/Cancel locked until
    // its reorder callback has applied the final draft, including no-op drops.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dragging || generation != _dragGeneration) return;
      _dragGapRepaint.stop();
      _dragScrollPosition?.removeListener(_refreshDragGap);
      _dragScrollPosition = null;
      setState(() {
        _dragging = false;
        _draggedPriority = null;
      });
    });
  }

  Widget _buildReorderableList(
    List<TripSearchPriority> order,
    Map<TripSearchPriority, _PriorityRowLayout> layouts,
    AppLocalizations l10n,
  ) => Listener(
    onPointerMove: (_) => _refreshDragGap(),
    onPointerUp: (_) => _refreshDragGap(),
    onPointerCancel: (_) => _refreshDragGap(),
    child: Stack(
      children: [
        CustomPaint(
          key: const ValueKey('priority-drag-slots'),
          painter: _draggedPriority == null
              ? null
              : _PriorityDragGapPainter(
                  listKey: _listGeometryKey,
                  entryKeys: _entryKeys,
                  order: [...order, TripSearchPriority.balanced],
                  draggedPriority: _draggedPriority!,
                  repaint: _dragGapRepaint,
                ),
          child: Column(
            children: [
              // Reuse the page's Scrollable, like the waypoint editor. A nested
              // non-scrollable ListView would prevent native edge auto-scrolling.
              ShrinkWrappingViewport(
                axisDirection: AxisDirection.down,
                offset: ViewportOffset.zero(),
                slivers: [
                  SliverReorderableList(
                    key: _reorderableKey,
                    itemCount: order.length,
                    onReorderItem: _reorder,
                    onReorderStart: (index) {
                      _cancelAutoReveal();
                      ++_dragGeneration;
                      _dragLanding.value = null;
                      _dragGapRepaint.forward(from: 0);
                      _dragScrollPosition?.removeListener(_refreshDragGap);
                      _dragScrollPosition = Scrollable.maybeOf(
                        context,
                      )?.position;
                      _dragScrollPosition?.addListener(_refreshDragGap);
                      setState(() {
                        _dragging = true;
                        _draggedPriority = order[index];
                      });
                    },
                    onReorderEnd: _dragEnded,
                    dragBoundaryProvider: widget.visibleViewport == null
                        ? null
                        : (_) => _visibleDrag,
                    proxyDecorator: (child, index, animation) {
                      final generation = _dragGeneration;
                      return _PriorityDragProxy(
                        animation: animation,
                        originShape: _rowShape(index),
                        originOpacity: _rowOpacity(order[index]),
                        landing: _dragLanding,
                        onRemoved: () => _dragProxyRemoved(generation),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) => _buildEntry(
                      order[index],
                      index,
                      layouts[order[index]]!,
                      l10n,
                    ),
                  ),
                ],
              ),
              _buildEntry(
                TripSearchPriority.balanced,
                order.length,
                layouts[TripSearchPriority.balanced]!,
                l10n,
              ),
            ],
          ),
        ),
        AnimatedPositioned(
          // Resolve the new first row's height while the rail is still hidden.
          duration: _dragging ? Duration.zero : _motionDuration,
          curve: _animationCurve,
          left: 0,
          top: 0,
          width: 4,
          height: layouts[order.first]!.height,
          child: IgnorePointer(child: _selectionIndicator()),
        ),
      ],
    ),
  );

  Widget _buildEntry(
    TripSearchPriority priority,
    int index,
    _PriorityRowLayout layout,
    AppLocalizations l10n,
  ) {
    final balanced = priority == TripSearchPriority.balanced;
    final numbered = _numbered && !balanced;
    final content = _priorityContent(priority, layout, l10n);
    final rankStyle = AppText.badge.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    final markerHeight = math.max(28.0, _textHeight('4', rankStyle, 28));
    final symbol = _placeholder(
      numbered
          ? Text(
              '${index + 1}',
              key: ValueKey('rank-priority-${priority.name}'),
              textAlign: TextAlign.center,
              style: rankStyle,
            )
          : Icon(
              _icon(priority),
              key: ValueKey('icon-priority-${priority.name}'),
              color: AppColors.iconSecondary,
              size: 24,
            ),
    );
    final marker = SizedBox(
      width: 28,
      child: AnimatedValueSwitcher(
        child: KeyedSubtree(
          key: ValueKey(numbered ? index + 1 : null),
          child: symbol,
        ),
      ),
    );
    return KeyedSubtree(
      key: _entryKeys[priority],
      child: Semantics(
        key: ValueKey('priority-row-${priority.name}'),
        sortKey: OrdinalSortKey(index.toDouble()),
        button: !_editing,
        enabled: !_editing || !balanced,
        selected: _value.priority == priority,
        child: Column(
          children: [
            AnimatedTouchItem(
              key: ValueKey('select-priority-${priority.name}'),
              onTap: widget.showSkeleton || _editing || _changingMode
                  ? null
                  : () => _select(priority),
              normalColor: Colors.transparent,
              pressedColor: Colors.transparent,
              pressedScale: 0.97,
              borderRadius: BorderRadius.zero,
              child: Builder(
                builder: (context) {
                  final dragAppearance = _PriorityDragAppearance.maybeOf(
                    context,
                  );
                  return AnimatedOpacity(
                    key: ValueKey('content-priority-${priority.name}'),
                    duration:
                        dragAppearance != null ||
                            MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : _animationDuration,
                    curve: _animationCurve,
                    opacity: widget.showSkeleton
                        ? 1
                        : dragAppearance?.contentOpacity ??
                              _rowOpacity(priority),
                    child: SizedBox(
                      height: layout.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: AppDimens.gapLg,
                            top: layout.markerCenter - markerHeight / 2,
                            width: 28,
                            height: markerHeight,
                            child: Center(child: marker),
                          ),
                          Positioned(
                            left: layout.contentLeft,
                            right: layout.contentRight,
                            top: layout.contentTop,
                            bottom: _rowVerticalPadding,
                            child: Center(
                              child: OverflowBox(
                                minHeight: 0,
                                maxHeight: double.infinity,
                                alignment: Alignment.centerLeft,
                                child: content,
                              ),
                            ),
                          ),
                          if (!balanced && layout.handleVisibility > 0)
                            Positioned(
                              right: AppDimens.gapLg,
                              top: layout.markerCenter - 24,
                              child: IgnorePointer(
                                ignoring: !_editing || _changingMode,
                                child: ExcludeSemantics(
                                  excluding: !_editing || _changingMode,
                                  child: Opacity(
                                    opacity: layout.handleVisibility,
                                    child: _dragHandle(priority, index, l10n),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Builder(
              builder: (context) => Container(
                key: ValueKey('divider-priority-${priority.name}'),
                height: AppDimens.dividerThickness,
                color: _PriorityDragAppearance.maybeOf(context) == null
                    ? AppColors.borderMuted
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityContent(
    TripSearchPriority priority,
    _PriorityRowLayout layout,
    AppLocalizations l10n,
  ) {
    final label = _placeholder(
      Text(
        _label(priority, l10n),
        key: ValueKey('priority-${priority.name}-label'),
        style: AppText.listTitle,
      ),
    );
    if (priority == TripSearchPriority.balanced) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          label,
          const SizedBox(height: AppDimens.gapXs),
          if (widget.showSkeleton)
            ShimmerParagraph(
              l10n.balancedSearchDescription,
              style: AppText.listSubtitle,
            )
          else
            Text(l10n.balancedSearchDescription, style: AppText.listSubtitle),
        ],
      );
    }
    if (!_hasTime(priority)) return label;
    final dayOffset = _dayOffset(priority, l10n);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label:
                '${_label(priority, l10n)}${dayOffset == null ? '' : ', $dayOffset'}',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                AnimatedValueSwitcher(
                  alignment: AlignmentDirectional.centerStart,
                  child: dayOffset == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(dayOffset),
                          padding: const EdgeInsets.only(top: AppDimens.gapXs),
                          child: _placeholder(
                            Text(
                              dayOffset,
                              key: const ValueKey(
                                'priority-arrival-day-offset',
                              ),
                              style: AppText.listSubtitle,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppDimens.gapSm),
        _timeControl(priority, detail: layout.timeDetail),
      ],
    );
  }

  Widget _dragHandle(
    TripSearchPriority priority,
    int index,
    AppLocalizations l10n,
  ) => Semantics(
    label: _label(priority, l10n),
    customSemanticsActions: {
      if (index > 0)
        CustomSemanticsAction(label: l10n.movePriorityUp): () =>
            _reorder(index, index - 1),
      if (index < _value.visibleOrder(widget.isRegularRide).length - 1)
        CustomSemanticsAction(label: l10n.movePriorityDown): () =>
            _reorder(index, index + 1),
    },
    child: VisibleAreaDragStartListener(
      controller: _visibleDrag,
      key: ValueKey('drag-priority-${priority.name}'),
      index: index,
      child: SizedBox(
        width: 44,
        height: 48,
        child: Builder(
          builder: (context) => Icon(
            Icons.drag_handle_rounded,
            color: Color.lerp(
              AppColors.iconMuted,
              AppColors.iconSecondary,
              _PriorityDragAppearance.maybeOf(context)?.progress ?? 0,
            ),
            size: 24,
          ),
        ),
      ),
    ),
  );

  Widget _timeControl(TripSearchPriority priority, {required double detail}) {
    final minutes = priority == TripSearchPriority.departure
        ? _value.departureMinutes
        : _value.arrivalMinutes(widget.routeDurationSeconds);
    return Semantics(
      button: true,
      child: AnimatedTouchItem(
        key: ValueKey('priority-${priority.name}-time'),
        isolatePressFeedback: true,
        onTap: widget.showSkeleton ? null : () => _pickTime(priority),
        normalColor: AppColors.surfacePressed,
        pressedColor: AppColors.surfaceStrong,
        pressedScale: 0.95,
        pressedOpacity: 0.6,
        borderRadius: AppRadius.compactControlBr,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: lerpDouble(AppDimens.gapSm, AppDimens.gapMd, detail)!,
          ),
          child: SizedBox(
            height: _timeHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRect(
                  child: Align(
                    widthFactor: detail,
                    child: Opacity(
                      opacity: detail,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _placeholder(
                            const Icon(
                              Icons.access_time_rounded,
                              color: AppColors.iconSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppDimens.gapSm),
                        ],
                      ),
                    ),
                  ),
                ),
                _placeholder(
                  AnimatedValueText(
                    TripSearchPreferences.formatTime(minutes),
                    style: AppText.compactButton.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _orderActionHeight(String label, double width) => math.max(
    50,
    _textHeight(
          label,
          AppText.compactButton.copyWith(fontSize: 14),
          width - 32 - 22 - AppDimens.gapSm,
        ) +
        24,
  );

  double _actionHeight(AppLocalizations l10n, double width) => _editing
      ? 2 * AppDimens.gapMd + AppDimens.buttonHeight
      : _orderActionHeight(l10n.orderSearchPriorities, width) +
            (_value.hasCustomOrder &&
                    _value.priority != TripSearchPriority.balanced
                ? AppDimens.dividerThickness +
                      _orderActionHeight(l10n.resetSearchPriorities, width)
                : 0);

  Widget _buildAction(AppLocalizations l10n, double width) {
    final content = _buildActionContents(l10n);
    final targetHeight = _actionHeight(l10n, width);
    if (!_changingMode) {
      _lastAction = content;
      _lastActionHeight = targetHeight;
      return content;
    }
    final progress = _modeProgress(300);
    final height = lerpDouble(_modeFromActionHeight, targetHeight, progress)!;
    final action = SizedBox(
      key: const ValueKey('priority-mode-actions'),
      height: height,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _modeFromActionHeight,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(opacity: 1 - progress, child: _modeFromAction),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: targetHeight,
              child: Opacity(opacity: progress, child: content),
            ),
          ],
        ),
      ),
    );
    _lastAction = action;
    _lastActionHeight = height;
    return action;
  }

  Widget _buildActionContents(AppLocalizations l10n) {
    if (_editing) {
      return AbsorbPointer(
        absorbing: _dragging,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapMd),
          child: Row(
            children: [
              Expanded(
                child: CancelButton(
                  text: l10n.cancel,
                  onTap: () => _finishEditing(save: false),
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: AuthButton(
                  text: l10n.save,
                  color: AppColors.passenger,
                  onTap: () => _finishEditing(save: true),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildOrderAction(
          id: 'edit-search-priorities',
          label: l10n.orderSearchPriorities,
          icon: Icons.format_list_numbered_rounded,
          onTap: _motion == _SelectionMotion.idle ? _startEditing : null,
        ),
        AnimatedReveal(
          visible:
              _value.hasCustomOrder &&
              _value.priority != TripSearchPriority.balanced,
          child: Column(
            children: [
              Container(
                height: AppDimens.dividerThickness,
                color: AppColors.borderMuted,
              ),
              _buildOrderAction(
                id: 'reset-search-priorities',
                label: l10n.resetSearchPriorities,
                icon: Icons.restart_alt_rounded,
                onTap: _motion == _SelectionMotion.idle && !_changingMode
                    ? _resetOrder
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderAction({
    required String id,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) => AnimatedTouchItem(
    key: ValueKey(id),
    onTap: widget.showSkeleton ? null : onTap,
    normalColor: Colors.transparent,
    pressedColor: Colors.transparent,
    pressedScale: 0.97,
    pressedOpacity: 0.6,
    borderRadius: BorderRadius.zero,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _placeholder(Icon(icon, color: Colors.white38, size: 22)),
            const SizedBox(width: AppDimens.gapSm),
            Flexible(
              child: _placeholder(
                Text(
                  label,
                  style: AppText.compactButton.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PriorityDragProxy extends StatefulWidget {
  final Animation<double> animation;
  final BorderRadius originShape;
  final double originOpacity;
  final ValueListenable<_PriorityDragLanding?> landing;
  final Widget child;
  final VoidCallback onRemoved;

  const _PriorityDragProxy({
    required this.animation,
    required this.originShape,
    required this.originOpacity,
    required this.landing,
    required this.child,
    required this.onRemoved,
  });

  @override
  State<_PriorityDragProxy> createState() => _PriorityDragProxyState();
}

class _PriorityDragProxyState extends State<_PriorityDragProxy> {
  late BorderRadius _currentShape = widget.originShape;
  late double _currentOpacity = widget.originOpacity;
  BorderRadius? _dropFromShape;
  double? _dropFromOpacity;
  double? _dropStartValue;

  @override
  void dispose() {
    widget.onRemoved();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.animation, widget.landing]),
    child: widget.child,
    builder: (context, child) {
      final progress = MediaQuery.disableAnimationsOf(context)
          ? 1.0
          : Curves.easeInOut.transform(widget.animation.value);
      const floatingShape = BorderRadius.all(Radius.circular(AppRadius.medium));
      final landing = widget.landing.value;
      if (landing == null) {
        _currentShape = BorderRadius.lerp(
          widget.originShape,
          floatingShape,
          progress,
        )!;
        _currentOpacity = lerpDouble(widget.originOpacity, 1, progress)!;
      } else {
        // A quick release can reverse the native lift before it completes.
        // Continue from the painted shape instead of jumping to a full lift.
        _dropFromShape ??= _currentShape;
        _dropFromOpacity ??= _currentOpacity;
        _dropStartValue ??= widget.animation.value;
        final dropProgress =
            MediaQuery.disableAnimationsOf(context) || _dropStartValue == 0
            ? 1.0
            : (1 - widget.animation.value / _dropStartValue!).clamp(0.0, 1.0);
        final dropT = Curves.easeInOut.transform(dropProgress);
        _currentShape = BorderRadius.lerp(
          _dropFromShape,
          landing.shape,
          dropT,
        )!;
        _currentOpacity = lerpDouble(
          _dropFromOpacity,
          landing.contentOpacity,
          dropT,
        )!;
      }
      return _PriorityDragAppearance(
        progress: progress,
        contentOpacity: _currentOpacity,
        child: Material(
          key: const ValueKey('priority-drag-surface'),
          animationDuration: Duration.zero,
          color: AppColors.floatingSurface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          elevation: 6 * progress,
          borderRadius: _currentShape,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
    },
  );
}

class _PriorityDragAppearance extends InheritedWidget {
  final double progress;
  final double contentOpacity;

  const _PriorityDragAppearance({
    required this.progress,
    required this.contentOpacity,
    required super.child,
  });

  static _PriorityDragAppearance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PriorityDragAppearance>();

  @override
  bool updateShouldNotify(_PriorityDragAppearance oldWidget) =>
      progress != oldWidget.progress ||
      contentOpacity != oldWidget.contentOpacity;
}

/// Paint the native reorder gaps below the rows. Reading the painted row
/// positions keeps the slot and its separators aligned with variable heights,
/// the native gap animation and the surrounding page's auto-scroll.
class _PriorityDragGapPainter extends CustomPainter {
  final GlobalKey listKey;
  final Map<TripSearchPriority, GlobalKey> entryKeys;
  final List<TripSearchPriority> order;
  final TripSearchPriority draggedPriority;

  _PriorityDragGapPainter({
    required this.listKey,
    required this.entryKeys,
    required this.order,
    required this.draggedPriority,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // The final reorder can rebuild the row in the list one frame before the
    // proxy's removal callback. Do not leave a slot tint under that settled row.
    final draggedContext = entryKeys[draggedPriority]?.currentContext;
    if (draggedContext
            ?.getInheritedWidgetOfExactType<_PriorityDragAppearance>() ==
        null) {
      return;
    }
    final listBox = listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return;
    final rows = <Rect>[];
    for (final priority in order) {
      if (priority == draggedPriority) continue;
      final rowBox = entryKeys[priority]?.currentContext?.findRenderObject();
      if (rowBox is! RenderBox || !rowBox.hasSize) continue;
      final top = listBox.globalToLocal(rowBox.localToGlobal(Offset.zero)).dy;
      rows.add(Rect.fromLTWH(0, top, size.width, rowBox.size.height));
    }
    rows.sort((a, b) => a.top.compareTo(b.top));
    var bottom = 0.0;
    for (final row in rows) {
      if (row.top - bottom > AppDimens.dividerThickness) {
        _paintGap(canvas, size.width, bottom, row.top);
      }
      bottom = math.max(bottom, row.bottom);
    }
  }

  void _paintGap(Canvas canvas, double width, double top, double bottom) {
    final rect = Rect.fromLTRB(
      AppDimens.gapSm,
      top + AppDimens.gapXs,
      width - AppDimens.gapSm,
      bottom - AppDimens.gapXs,
    );
    if (rect.height > 0 && rect.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.medium)),
        Paint()..color = AppColors.surfaceDisabled,
      );
    }
    canvas.drawLine(
      Offset(0, bottom - AppDimens.dividerThickness / 2),
      Offset(width, bottom - AppDimens.dividerThickness / 2),
      Paint()
        ..color = AppColors.borderMuted
        ..strokeWidth = AppDimens.dividerThickness,
    );
  }

  @override
  bool shouldRepaint(_PriorityDragGapPainter oldDelegate) =>
      oldDelegate.draggedPriority != draggedPriority ||
      oldDelegate.listKey != listKey ||
      oldDelegate.entryKeys != entryKeys ||
      !listEquals(oldDelegate.order, order);
}
