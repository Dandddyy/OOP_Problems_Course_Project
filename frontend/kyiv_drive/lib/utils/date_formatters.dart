import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class DateFormatters {
  static String getDisplayDate(BuildContext context, DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    final List<String> monthNames = [
      '',
      AppLocalizations.of(context)!.jan,
      AppLocalizations.of(context)!.feb,
      AppLocalizations.of(context)!.mar,
      AppLocalizations.of(context)!.apr,
      AppLocalizations.of(context)!.may,
      AppLocalizations.of(context)!.jun,
      AppLocalizations.of(context)!.jul,
      AppLocalizations.of(context)!.aug,
      AppLocalizations.of(context)!.sep,
      AppLocalizations.of(context)!.oct,
      AppLocalizations.of(context)!.nov,
      AppLocalizations.of(context)!.dec
    ];

    final yearShort = AppLocalizations.of(context)!.yearShort;
    final String dateStr = "${date.day} ${monthNames[date.month]} ${date.year} $yearShort";

    if (targetDate == today) {
      return "${AppLocalizations.of(context)!.today}, $dateStr";
    } else if (targetDate == tomorrow) {
      return "${AppLocalizations.of(context)!.tomorrow}, $dateStr";
    } else {
      return dateStr;
    }
  }
}