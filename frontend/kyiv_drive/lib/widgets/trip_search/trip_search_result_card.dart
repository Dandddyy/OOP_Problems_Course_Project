import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip_search_model.dart';
import '../../utils/pluralization_formatters.dart';
import '../../utils/route_formatters.dart';
import '../../utils/ukraine_time.dart';
import '../address_widgets.dart';
import '../animated_touch_templates.dart';
import '../dashed_route_line.dart';
import '../shimmer_placeholder.dart';

Color get _surface => Color.alphaBlend(AppColors.surface, AppColors.background);

final _priceStyle = AppText.metricValue.copyWith(fontSize: 24);

class TripSearchResultCard extends StatelessWidget {
  final TripSearchResultModel result;
  final VoidCallback? onTap;

  const TripSearchResultCard({super.key, required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final match = result.preferenceMatch;
    final isRegularRide = match.schedule != null;
    final scheduleLabel = switch (match.schedule) {
      TripSearchScheduleMatch.fits => l10n.tripSearchScheduleFits,
      TripSearchScheduleMatch.incomplete => l10n.tripSearchScheduleIncomplete,
      TripSearchScheduleMatch.startsLater => l10n.tripSearchScheduleStartsLater,
      null => null,
    };
    final first = result.occurrences.reduce(
      (a, b) => a.leaveAt.isBefore(b.leaveAt) ? a : b,
    );
    final distance =
        (result.walkingToPickup.distanceMeters +
                result.rideDistanceMeters +
                result.walkingFromDropoff.distanceMeters)
            .round();
    final score = NumberFormat('0.0', l10n.localeName).format(result.score);
    final durationLabel = RouteFormatters.formatDuration(
      context,
      first.arriveAt.difference(first.leaveAt).inSeconds,
    );
    final distanceLabel = RouteFormatters.formatDistance(context, distance);

    return Semantics(
      button: onTap != null,
      child: AnimatedTouchItem(
        onTap: onTap,
        normalColor: _surface,
        pressedColor: Color.alphaBlend(
          AppColors.surfacePressed,
          AppColors.background,
        ),
        pressedScale: 0.985,
        borderRadius: AppRadius.surfaceBr,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardSummary(
                score: _MatchScore(score: score),
                duration: Text(durationLabel, style: AppText.metricValue),
                distance: Text(distanceLabel, style: AppText.bodySecondary),
                clock: _StatusIcon(
                  icon: Icons.schedule_rounded,
                  label: match.timeFits
                      ? l10n.tripSearchTimeFits
                      : l10n.tripSearchTimeMismatch,
                  warning: !match.timeFits,
                ),
                calendar: scheduleLabel != null
                    ? _StatusIcon(
                        icon: Icons.calendar_month_rounded,
                        label: scheduleLabel,
                        warning: match.schedule != TripSearchScheduleMatch.fits,
                      )
                    : null,
                shield: _StatusIcon(
                  icon: Icons.shield_outlined,
                  color: AppColors.iconMuted,
                  label: l10n.tripSearchIdentityVerificationUnavailable,
                ),
              ),
              const _CardDivider(),
              _Journey(result: result, occurrence: first),
              const SizedBox(height: AppDimens.gapMd),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: AppColors.iconMuted,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRegularRide) ...[
                          Text(_weekdays(l10n), style: AppText.meta),
                          const SizedBox(height: AppDimens.gapXs),
                        ],
                        Text(
                          isRegularRide
                              ? l10n.tripSearchFirstTripOn(_date(first, l10n))
                              : _date(first, l10n),
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const _CardDivider(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(16) > 22;
                  final driver = Row(
                    children: [
                      _DriverAvatar(
                        name: result.driverName,
                        url: result.driverAvatarUrl,
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(child: _driverSummary(context, l10n)),
                    ],
                  );
                  final price = _price(l10n);
                  return largeText
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            driver,
                            const SizedBox(height: AppDimens.gapMd),
                            Align(
                              alignment: Alignment.centerRight,
                              child: price,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: driver),
                            const SizedBox(width: AppDimens.gapMd),
                            price,
                          ],
                        );
                },
              ),
              const SizedBox(height: AppDimens.gapMd),
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Expanded(
                    child: Text(
                      result.carLabel,
                      style: AppText.bodySecondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapMd),
                  Semantics(
                    excludeSemantics: true,
                    label: l10n.tripSearchAvailableSeats(
                      result.availableSeats,
                      result.totalSeats,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.airline_seat_recline_normal_rounded,
                          size: 18,
                          color: AppColors.iconMuted,
                        ),
                        const SizedBox(width: AppDimens.gapXs),
                        Text(
                          '${result.availableSeats}/${result.totalSeats}',
                          style: AppText.meta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverSummary(BuildContext context, AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        result.driverName,
        style: AppText.bodyStrong,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: AppDimens.gapXs),
      if (result.driverRatingCount == 0)
        Text(l10n.tripSearchNoReviews, style: AppText.caption)
      else
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimens.gapXs,
          runSpacing: AppDimens.gapXs,
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            Text(
              NumberFormat('0.00', l10n.localeName).format(result.driverRating),
              style: AppText.badge,
            ),
            Text(
              '· ${PluralizationService.getReviews(context, result.driverRatingCount)}',
              style: AppText.caption,
            ),
          ],
        ),
    ],
  );

  Widget _price(AppLocalizations l10n) => Text(
    '${NumberFormat('#,##0.##', l10n.localeName).format(result.priceAmount)} ₴',
    style: _priceStyle,
  );

  String _weekdays(AppLocalizations l10n) {
    final labels = [
      l10n.mon,
      l10n.tue,
      l10n.wed,
      l10n.thu,
      l10n.fri,
      l10n.sat,
      l10n.sun,
    ];
    return [
      for (final day in TripSearchWeekday.values)
        if (result.matchedWeekdays.contains(day)) labels[day.index],
    ].join(' · ');
  }

  String _date(TripSearchOccurrenceModel first, AppLocalizations l10n) =>
      DateFormat.yMMMMd(l10n.localeName).format(UkraineTime.now(first.leaveAt));
}

class _CardSummary extends StatelessWidget {
  final Widget score;
  final Widget duration;
  final Widget distance;
  final Widget clock;
  final Widget? calendar;
  final Widget shield;

  const _CardSummary({
    required this.score,
    required this.duration,
    required this.distance,
    required this.clock,
    this.calendar,
    required this.shield,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          duration,
          const SizedBox(width: AppDimens.gapSm),
          distance,
        ],
      ),
    );
    final statusIcons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        clock,
        if (calendar != null) ...[
          const SizedBox(width: AppDimens.gapSm),
          calendar!,
        ],
        const SizedBox(width: AppDimens.gapMd),
        shield,
      ],
    );

    if (MediaQuery.textScalerOf(context).scale(16) > 22) {
      return Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimens.gapLg,
              runSpacing: AppDimens.gapXs,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: score),
                metrics,
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          statusIcons,
        ],
      );
    }

    return _CenteredSummaryRow(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppDimens.gapLg),
          child: score,
        ),
        Flexible(child: metrics),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppDimens.gapMd),
          child: statusIcons,
        ),
      ],
    );
  }
}

class _CenteredSummaryRow extends Row {
  const _CenteredSummaryRow({required super.children})
    : super(mainAxisAlignment: MainAxisAlignment.spaceBetween);

  @override
  RenderFlex createRenderObject(BuildContext context) =>
      _RenderCenteredSummaryRow(Directionality.of(context));
}

class _RenderCenteredSummaryRow extends RenderFlex {
  _RenderCenteredSummaryRow(TextDirection textDirection)
    : super(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: textDirection,
      );

  @override
  void performLayout() {
    super.performLayout();

    final first = firstChild!;
    final middle = childAfter(first)!;
    final last = lastChild!;
    final rtl = textDirection == TextDirection.rtl;
    final left = rtl ? last : first;
    final right = rtl ? first : last;
    final leftData = left.parentData! as FlexParentData;
    final middleData = middle.parentData! as FlexParentData;
    final rightData = right.parentData! as FlexParentData;

    // The row measures the three groups and puts the side groups at its edges.
    final minX = leftData.offset.dx + left.size.width;
    final maxX = rightData.offset.dx - middle.size.width;
    final centeredX = (size.width - middle.size.width) / 2;
    middleData.offset = Offset(
      maxX <= minX ? minX : centeredX.clamp(minX, maxX),
      middleData.offset.dy,
    );
  }
}

const _statusIconSize = 20.0;

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;
  final Color color;

  const _StatusIcon({
    required this.icon,
    required this.label,
    this.warning = false,
    this.color = AppColors.passengerAccent,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: _statusIconSize,
          color: warning ? Colors.amber : color,
        ),
        if (warning)
          Positioned(
            right: -3,
            bottom: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                size: 11,
                color: Colors.amber,
              ),
            ),
          ),
      ],
    ),
  );
}

class _MatchScore extends StatelessWidget {
  final String score;

  const _MatchScore({required this.score});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.star_purple500_rounded,
        size: 22,
        color: AppColors.passengerAccent,
      ),
      const SizedBox(width: AppDimens.gapXs),
      Text.rich(
        TextSpan(
          text: score,
          style: AppText.metricValue.copyWith(fontSize: 26),
          children: const [TextSpan(text: '/10', style: AppText.hint)],
        ),
      ),
    ],
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimens.gapLg),
    child: Divider(height: 1, color: AppColors.borderMuted),
  );
}

class _DriverAvatar extends StatelessWidget {
  final String name;
  final String? url;

  const _DriverAvatar({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final fallback = ColoredBox(
      color: Color.alphaBlend(AppColors.surfaceStrong, _surface),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.gapXs),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              initials,
              maxLines: 1,
              style: AppText.bodyStrong.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox(
          width: 42,
          height: 42,
          child: url == null
              ? fallback
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _Journey extends StatelessWidget {
  final TripSearchResultModel result;
  final TripSearchOccurrenceModel occurrence;

  const _Journey({required this.result, required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final instants = [
      occurrence.leaveAt,
      occurrence.boardAt,
      occurrence.alightAt,
      occurrence.arriveAt,
    ];
    final times = instants.map(UkraineTime.now).toList();
    final durations = [
      result.walkingToPickup.durationSeconds.ceil(),
      result.rideDurationSeconds,
      result.walkingFromDropoff.durationSeconds.ceil(),
    ];
    final start = DateTime.utc(
      times.first.year,
      times.first.month,
      times.first.day,
    );

    Widget time(int index) {
      final value = times[index];
      final day = DateTime.utc(
        value.year,
        value.month,
        value.day,
      ).difference(start).inDays;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat.Hm(l10n.localeName).format(value),
            style: AppText.body.copyWith(
              color: index == 0 || index == 3
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          if (day != 0)
            Text(l10n.tripSearchDayOffset(day), style: AppText.caption),
        ],
      );
    }

    Widget leg(int index) => Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppDimens.gapXs,
      children: [
        Icon(
          index == 1
              ? Icons.directions_car_outlined
              : Icons.directions_walk_rounded,
          size: 18,
          color: index == 1 ? AppColors.iconPrimary : AppColors.iconMuted,
          semanticLabel: index == 1
              ? l10n.tripSearchByCar
              : l10n.priorityWalking,
        ),
        Text(
          RouteFormatters.formatDuration(context, durations[index]),
          style: AppText.bodySecondary.copyWith(
            color: index == 1 ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(15) >
            (constraints.maxWidth < 300 ? 19 : 24);
        if (largeText) {
          return Column(
            children: [
              for (var index = 0; index < 3; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.gapXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: leg(index)),
                      const SizedBox(width: AppDimens.gapSm),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppDimens.gapSm,
                          children: [time(index), time(index + 1)],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(child: leg(index)),
              ],
            ),
            const SizedBox(height: AppDimens.gapXs),
            const SizedBox(
              height: 16,
              width: double.infinity,
              child: CustomPaint(painter: _JourneyLinePainter()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (var index = 0; index < 4; index++) time(index)],
            ),
          ],
        );
      },
    );
  }
}

class _JourneyLinePainter extends CustomPainter {
  const _JourneyLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 3.0;
    final step = (size.width - radius * 2) / 3;
    final y = size.height / 2;
    for (final segment in [0, 2]) {
      paintDashedRouteLine(
        canvas,
        Offset(radius + step * segment, y),
        Offset(radius + step * (segment + 1), y),
      );
    }
    canvas.drawLine(
      Offset(radius + step, y),
      Offset(radius + step * 2, y),
      Paint()
        ..color = AppColors.passengerAccent
        ..strokeWidth = 3,
    );
    for (var index = 0; index < 4; index++) {
      canvas.drawCircle(
        Offset(radius + step * index, y),
        radius,
        Paint()..color = AppColors.textPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_JourneyLinePainter oldDelegate) => false;
}

class TripSearchResultCardSkeleton extends StatelessWidget {
  final bool isRegularRide;

  const TripSearchResultCardSkeleton({super.key, required this.isRegularRide});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget text(String value, TextStyle style) => ShimmerPlaceholder(
      child: Text(
        value,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    const status = ShimmerBlock(
      width: _statusIconSize,
      height: _statusIconSize,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: AppRadius.surfaceBr,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.gapLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardSummary(
              score: const ShimmerPlaceholder(child: _MatchScore(score: '8,7')),
              duration: text('45 ${l10n.minutesShort}', AppText.metricValue),
              distance: text(
                '12,8 ${l10n.kilometersShort}',
                AppText.bodySecondary,
              ),
              clock: status,
              calendar: isRegularRide ? status : null,
              shield: status,
            ),
            const _CardDivider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.gapXs,
                      ),
                      child: text(
                        '15 ${l10n.minutesShort}',
                        AppText.bodySecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.gapSm),
              child: ShimmerBlock(width: double.infinity, height: 3),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var index = 0; index < 4; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.gapXs,
                      ),
                      child: text('00:00', AppText.body),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            if (isRegularRide) ...[
              text('${l10n.mon} · ${l10n.wed} · ${l10n.fri}', AppText.meta),
              const SizedBox(height: AppDimens.gapXs),
            ],
            text('00 ${l10n.nov} 0000', AppText.caption),
            const _CardDivider(),
            Row(
              children: [
                const ShimmerBlock(width: 42, height: 42, borderRadius: 21),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text('Александр', AppText.bodyStrong),
                      const SizedBox(height: AppDimens.gapXs),
                      text('4,92 · 38', AppText.caption),
                    ],
                  ),
                ),
                text('75 ₴', _priceStyle),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            text('Toyota Corolla', AppText.bodySecondary),
          ],
        ),
      ),
    );
  }
}
