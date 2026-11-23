import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shimmer_placeholder.dart';

class RideNegotiationToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showSkeleton;

  const RideNegotiationToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.showSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hintStyle = AppText.hint.copyWith(height: 1.35);
    final switchControl = CupertinoSwitch(
      value: value,
      activeTrackColor: AppColors.driver,
      inactiveTrackColor: Colors.white12,
      onChanged: showSkeleton ? null : onChanged,
    );

    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: showSkeleton || onChanged == null
            ? null
            : () => onChanged!(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppDimens.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppDimens.gapMd,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.formControlBr,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSkeleton)
                      ShimmerParagraph(
                        l10n.allowPriceNegotiation,
                        style: AppText.inputText,
                      )
                    else
                      Text(
                        l10n.allowPriceNegotiation,
                        style: AppText.inputText,
                      ),
                    const SizedBox(height: AppDimens.gapXs),
                    if (showSkeleton)
                      ShimmerParagraph(
                        l10n.priceNegotiationHint,
                        style: hintStyle,
                      )
                    else
                      Text(l10n.priceNegotiationHint, style: hintStyle),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              showSkeleton
                  ? ShimmerPlaceholder(
                      borderRadius: AppRadius.full,
                      horizontalInset: AppDimens.gapXs,
                      verticalInset: AppDimens.gapXs,
                      child: switchControl,
                    )
                  : switchControl,
            ],
          ),
        ),
      ),
    );
  }
}
