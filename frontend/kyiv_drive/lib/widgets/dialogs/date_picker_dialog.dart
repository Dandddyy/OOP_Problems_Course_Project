import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth_widgets.dart';
import '../custom_calendar.dart';
import 'app_dialogs.dart';
import 'dialog_layout.dart';

extension AppDatePickerExtension on AppDialogs {
  static Future<DateTime?> showDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    Color? brandColor,
    SelectableDayPredicate? selectableDayPredicate,
  }) {
    final primaryColor = brandColor ?? AppColors.passenger;
    DateTime selectedDate = initialDate;

    return showGeneralDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: 'DatePicker',
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
              padding: const EdgeInsets.only(
                top: AppDimens.gapXl,
                left: AppDimens.gapLg,
                right: AppDimens.gapLg,
                bottom: AppDimens.gapXl,
              ),
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
              child: StatefulBuilder(
                builder: (context, setDialogState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomCalendar(
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      primaryColor: primaryColor,
                      selectableDayPredicate: selectableDayPredicate,
                      onDateChanged: (DateTime date) {
                        setDialogState(() => selectedDate = date);
                      },
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
                            onTap:
                                DateUtils.dateOnly(
                                      selectedDate,
                                    ).isBefore(DateUtils.dateOnly(firstDate)) ||
                                    DateUtils.dateOnly(
                                      selectedDate,
                                    ).isAfter(DateUtils.dateOnly(lastDate)) ||
                                    !(selectableDayPredicate?.call(
                                          selectedDate,
                                        ) ??
                                        true)
                                ? null
                                : () {
                                    context.pop(selectedDate);
                                  },
                          ),
                        ),
                      ],
                    ),
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
