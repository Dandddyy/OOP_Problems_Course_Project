import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../address_widgets.dart';
import '../animated_field_icon.dart';
import '../animated_field_text_color.dart';
import '../animated_touch_templates.dart';
import '../animated_value_text.dart';
import '../shimmer_placeholder.dart';

class RideDateTimeField extends StatelessWidget {
  final String dateText;
  final String timeText;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;
  final bool isEnabled;
  final bool hasError;
  final bool showSkeleton;

  const RideDateTimeField({
    super.key,
    required this.dateText,
    required this.timeText,
    required this.onDateTap,
    required this.onTimeTap,
    this.isEnabled = true,
    this.hasError = false,
    this.showSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.danger.withValues(alpha: 0.8)
        : isEnabled
        ? Colors.transparent
        : AppColors.borderMuted;
    final iconColor = hasError
        ? AppColors.danger
        : isEnabled
        ? AppColors.iconSecondary
        : AppColors.textDisabled;
    final textStyle = AppText.compactButton.copyWith(
      fontWeight: FontWeight.bold,
      color: isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
    );

    Widget icon(IconData data) => showSkeleton
        ? const ShimmerBlock(width: 20, height: 20, borderRadius: 6)
        : AnimatedFieldIcon(
            color: iconColor,
            builder: (color) => Icon(data, color: color, size: 20),
          );

    Widget value(String text, {int? maxLines, TextOverflow? overflow}) =>
        showSkeleton
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: ShimmerPlaceholder(
              child: Text(
                text,
                style: textStyle,
                maxLines: maxLines,
                overflow: overflow,
              ),
            ),
          )
        : AnimatedFieldTextColor(
            color: textStyle.color!,
            builder: (textColor) => AnimatedValueText(
              text,
              style: textStyle.copyWith(color: textColor),
              overflow: overflow,
              maxLines: maxLines,
            ),
          );

    return Semantics(
      enabled: isEnabled && !showSkeleton,
      child: AnimatedContainer(
        duration: AppDurations.fieldState,
        foregroundDecoration: BoxDecoration(
          borderRadius: AppRadius.compactControlBr,
          border: Border.all(
            color: borderColor,
            width: AppDimens.focusBorderWidth,
          ),
        ),
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.surface : AppColors.surfaceDisabled,
          borderRadius: AppRadius.compactControlBr,
        ),
        child: Row(
          children: [
            Expanded(
              child: AnimatedTouchItem(
                onTap: isEnabled && !showSkeleton ? onDateTap : null,
                normalColor: Colors.transparent,
                pressedColor: Colors.transparent,
                pressedScale: 0.97,
                pressedOpacity: 0.6,
                borderRadius: AppRadius.compactControlBr,
                child: Container(
                  height: AppDimens.compactHeight,
                  padding: const EdgeInsets.only(
                    left: AppDimens.gapLg,
                    right: AppDimens.gapMd,
                  ),
                  child: Row(
                    children: [
                      icon(Icons.calendar_month_rounded),
                      const SizedBox(width: AppDimens.gapSm),
                      Expanded(
                        child: value(
                          dateText,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: AppDimens.dividerThickness,
              height: 24,
              color: AppColors.borderMuted,
            ),
            AnimatedTouchItem(
              onTap: isEnabled && !showSkeleton ? onTimeTap : null,
              normalColor: Colors.transparent,
              pressedColor: Colors.transparent,
              pressedScale: 0.95,
              pressedOpacity: 0.6,
              borderRadius: AppRadius.compactControlBr,
              child: Container(
                height: AppDimens.compactHeight,
                padding: const EdgeInsets.only(
                  left: AppDimens.gapMd,
                  right: AppDimens.gapLg,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon(Icons.access_time_rounded),
                    const SizedBox(width: AppDimens.gapSm),
                    value(timeText),
                    if (!isEnabled)
                      const Padding(
                        padding: EdgeInsets.only(left: AppDimens.gapSm),
                        child: Icon(
                          Icons.lock_outline,
                          color: AppColors.textDisabled,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
