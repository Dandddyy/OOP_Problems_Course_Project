import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth_widgets.dart';
import 'app_dialogs.dart';
import 'dialog_layout.dart';

extension AppTimePicker on AppDialogs {
  static Future<TimeOfDay?> showTimePicker(
      BuildContext context, {
        required TimeOfDay initialTime,
        Color? brandColor,
      }) {
    final primaryColor = brandColor ?? AppColors.passenger;
    TimeOfDay selectedTime = initialTime;

    return showGeneralDialog<TimeOfDay>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: 'TimePicker',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Dialog(
            backgroundColor: AppColors.background,
            insetPadding: safeDialogInsetPadding(context),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.surfaceBr,
            ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.selectTime,
                    textAlign: TextAlign.center,
                    style: AppText.modalTitle,
                  ),

                  const SizedBox(height: AppDimens.gapXl),

                  SizedBox(
                    height: 180,
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: true,
                        initialDateTime: DateTime(
                          2000, 1, 1,
                          initialTime.hour, initialTime.minute,
                        ),
                        onDateTimeChanged: (DateTime newDateTime) {
                          selectedTime = TimeOfDay(
                            hour: newDateTime.hour,
                            minute: newDateTime.minute,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimens.gapXl),

                  Row(
                    children: [
                      Expanded(
                        child: CancelButton(
                          text: AppLocalizations.of(context)!.cancel,
                          onTap: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: AuthButton(
                          text: AppLocalizations.of(context)!.done,
                          color: primaryColor,
                          onTap: () {
                            context.pop(selectedTime);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
