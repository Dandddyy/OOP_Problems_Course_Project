import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../models/route_model.dart';
import '../address_widgets.dart';
import '../app_bottom_bars.dart';
import '../map/route_map_surface.dart';
import '../shimmer_placeholder.dart';
import 'ride_date_time_field.dart';
import 'ride_planning_widgets.dart';
import 'route_preview_addresses.dart';
import 'route_preview_footer.dart';

/// Keeps the preview mounted so the map can prepare before the content fades in.
class RoutePreviewContentTransition extends StatelessWidget {
  final bool isLoading;
  final Widget? skeleton;
  final Widget content;
  final Widget? error;
  final VoidCallback onSkeletonFadeEnd;
  final VoidCallback onRetryFadeEnd;

  const RoutePreviewContentTransition({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.content,
    this.error,
    required this.onSkeletonFadeEnd,
    required this.onRetryFadeEnd,
  });

  bool get showSkeleton => skeleton != null;

  @override
  Widget build(BuildContext context) {
    final skeletonLayer = Positioned.fill(
      key: const ValueKey('route-skeleton-layer'),
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: ExcludeFocus(
            child: AnimatedOpacity(
              key: const ValueKey('route-skeleton-fade'),
              duration: AppDurations.screenCrossFade,
              opacity: isLoading ? 1 : 0,
              onEnd: isLoading ? onRetryFadeEnd : onSkeletonFadeEnd,
              child: skeleton,
            ),
          ),
        ),
      ),
    );
    final contentLayer = ExcludeSemantics(
      key: const ValueKey('route-content-layer'),
      excluding: isLoading,
      child: IgnorePointer(
        ignoring: isLoading,
        child: ExcludeFocus(
          excluding: isLoading,
          child: AnimatedOpacity(
            key: const ValueKey('route-content-fade'),
            duration: AppDurations.screenCrossFade,
            opacity: isLoading ? 0 : 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: error == null ? 1 : 0, child: content),
                ?error,
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: isLoading
          ? [contentLayer, skeletonLayer]
          : [skeletonLayer, contentLayer],
    );
  }
}

class RoutePreviewBottomAction extends StatelessWidget {
  final bool showAction;
  final bool showSkeleton;
  final bool visible;
  final bool fadeInOnMount;
  final bool maintainBottomViewPadding;
  final double bottomInset;
  final Widget action;

  const RoutePreviewBottomAction({
    super.key,
    required this.showAction,
    required this.showSkeleton,
    required this.action,
    required this.visible,
    required this.fadeInOnMount,
    this.maintainBottomViewPadding = true,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: AppDurations.screenCrossFade,
    tween: Tween(begin: fadeInOnMount ? 0 : null, end: visible ? 1 : 0),
    builder: (context, opacity, child) => IgnorePointer(
      ignoring: !visible,
      child: Opacity(opacity: opacity, child: child),
    ),
    child: AppBottomActionBar(
      key: const ValueKey('route-bottom-action-background'),
      maintainBottomViewPadding: maintainBottomViewPadding,
      bottomInset: bottomInset,
      child: Stack(
        children: [
          if (showSkeleton)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: AppDurations.screenCrossFade,
                  opacity: showAction ? 0 : 1,
                  child: const ShimmerBlock(
                    key: ValueKey('route-bottom-action-skeleton'),
                    width: double.infinity,
                    height: AppDimens.buttonHeight,
                    borderRadius: AppRadius.control,
                  ),
                ),
              ),
            ),
          ExcludeSemantics(
            excluding: !showAction,
            child: IgnorePointer(
              ignoring: !showAction,
              child: ExcludeFocus(
                excluding: !showAction,
                child: AnimatedOpacity(
                  key: const ValueKey('route-bottom-action-transition'),
                  duration: AppDurations.screenCrossFade,
                  opacity: showAction ? 1 : 0,
                  child: action,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class RoutePreviewMapFrame extends StatelessWidget {
  static const editButtonInset = AppDimens.gapMd;
  static const editButtonSize = 42.0;

  final Widget child;

  const RoutePreviewMapFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    height: AppDimens.routePreviewMapHeight,
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: AppColors.borderSubtle),
      ),
    ),
    child: child,
  );
}

class RoutePreviewHint extends StatelessWidget {
  final String text;
  final bool showSkeleton;

  const RoutePreviewHint(this.text, {super.key, this.showSkeleton = false});

  @override
  Widget build(BuildContext context) {
    final style = AppText.bodySecondary.copyWith(
      color: Colors.white54,
      fontSize: 13,
      height: 1.3,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSkeleton)
          const ShimmerBlock(width: 16, height: 16, borderRadius: 8)
        else
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.iconMuted,
            size: 16,
          ),
        const SizedBox(width: AppDimens.gapSm),
        Expanded(
          child: showSkeleton
              ? ShimmerParagraph(text, style: style)
              : Text(text, style: style),
        ),
      ],
    );
  }
}

class RoutePreviewSkeleton extends StatelessWidget {
  final AddressModel origin;
  final AddressModel destination;
  final bool isDriver;
  final bool isRegularRide;
  final bool isStopsView;
  final RouteModel? route;
  final List<String> weekDays;
  final List<bool> selectedDays;
  final String dateText;
  final String timeText;
  final Widget details;

  const RoutePreviewSkeleton({
    super.key,
    required this.origin,
    required this.destination,
    required this.isDriver,
    required this.isRegularRide,
    required this.route,
    required this.weekDays,
    required this.selectedDays,
    required this.dateText,
    required this.timeText,
    required this.details,
    this.isStopsView = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = isDriver ? AppColors.driver : AppColors.passenger;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.surfaceBr,
            border: Border.all(
              color: AppColors.borderSubtle,
              width: AppDimens.borderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.surfaceBr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDriver) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: RoutePreviewHint(
                      l10n.makeSureTheRouteSuitsYou,
                      showSkeleton: true,
                    ),
                  ),
                  TabSwitcher(
                    key: const ValueKey('route-view-switch-skeleton'),
                    isRightTabSelected: isStopsView,
                    leftTabTitle: l10n.route,
                    rightTabTitle: l10n.stops,
                    backgroundColor: Colors.white.withValues(alpha: 0.03),
                    activeColor: Colors.white.withValues(alpha: 0.08),
                    outerBorderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.medium),
                    ),
                    onLeftTap: () {},
                    onRightTap: () {},
                    showSkeleton: true,
                  ),
                ],
                RoutePreviewMapFrame(
                  child: Stack(
                    children: [
                      const Positioned.fill(child: RouteMapPlaceholder()),
                      if (isDriver)
                        const Positioned(
                          top: RoutePreviewMapFrame.editButtonInset,
                          right: RoutePreviewMapFrame.editButtonInset,
                          child: ShimmerBlock(
                            key: ValueKey('route-editor-skeleton'),
                            width: RoutePreviewMapFrame.editButtonSize,
                            height: RoutePreviewMapFrame.editButtonSize,
                            borderRadius: AppRadius.small,
                          ),
                        ),
                    ],
                  ),
                ),
                RoutePreviewAddresses(
                  origin: _address(
                    context,
                    origin,
                    RoutePreviewAddresses.originIconSize,
                  ),
                  destination: _address(
                    context,
                    destination,
                    RoutePreviewAddresses.destinationIconSize,
                  ),
                ),
                RoutePreviewFooter(
                  durationSeconds: route?.durationSeconds ?? 1800,
                  distanceMeters: route?.distanceMeters ?? 12000,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.gap2xl),
        SectionDivider(
          title: isDriver ? l10n.scheduleRide : l10n.rideDetails,
          showSkeleton: true,
        ),
        const SizedBox(height: AppDimens.gapLg),
        SizedBox(
          width: double.infinity,
          child: TabSwitcher(
            isRightTabSelected: isRegularRide,
            leftTabTitle: l10n.notRegular,
            rightTabTitle: l10n.regular,
            activeColor: color,
            onLeftTap: () {},
            onRightTap: () {},
            showSkeleton: true,
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),
        if (isRegularRide) ...[
          SkeletonFieldHint(text: l10n.selectDaysOfWeek, rightPadding: 0),
          WeekDaysSelector(
            weekDays: weekDays,
            selectedDays: selectedDays,
            activeColor: color,
            onDayTapped: (_) {},
            showSkeleton: true,
          ),
          const SizedBox(height: AppDimens.gapLg),
        ],
        SkeletonFieldHint(
          text: isRegularRide
              ? l10n.selectFirstRideDateAndTime
              : l10n.selectDateAndTime,
          rightPadding: 0,
        ),
        RideDateTimeField(
          dateText: dateText,
          timeText: timeText,
          onDateTap: () {},
          onTimeTap: () {},
          showSkeleton: true,
        ),
        details,
      ],
    );
    return ColoredBox(color: AppColors.background, child: content);
  }

  Widget _address(BuildContext context, AddressModel address, double iconSize) {
    return SizedBox(
      height: AppDimens.rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
        child: Row(
          children: [
            SizedBox(
              width: AddressRow.iconSlotWidth,
              child: Center(
                child: ShimmerBlock(
                  width: iconSize,
                  height: iconSize,
                  borderRadius: iconSize / 2,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.gapLg),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder(
                    child: Text(
                      address.shortAddress ??
                          AppLocalizations.of(context)!.unknownLocation,
                      style: AppText.addressTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (address.subtitle?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    ShimmerPlaceholder(
                      child: Text(
                        address.subtitle!,
                        style: AppText.addressSubtitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonFieldHint extends StatelessWidget {
  final String text;
  final double rightPadding;
  final Widget? trailing;

  const SkeletonFieldHint({
    super.key,
    required this.text,
    this.rightPadding = AppDimens.gapSm,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hint = ShimmerParagraph(text, style: AppText.hint);
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.gapSm,
        right: rightPadding,
        bottom: AppDimens.gapSm,
      ),
      child: trailing == null
          ? hint
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [hint, trailing!],
            ),
    );
  }
}
