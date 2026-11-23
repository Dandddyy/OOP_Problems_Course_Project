import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import '../l10n/app_localizations.dart';
import 'app_buttons.dart';
import 'app_scrollbar.dart';

class AppScreenMessage extends StatelessWidget {
  final double topInset;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onRetry;

  const AppScreenMessage({
    super.key,
    required this.topInset,
    required this.icon,
    required this.title,
    required this.description,
    this.onRetry,
  });

  factory AppScreenMessage.serviceBusy({
    required BuildContext context,
    required double topInset,
    required VoidCallback onRetry,
    String? title,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return AppScreenMessage(
      topInset: topInset,
      icon: Icons.cloud_off_rounded,
      title: title ?? l10n.serviceBusy,
      description: l10n.tryAgainLater,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
      AppDimens.pagePadding,
      topInset,
      AppDimens.pagePadding,
      AppScrollbar.screenBottomInsetOf(context, clearance: AppDimens.gapLg),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Align(
            alignment: const Alignment(0, -0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gap2xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.iconDisabled),
                  ),
                  const SizedBox(height: AppDimens.gapXl),
                  Text(
                    title,
                    style: AppText.screenTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  Text(
                    description,
                    style: AppText.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppDimens.gapXl),
                    AppPillButton(
                      onTap: onRetry,
                      hasShadow: false,
                      child: Text(
                        AppLocalizations.of(context)!.retry,
                        style: AppText.compactButton,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
