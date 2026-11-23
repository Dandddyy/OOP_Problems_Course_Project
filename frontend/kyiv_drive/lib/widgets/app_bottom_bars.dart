import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

class AppBottomActionBar extends StatelessWidget {
  static const double standardButtonBaseExtent =
      AppDimens.borderWidth +
      AppDimens.gapLg +
      AppDimens.buttonHeight +
      AppDimens.bottomContentGap;

  static double standardButtonExtentOf(
    BuildContext context, {
    bool maintainBottomViewPadding = true,
    double bottomInset = 0,
  }) {
    return standardButtonBaseExtent +
        bottomInset +
        (maintainBottomViewPadding
            ? MediaQuery.viewPaddingOf(context).bottom
            : MediaQuery.paddingOf(context).bottom);
  }

  final Widget child;
  final bool showTopBorder;
  final bool showShadow;
  final bool maintainBottomViewPadding;

  /// Extra space below the action, painted as part of the same surface.
  /// Keeps the surface's bottom edge below a rounded or translucent keyboard.
  final double bottomInset;

  const AppBottomActionBar({
    super.key,
    required this.child,
    this.showTopBorder = true,
    this.showShadow = true,
    this.maintainBottomViewPadding = true,
    this.bottomInset = 0,
  }) : assert(bottomInset >= 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: showTopBorder
            ? Border(
          top: BorderSide(
            color: AppColors.borderSubtle,
            width: AppDimens.borderWidth,
          ),
        )
            : null,
        boxShadow: showShadow
            ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ]
            : null,
      ),
      child: AppBottomSafeArea(
        maintainBottomViewPadding: maintainBottomViewPadding,
        contentGap: AppDimens.bottomContentGap + bottomInset,
        child: Padding(
          padding: AppInsets.bottomActionContent,
          child: child,
        )
      ),
    );
  }
}

class AppGradientBottomActionBar extends StatelessWidget {
  static const double fadeExtent = AppDimens.gap2xl;
  static const double buttonEdgeOpacity = 0.96;
  static const double buttonOcclusionExtent = AppDimens.gapLg;
  static const double _nearButtonOpacity = 0.92;
  static const double _nearButtonStop = 0.75;

  static const double baseExtent =
      fadeExtent +
          AppDimens.buttonHeight +
          AppDimens.bottomContentGap;

  static double extentOf(BuildContext context) {
    return baseExtent + MediaQuery.paddingOf(context).bottom;
  }

  final Widget child;
  final double middleOpacity;
  final double middleStop;

  const AppGradientBottomActionBar({
    super.key,
    required this.child,
    this.middleOpacity = 0.72,
    this.middleStop = 0.5,
  }) : assert(middleOpacity >= 0 && middleOpacity <= 1),
       assert(middleStop > 0 && middleStop < _nearButtonStop);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: SizedBox(
            key: const ValueKey('gradient_bottom_action_fade'),
            width: double.infinity,
            height: fadeExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background.withValues(alpha: middleOpacity),
                    AppColors.background.withValues(
                      alpha: _nearButtonOpacity,
                    ),
                    AppColors.background.withValues(
                      alpha: buttonEdgeOpacity,
                    ),
                  ],
                  stops: [
                    0,
                    middleStop,
                    _nearButtonStop,
                    1,
                  ],
                ),
              ),
            ),
          ),
        ),
        Stack(
          key: const ValueKey('gradient_bottom_action_surface'),
          children: [
            Positioned.fill(
              child: AbsorbPointer(
                child: Column(
                  children: [
                    SizedBox(
                      key: const ValueKey(
                        'gradient_bottom_action_occlusion',
                      ),
                      width: double.infinity,
                      height: buttonOcclusionExtent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background.withValues(
                                alpha: buttonEdgeOpacity,
                              ),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: ColoredBox(
                        color: AppColors.background,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomSafeArea(
              child: Padding(
                padding: AppInsets.gradientBottomActionContent,
                child: child,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AppBottomSheetSurface extends StatelessWidget {
  final Widget child;

  const AppBottomSheetSurface({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: AppColors.background,
          child: child,
        ),
      ),
    );
  }
}

class AppSheetHandle extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const AppSheetHandle({
    super.key,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppDimens.sheetHandleWidth,
        height: AppDimens.sheetHandleHeight,
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.sheetHandle,
          borderRadius: AppRadius.fullBr,
        ),
      ),
    );
  }
}

class AppBottomSafeArea extends StatelessWidget {
  final Widget child;
  final double contentGap;
  final bool maintainBottomViewPadding;

  const AppBottomSafeArea({
    super.key,
    required this.child,
    this.contentGap = AppDimens.bottomContentGap,
    this.maintainBottomViewPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      maintainBottomViewPadding:
      maintainBottomViewPadding,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: contentGap,
        ),
        child: child,
      ),
    );
  }
}

class AppBottomSafeFadeOverlay extends StatelessWidget {
  const AppBottomSafeFadeOverlay({
    super.key,
  });

  static double extentOf(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = extentOf(context);

    if (safeBottom <= 0) {
      return const SizedBox.shrink();
    }

    return AbsorbPointer(
      absorbing: true,
      child: SizedBox(
        width: double.infinity,
        height: safeBottom,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0),
                AppColors.background.withValues(alpha: 0.7),
                AppColors.background,
              ],
              stops: const [
                0,
                0.55,
                1,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
