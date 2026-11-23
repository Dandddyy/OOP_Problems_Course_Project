import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'animated_touch_templates.dart';

class ProfileOptionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const ProfileOptionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gapSm,
      ),
      child: AnimatedTouchItem(
        onTap: onTap,
        normalColor: Colors.transparent,
        pressedColor: Colors.transparent,
        borderRadius: AppRadius.compactControlBr,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.gapLg,
            vertical: 22,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: effectiveColor.withValues(alpha: 0.7),
                size: 24,
              ),
              const SizedBox(width: AppDimens.gapLg),
              Expanded(
                child: Text(
                  title,
                  style: AppText.bodyStrong.copyWith(
                    color: effectiveColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: effectiveColor.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMenuDivider extends StatelessWidget {
  const ProfileMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: 64,
        right: AppDimens.authPagePadding,
      ),
      height: AppDimens.dividerThickness,
      color: AppColors.borderSoft,
    );
  }
}