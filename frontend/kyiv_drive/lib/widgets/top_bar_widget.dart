import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'app_buttons.dart';
import 'animated_control_lock.dart';
import 'app_top_safe_area.dart';

class AppTopBar extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final bool isLeadingEnabled;
  final Color? buttonBackgroundColor;
  final bool buttonHasShadow;
  final double bottomPadding;
  final Widget? trailing;
  final bool fitTitleOnOneLine;

  const AppTopBar({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.onLeadingTap,
    this.isLeadingEnabled = true,
    this.buttonBackgroundColor,
    this.buttonHasShadow = false,
    this.bottomPadding = 0,
    this.trailing,
    this.fitTitleOnOneLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      style: AppText.screenTitle,
      maxLines: fitTitleOnOneLine ? 1 : null,
    );
    final leading = AnimatedControlLock(
      isEnabled: isLeadingEnabled,
      child: AppSquareButton(
        icon: leadingIcon,
        onTap: isLeadingEnabled ? onLeadingTap : null,
        backgroundColor: buttonBackgroundColor ?? AppColors.floatingSurface,
        hasShadow: buttonHasShadow,
      ),
    );
    final end = trailing ?? const SizedBox(width: AppDimens.squareButtonSize);
    return AppTopSafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimens.pagePadding,
          right: AppDimens.pagePadding,
          bottom: bottomPadding,
        ),
        child: fitTitleOnOneLine
            ? SizedBox(
                height: AppDimens.squareButtonSize,
                child: NavigationToolbar(
                  middleSpacing: 0,
                  leading: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppDimens.gapSm,
                    ),
                    child: leading,
                  ),
                  middle: FittedBox(fit: BoxFit.scaleDown, child: titleText),
                  trailing: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppDimens.gapSm,
                    ),
                    child: end,
                  ),
                ),
              )
            : Row(
                children: [
                  leading,
                  Expanded(child: titleText),
                  end,
                ],
              ),
      ),
    );
  }
}

typedef AppTopBarBodyBuilder =
    Widget Function(BuildContext context, double topInset);

class AppTopBarOverlayLayout extends StatelessWidget {
  static const double fadeExtent = AppDimens.gap2xl;
  static const double headerOpacity = 0.92;

  final String title;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final bool isLeadingEnabled;
  final Color? buttonBackgroundColor;
  final bool buttonHasShadow;
  final double contentOverlap;
  final Clip clipBehavior;
  final Widget? trailing;
  final bool fitTitleOnOneLine;
  final AppTopBarBodyBuilder bodyBuilder;

  const AppTopBarOverlayLayout({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.onLeadingTap,
    this.isLeadingEnabled = true,
    required this.bodyBuilder,
    this.buttonBackgroundColor,
    this.buttonHasShadow = false,
    this.contentOverlap = 0,
    this.clipBehavior = Clip.hardEdge,
    this.trailing,
    this.fitTitleOnOneLine = false,
  }) : assert(
         contentOverlap >= 0 && contentOverlap <= fadeExtent,
         'contentOverlap must stay inside the fade extent',
       );

  /// Reads the measured height from a bodyBuilder or body descendant context.
  /// Outside an overlay, falls back to the standard single-row header height.
  static double headerExtentOf(BuildContext context) {
    final metrics = context
        .dependOnInheritedWidgetOfExactType<_AppTopBarMetrics>();
    if (metrics != null) return metrics.headerExtent;
    return MediaQuery.paddingOf(context).top +
        AppDimens.topContentGap +
        AppDimens.squareButtonSize;
  }

  static double contentInsetOf(BuildContext context) {
    return headerExtentOf(context) + fadeExtent;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        clipBehavior: clipBehavior,
        children: [
          // Flex lays out the natural-height header before its expanded body.
          // Reversing the vertical direction paints the body first, allowing
          // its full-screen viewport to scroll behind the header as before.
          Column(
            verticalDirection: VerticalDirection.up,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bodyConstraints) {
                    final headerExtent =
                        constraints.maxHeight - bodyConstraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: -headerExtent,
                          height: constraints.maxHeight,
                          child: _AppTopBarMetrics(
                            headerExtent: headerExtent,
                            child: Builder(
                              builder: (context) => bodyBuilder(
                                context,
                                headerExtent + fadeExtent - contentOverlap,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: IgnorePointer(
                            child: SizedBox(
                              height: fadeExtent,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.background.withValues(
                                        alpha: headerOpacity,
                                      ),
                                      AppColors.background.withValues(
                                        alpha: 0.82,
                                      ),
                                      AppColors.background.withValues(alpha: 0),
                                    ],
                                    stops: const [0, 0.22, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ColoredBox(
                color: AppColors.background.withValues(alpha: headerOpacity),
                child: AppTopBar(
                  title: title,
                  leadingIcon: leadingIcon,
                  onLeadingTap: onLeadingTap,
                  isLeadingEnabled: isLeadingEnabled,
                  buttonBackgroundColor: buttonBackgroundColor,
                  buttonHasShadow: buttonHasShadow,
                  trailing: trailing,
                  fitTitleOnOneLine: fitTitleOnOneLine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppTopBarMetrics extends InheritedWidget {
  final double headerExtent;

  const _AppTopBarMetrics({required this.headerExtent, required super.child});

  @override
  bool updateShouldNotify(_AppTopBarMetrics oldWidget) =>
      headerExtent != oldWidget.headerExtent;
}
