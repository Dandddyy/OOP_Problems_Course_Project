import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'animated_touch_templates.dart';
import 'animated_value_switcher.dart';

class CustomOriginIcon extends StatelessWidget {
  final Color color;
  final double size;

  const CustomOriginIcon({
    super.key,
    this.color = Colors.cyan,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.radio_button_checked, color: color, size: size),
        Container(width: 2, height: 10, color: color),
      ],
    );
  }
}

class AddressRow extends StatelessWidget {
  static const iconSlotWidth = 24.0;

  final Widget iconWidget;
  final String text;
  final String? subtitle;
  final Color textColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;
  final bool isLoading;
  final ValueChanged<bool>? onPressedChanged;
  final Color? pressedBackgroundColor;

  const AddressRow({
    super.key,
    required this.iconWidget,
    required this.text,
    this.subtitle,
    required this.textColor,
    this.trailing,
    this.onTap,
    this.onTrailingTap,
    this.isLoading = false,
    this.onPressedChanged,
    this.pressedBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final addressSubtitle = subtitle ?? '';
    return SizedBox(
      height: AppDimens.rowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedListHighlight(
              onTap: onTap,
              onPressedChanged: onPressedChanged,
              pressedBackgroundColor: pressedBackgroundColor,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: AppDimens.gapLg,
                  right: trailing != null ? 72 : AppDimens.gapLg,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: iconSlotWidth,
                      child: Center(child: iconWidget),
                    ),
                    const SizedBox(width: AppDimens.gapLg),
                    Expanded(
                      child: AnimatedValueSwitcher.withSkeleton(
                        alignment: AlignmentDirectional.centerStart,
                        showSkeleton: isLoading,
                        skeleton: const Column(
                          key: ValueKey('address-loading'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBlock(width: 180, height: 16),
                            SizedBox(height: AppDimens.gapSm),
                            ShimmerBlock(width: 110, height: 12),
                          ],
                        ),
                        child: Column(
                          key: ValueKey((text, addressSubtitle)),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: AppText.addressTitle.copyWith(
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (addressSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                addressSubtitle,
                                style: AppText.addressSubtitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: AnimatedTouchItem(
                onTap: onTrailingTap ?? onTap,
                normalColor: Colors.transparent,
                pressedColor: Colors.transparent,
                pressedScale: 0.95,
                pressedOpacity: 0.7,
                child: Container(
                  width: 72,
                  height: AppDimens.rowHeight,
                  color: Colors.transparent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppDimens.gapLg),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: AppRadius.smallBr,
                    ),
                    child: Center(child: trailing),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BorderRadiusGeometry? borderRadiusGeometry;

  const ShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppShimmer.textBorderRadius,
    this.borderRadiusGeometry,
  });

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = _controller.value * 3 - 1;

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AppColors.shimmerBase,
                AppColors.shimmerHighlight,
                AppColors.shimmerBase,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromLTWH(
              bounds.width * dx,
              0,
              bounds.width,
              bounds.height,
            ));
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  widget.borderRadiusGeometry ??
                  BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
