import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/route_formatters.dart';
import '../address_widgets.dart';
import '../animated_value_text.dart';
import '../shimmer_placeholder.dart';
import 'route_template_action.dart';

class RoutePreviewFooter extends StatelessWidget {
  final int durationSeconds;
  final int distanceMeters;

  /// When omitted, shows the loading placeholders at the same size.
  final Widget? action;

  const RoutePreviewFooter({
    super.key,
    required this.durationSeconds,
    required this.distanceMeters,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final total = localizations.routePreviewTotal;
    final duration = RouteFormatters.formatDuration(context, durationSeconds);
    final distance = RouteFormatters.formatDistance(context, distanceMeters);
    const iconSize = 24.0;
    const leadingWidth = iconSize + AppDimens.gapSm;
    const routeIcon = Icon(
      Icons.route_rounded,
      size: iconSize,
      color: AppColors.iconMuted,
    );
    final durationWidth = _textWidth(context, duration, AppText.metricValue);
    final distanceWidth = _textWidth(context, distance, AppText.bodySecondary);
    final minimumWidth = leadingWidth + math.max(durationWidth, distanceWidth);
    final inlineWidth =
        leadingWidth +
        math.max(
          durationWidth + AppDimens.gapSm + distanceWidth,
          _textWidth(context, total, AppText.metricLabel),
        );
    final loading = action == null;
    Widget metric(String text, TextStyle style, {double? maxWidth}) {
      if (loading) return ShimmerPlaceholder(child: Text(text, style: style));
      // An outgoing value can be wider than its replacement in the inline row.
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: AnimatedValueText(
          text,
          style: style,
          maxLines: maxWidth == null ? null : 1,
          overflow: maxWidth == null ? null : TextOverflow.ellipsis,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: AppDimens.dividerThickness,
          thickness: AppDimens.dividerThickness,
          color: AppColors.borderMuted,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.gapLg,
            vertical: AppDimens.gapMd,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final rowWidth = width - AppDimens.gapMd;
              final actionSize = RouteTemplateAction.measure(context, width);
              final stacked = rowWidth < minimumWidth + actionSize.width;
              final halfWidth = rowWidth / 2;
              final equalWidths =
                  halfWidth >= math.max(inlineWidth, actionSize.width);
              final actionWidth = stacked
                  ? width
                  : equalWidths
                  ? halfWidth
                  : actionSize.width;
              final metricsWidth = stacked ? width : rowWidth - actionWidth;
              final inline = inlineWidth <= metricsWidth;
              final values = Flex(
                direction: inline ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: inline
                    ? CrossAxisAlignment.baseline
                    : CrossAxisAlignment.start,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  metric(
                    duration,
                    AppText.metricValue,
                    maxWidth: inline ? durationWidth : null,
                  ),
                  const SizedBox(
                    width: AppDimens.gapSm,
                    height: AppDimens.gapXs,
                  ),
                  metric(
                    distance,
                    AppText.bodySecondary,
                    maxWidth: inline ? distanceWidth : null,
                  ),
                ],
              );

              return Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: metricsWidth,
                    child: Semantics(
                      excludeSemantics: true,
                      label: loading
                          ? null
                          : '$total. ${localizations.travelTime} $duration, '
                                '${localizations.distance} $distance',
                      child: Row(
                        children: [
                          loading
                              ? const ShimmerPlaceholder(child: routeIcon)
                              : routeIcon,
                          const SizedBox(width: AppDimens.gapSm),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (inline) ...[
                                  metric(total, AppText.metricLabel),
                                  const SizedBox(height: AppDimens.gapXs),
                                ],
                                values,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox.square(dimension: AppDimens.gapMd),
                  SizedBox(
                    width: actionWidth,
                    height: actionSize.height,
                    child:
                        action ??
                        const ShimmerBlock(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: AppRadius.medium,
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return TextPainter.computeWidth(
      text: TextSpan(
        text: text,
        style: MediaQuery.boldTextOf(context)
            ? effectiveStyle.copyWith(fontWeight: FontWeight.bold)
            : effectiveStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    );
  }
}
