import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'animated_touch_templates.dart';

class AppSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color iconColor;
  final bool hasShadow;
  final double pressedScale;
  final double highlightOpacity;

  const AppSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.backgroundColor = AppColors.floatingSurface,
    this.iconColor = AppColors.iconSecondary,
    this.hasShadow = true,
    this.pressedScale = 0.9,
    this.highlightOpacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    final pressedColor = Color.alphaBlend(
      Colors.white.withValues(alpha: highlightOpacity),
      backgroundColor,
    );

    return AnimatedTouchItem(
      onTap: onTap,
      normalColor: backgroundColor,
      pressedColor: pressedColor,
      pressedScale: pressedScale,
      borderRadius: AppRadius.floatingControlBr,
      boxShadow: hasShadow
          ? [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ]
          : null,
      child: SizedBox(
        width: AppDimens.squareButtonSize,
        height: AppDimens.squareButtonSize,
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class AppPillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final bool hasShadow;

  const AppPillButton({
    super.key,
    required this.child,
    required this.onTap,
    this.backgroundColor = AppColors.floatingSurface,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final pressedColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.04),
      backgroundColor,
    );

    return AnimatedTouchItem(
      onTap: onTap,
      normalColor: backgroundColor,
      pressedColor: pressedColor,
      pressedScale: 0.95,
      borderRadius: AppRadius.floatingControlBr,
      boxShadow: hasShadow
          ? [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ]
          : null,
      child: Container(
        height: AppDimens.compactHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class AppAvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onTap;

  const AppAvatarButton({
    super.key,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return AnimatedTouchItem(
      onTap: onTap,
      normalColor: AppColors.floatingSurface,
      pressedColor: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.05),
        AppColors.floatingSurface,
      ),
      pressedScale: 0.9,
      borderRadius: AppRadius.floatingControlBr,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      child: SizedBox(
        width: AppDimens.squareButtonSize,
        height: AppDimens.squareButtonSize,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: hasAvatar
              ? ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.soft - 3),
            child: Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person_rounded,
                  color: AppColors.iconSecondary,
                  size: 28,
                );
              },
            ),
          )
              : const Icon(
            Icons.person_rounded,
            color: AppColors.iconSecondary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
