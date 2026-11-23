import 'package:flutter/material.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/car_color.dart';
import '../animated_touch_templates.dart';
import '../animated_value_text.dart';

class CarColorSelector extends StatelessWidget {
  final CarColor selectedColor;
  final ValueChanged<CarColor> onColorSelected;

  const CarColorSelector({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
          child: Row(
            children: [
              const Icon(
                Icons.palette_outlined,
                color: Colors.white54,
                size: 20,
              ),
              const SizedBox(width: AppDimens.gapSm),
              Text(
                AppLocalizations.of(context)!.bodyColor,
                style: AppText.sectionTitle,
              ),
              const SizedBox(width: AppDimens.gapSm),
              Expanded(
                child: AnimatedValueText(
                  selectedColor.localizedName(context),
                  alignment: AlignmentDirectional.centerEnd,
                  textAlign: TextAlign.end,
                  style: AppText.bodySecondary.copyWith(
                    color: AppColors.driverAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),

        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.03, 0.97, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
              itemCount: CarColor.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppDimens.gapMd),
              itemBuilder: (context, index) {
                final colorEnum = CarColor.values[index];
                final isSelected = colorEnum == selectedColor;

                final checkIconColor =
                ThemeData.estimateBrightnessForColor(colorEnum.uiColor) == Brightness.light
                    ? Colors.black87
                    : Colors.white;

                return AnimatedTouchItem(
                  onTap: () => onColorSelected(colorEnum),
                  normalColor: Colors.transparent,
                  pressedColor: Colors.transparent,
                  pressedScale: 0.92,
                  borderRadius: AppRadius.fullBr,
                  child: SizedBox(
                    width: 46,
                    height: 56,
                    child: Center(
                      child: AnimatedScale(
                        scale: isSelected ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorEnum.uiColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: AppDimens.borderWidth,
                            ),
                          ),
                          child: AnimatedOpacity(
                            opacity: isSelected ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              Icons.check_rounded,
                              color: checkIconColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
