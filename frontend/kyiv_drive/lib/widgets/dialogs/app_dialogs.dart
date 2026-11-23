import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../animated_touch_templates.dart';
import '../auth_widgets.dart';
import 'dialog_layout.dart';

enum UnsavedChangesAction { save, discard, cancel }

enum PendingWaypointChangesAction { redraw, discard, cancel }

class AppDialogs {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    required String primaryButtonText,
    String? secondaryButtonText,
    IconData icon = Icons.info_rounded,
    bool isDestructive = false,
    bool barrierDismissible = false,
    Color? brandColor,
  }) {
    return _show<bool>(
      context,
      title: title,
      content: content,
      icon: icon,
      isDestructive: isDestructive,
      barrierDismissible: barrierDismissible,
      brandColor: brandColor ?? AppColors.passenger,
      actionsBuilder: (context, primaryColor) => Row(
        children: [
          Expanded(
            child: CancelButton(
              text: secondaryButtonText ?? AppLocalizations.of(context)!.cancel,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: AuthButton(
              text: primaryButtonText,
              color: primaryColor,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }

  static Future<UnsavedChangesAction?> showUnsavedChanges(
    BuildContext context, {
    Color brandColor = AppColors.driver,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return _showEditingChanges<UnsavedChangesAction>(
      context,
      title: l10n.unsavedChangesTitle,
      content: l10n.unsavedChangesMessage,
      primaryButtonText: l10n.save,
      primaryAction: UnsavedChangesAction.save,
      discardAction: UnsavedChangesAction.discard,
      cancelAction: UnsavedChangesAction.cancel,
      brandColor: brandColor,
    );
  }

  static Future<PendingWaypointChangesAction?> showPendingWaypointChanges(
    BuildContext context, {
    Color brandColor = AppColors.driver,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return _showEditingChanges<PendingWaypointChangesAction>(
      context,
      title: l10n.waypointChangesNotRedrawnTitle,
      content: l10n.waypointChangesNotRedrawnMessage,
      primaryButtonText: l10n.redraw,
      primaryAction: PendingWaypointChangesAction.redraw,
      discardAction: PendingWaypointChangesAction.discard,
      cancelAction: PendingWaypointChangesAction.cancel,
      brandColor: brandColor,
    );
  }

  static Future<T?> _showEditingChanges<T>(
    BuildContext context, {
    required String title,
    required String content,
    required String primaryButtonText,
    required T primaryAction,
    required T discardAction,
    required T cancelAction,
    required Color brandColor,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return _show<T>(
      context,
      title: title,
      content: content,
      barrierDismissible: true,
      brandColor: brandColor,
      actionsBuilder: (context, primaryColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthButton(
            text: primaryButtonText,
            color: primaryColor,
            onTap: () => Navigator.of(context).pop(primaryAction),
          ),
          const SizedBox(height: AppDimens.gapMd),
          AnimatedTouchItem(
            normalColor: AppColors.surface,
            pressedColor: AppColors.surfacePressed,
            pressedScale: 0.96,
            borderRadius: AppRadius.actionButtonBr,
            onTap: () => Navigator.of(context).pop(discardAction),
            child: SizedBox(
              height: AppDimens.buttonHeight,
              child: Center(child: Text(l10n.doNotSave, style: AppText.button)),
            ),
          ),
          const SizedBox(height: AppDimens.gapXs),
          CancelButton(
            text: l10n.cancel,
            onTap: () => Navigator.of(context).pop(cancelAction),
          ),
        ],
      ),
    );
  }

  static Future<T?> _show<T>(
    BuildContext context, {
    required String title,
    required String content,
    IconData? icon,
    required Color brandColor,
    required Widget Function(BuildContext, Color) actionsBuilder,
    bool isDestructive = false,
    bool barrierDismissible = false,
  }) {
    final activeBrandColor = brandColor;

    final primaryColor = isDestructive ? AppColors.danger : activeBrandColor;
    final iconBgColor = isDestructive
        ? AppColors.danger.withValues(alpha: 0.08)
        : activeBrandColor.withValues(alpha: 0.1);

    return showGeneralDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dialog',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Dialog(
            backgroundColor: AppColors.background,
            insetPadding: safeDialogInsetPadding(context),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.surfaceBr),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(AppDimens.gapXl),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppRadius.surfaceBr,
                border: Border.all(
                  color: AppColors.borderSoft,
                  width: AppDimens.borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: primaryColor, size: 32),
                      ),

                      const SizedBox(height: AppDimens.gapXl),
                    ],

                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.modalTitle,
                    ),

                    const SizedBox(height: AppDimens.gapMd),

                    Text(
                      content,
                      textAlign: TextAlign.center,
                      style: AppText.bodySecondary.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppDimens.gapXl),

                    actionsBuilder(context, primaryColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
