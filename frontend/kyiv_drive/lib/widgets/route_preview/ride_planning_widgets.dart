import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../animated_touch_templates.dart';
import '../shimmer_placeholder.dart';

class SectionDivider extends StatelessWidget {
  final String title;
  final bool showSkeleton;

  const SectionDivider({
    super.key,
    required this.title,
    this.showSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: AppDimens.dividerThickness,
            color: AppColors.borderMuted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
          child: showSkeleton
              ? ShimmerPlaceholder(
                  child: Text(title, style: AppText.sectionDivider),
                )
              : Text(title, style: AppText.sectionDivider),
        ),
        Expanded(
          child: Container(
            height: AppDimens.dividerThickness,
            color: AppColors.borderMuted,
          ),
        ),
      ],
    );
  }
}

class TabSwitcher extends StatelessWidget {
  final bool isRightTabSelected;
  final String leftTabTitle;
  final String rightTabTitle;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;
  final Color activeColor;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final Color? backgroundColor;
  final BorderRadius? outerBorderRadius;
  final BorderRadius? innerBorderRadius;
  final EdgeInsetsGeometry? padding;
  final double height;
  final bool showSkeleton;

  const TabSwitcher({
    super.key,
    required this.isRightTabSelected,
    required this.leftTabTitle,
    required this.rightTabTitle,
    required this.onLeftTap,
    required this.onRightTap,
    required this.activeColor,
    this.activeTextColor = Colors.white,
    this.inactiveTextColor = Colors.white38,
    this.backgroundColor,
    this.outerBorderRadius,
    this.innerBorderRadius,
    this.padding,
    this.height = AppDimens.compactHeight,
    this.showSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOuterRadius = outerBorderRadius ?? AppRadius.mediumBr;
    final effectiveInnerRadius = innerBorderRadius ?? AppRadius.smallBr;

    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(AppDimens.gapXs),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: effectiveOuterRadius,
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            alignment: isRightTabSelected
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: showSkeleton ? AppColors.surfaceStrong : activeColor,
                  borderRadius: effectiveInnerRadius,
                  boxShadow: [
                    if (!showSkeleton && backgroundColor != Colors.transparent)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _buildTabButtonText(
                title: leftTabTitle,
                isSelected: !isRightTabSelected,
                onTap: onLeftTap,
                activeColor: activeTextColor,
                inactiveColor: inactiveTextColor,
                radius: effectiveInnerRadius,
              ),
              _buildTabButtonText(
                title: rightTabTitle,
                isSelected: isRightTabSelected,
                onTap: onRightTap,
                activeColor: activeTextColor,
                inactiveColor: inactiveTextColor,
                radius: effectiveInnerRadius,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtonText({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required Color inactiveColor,
    required BorderRadius radius,
  }) {
    if (showSkeleton) {
      return Expanded(
        child: Center(
          child: ShimmerPlaceholder(
            child: Text(title, style: AppText.compactButton),
          ),
        ),
      );
    }
    final targetColor = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: AnimatedTouchItem(
        onTap: onTap,
        normalColor: Colors.transparent,
        pressedColor: Colors.transparent,
        pressedScale: 0.93,
        borderRadius: radius,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            style: AppText.compactButton.copyWith(color: targetColor),
            child: Text(title),
          ),
        ),
      ),
    );
  }
}

class WeekDaysSelector extends StatelessWidget {
  final List<String> weekDays;
  final List<bool> selectedDays;
  final Function(int) onDayTapped;
  final Color activeColor;
  final bool hasError;
  final bool showSkeleton;

  const WeekDaysSelector({
    super.key,
    required this.weekDays,
    required this.selectedDays,
    required this.onDayTapped,
    required this.activeColor,
    this.hasError = false,
    this.showSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final rowChildren = <Widget>[];

    for (int i = 0; i < weekDays.length; i++) {
      rowChildren.add(
        Expanded(
          child: AnimatedTouchItem(
            onTap: showSkeleton ? null : () => onDayTapped(i),
            normalColor: Colors.transparent,
            pressedColor: Colors.transparent,
            pressedScale: 0.88,
            borderRadius: AppRadius.smallBr,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                width: 44,
                height: 36,
                decoration: BoxDecoration(
                  color: selectedDays[i]
                      ? (showSkeleton ? AppColors.surfaceStrong : activeColor)
                      : activeColor.withValues(alpha: 0.0),
                  borderRadius: AppRadius.smallBr,
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOutCubic,
                    style: AppText.compactButton.copyWith(
                      color: selectedDays[i]
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 14,
                    ),
                    child: showSkeleton
                        ? ShimmerPlaceholder(child: Text(weekDays[i]))
                        : Text(weekDays[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (i < weekDays.length - 1) {
        rowChildren.add(
          Container(
            width: AppDimens.dividerThickness,
            height: 20,
            color: AppColors.borderMuted,
          ),
        );
      }
    }

    return AnimatedContainer(
      duration: AppDurations.fieldState,
      height: AppDimens.compactHeight,
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadius.mediumBr,
        border: Border.all(
          color: hasError
              ? AppColors.danger.withValues(alpha: 0.8)
              : Colors.transparent,
          width: AppDimens.focusBorderWidth,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: AppDimens.gapXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumBr,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rowChildren,
      ),
    );
  }
}
