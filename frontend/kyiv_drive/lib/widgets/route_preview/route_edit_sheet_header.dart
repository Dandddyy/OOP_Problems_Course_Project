import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../animated_value_text.dart';
import '../app_bottom_bars.dart';

class RouteEditSheetHeader extends StatelessWidget {
  static const double extent = 120;

  static const double topHandleSpacing = AppDimens.gapMd;
  static const double contentSpacing = AppDimens.gapLg;

  final String title;
  final String counterText;
  final String description;

  const RouteEditSheetHeader({
    super.key,
    required this.title,
    required this.counterText,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: extent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: topHandleSpacing),

          const AppSheetHandle(),

          const SizedBox(height: contentSpacing),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppText.screenTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.gapMd),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.gapMd,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.smallBr,
                  ),
                  child: AnimatedValueText(
                    counterText,
                    alignment: Alignment.center,
                    style: AppText.badge,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  description,
                  style: AppText.hint.copyWith(height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
