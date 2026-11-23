import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../animated_control_lock.dart';
import '../animated_touch_templates.dart';
import '../animated_value_switcher.dart';

class RouteTemplateAction extends StatefulWidget {
  static const _iconSize = 20.0;
  static final _labelStyle = AppText.compactButton.copyWith(
    fontWeight: FontWeight.bold,
  );
  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: AppDimens.gapSm,
    vertical: AppDimens.gapXs,
  );

  final bool refreshRequired;
  final bool isSaving;
  final bool isRefreshing;
  final bool isSaved;
  final bool isEnabled;
  final Color accentColor;
  final VoidCallback onSave;
  final VoidCallback onRefresh;

  const RouteTemplateAction({
    super.key,
    required this.refreshRequired,
    required this.isSaving,
    required this.isRefreshing,
    required this.isSaved,
    this.isEnabled = true,
    required this.accentColor,
    required this.onSave,
    required this.onRefresh,
  });

  /// Returns the width for any label on one line and the height at [maxWidth].
  static Size measure(BuildContext context, double maxWidth) {
    final localizations = AppLocalizations.of(context)!;
    final defaultStyle = DefaultTextStyle.of(context);
    final labelStyle = defaultStyle.style.merge(_labelStyle);
    final horizontalSpace =
        _contentPadding.horizontal + _iconSize + AppDimens.gapSm;
    final maxLabelWidth = math.max(0.0, maxWidth - horizontalSpace);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: defaultStyle.textHeightBehavior,
      locale: Localizations.localeOf(context),
    );
    var labelWidth = 0.0;
    var labelHeight = 0.0;
    // Measure every state so changing the label keeps the button in place.
    for (final label in [
      localizations.save,
      localizations.routeTemplateSaved,
      localizations.refreshRouteShort,
    ]) {
      painter.text = TextSpan(text: label, style: labelStyle);
      painter.layout(maxWidth: maxLabelWidth);
      labelWidth = math.max(labelWidth, painter.maxIntrinsicWidth);
      labelHeight = math.max(labelHeight, painter.height);
    }
    painter.dispose();
    return Size(
      (labelWidth + horizontalSpace).ceilToDouble(),
      math.max(AppDimens.compactHeight, labelHeight + _contentPadding.vertical),
    );
  }

  @override
  State<RouteTemplateAction> createState() => _RouteTemplateActionState();
}

class _RouteTemplateActionState extends State<RouteTemplateAction> {
  Timer? _confirmationTimer;

  @override
  void didUpdateWidget(covariant RouteTemplateAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSaved || widget.refreshRequired) {
      _confirmationTimer?.cancel();
      _confirmationTimer = null;
    } else if (oldWidget.isSaving &&
        !widget.isSaving &&
        !MediaQuery.disableAnimationsOf(context)) {
      _confirmationTimer = Timer(const Duration(seconds: 1), () {
        setState(() => _confirmationTimer = null);
      });
    }
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final refreshRequired = widget.refreshRequired;
    final busy = widget.isSaving || widget.isRefreshing;
    final saved = widget.isSaved && !refreshRequired;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final confirming = saved && _confirmationTimer != null && !reduceMotion;
    final enabled = widget.isEnabled && !busy && !saved;
    final dimmed =
        !widget.isEnabled ||
        (busy && !refreshRequired) ||
        (saved && !confirming);
    final onTap = enabled
        ? (refreshRequired ? widget.onRefresh : widget.onSave)
        : null;
    final label = refreshRequired
        ? localizations.refreshRouteShort
        : saved
        ? localizations.routeTemplateSaved
        : localizations.save;
    final duration = reduceMotion ? Duration.zero : AppDurations.buttonState;

    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: true,
      label: refreshRequired
          ? localizations.refreshRoute
          : saved
          ? localizations.routeSavedToTemplates
          : localizations.saveRoute,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: dimmed ? AnimatedControlLock.disabledOpacity : 1,
        duration: duration,
        curve: Curves.easeOut,
        child: ExcludeSemantics(
          child: TweenAnimationBuilder<Color?>(
            duration: duration,
            curve: Curves.easeInOut,
            tween: ColorTween(
              end: refreshRequired
                  ? widget.accentColor.withValues(alpha: busy ? 0.5 : 1)
                  : AppColors.surface,
            ),
            builder: (context, color, child) => IgnorePointer(
              ignoring: !enabled,
              child: AnimatedTouchItem(
                onTap: onTap,
                normalColor: color!,
                pressedColor: refreshRequired
                    ? Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.06),
                        color,
                      )
                    : AppColors.surfacePressed,
                pressedScale: 0.97,
                borderRadius: AppRadius.compactControlBr,
                child: child!,
              ),
            ),
            child: Padding(
              padding: RouteTemplateAction._contentPadding,
              child: AnimatedValueSwitcher(
                child: busy
                    ? const SizedBox(
                        key: ValueKey('route-action-busy'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2,
                        ),
                      )
                    : confirming
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('route-action-confirmed'),
                        color: Colors.white,
                        size: 28,
                      )
                    : Row(
                        key: ValueKey(label),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            refreshRequired
                                ? Icons.refresh_rounded
                                : saved
                                ? Icons.check_rounded
                                : Icons.bookmark_rounded,
                            color: refreshRequired || saved
                                ? Colors.white
                                : Colors.white70,
                            size: RouteTemplateAction._iconSize,
                          ),
                          const SizedBox(width: AppDimens.gapSm),
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: RouteTemplateAction._labelStyle,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
