import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class RouteFormatters {
  static String formatDistance(BuildContext context, int totalMeters) {
    if (totalMeters < 1000) {
      return "$totalMeters ${AppLocalizations.of(context)!.metersShort}";
    } else {
      double km = totalMeters / 1000.0;
      String formattedKm = km.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
      if (formattedKm.endsWith('.')) {
        formattedKm = formattedKm.substring(0, formattedKm.length - 1);
      }
      return "$formattedKm ${AppLocalizations.of(context)!.kilometersShort}";
    }
  }

  static String formatDuration(BuildContext context, int totalSeconds) {
    final int totalMinutes = (totalSeconds / 60).round();
    if (totalMinutes < 60) {
      return "$totalMinutes ${AppLocalizations.of(context)!.minutesShort}";
    } else {
      final int hours = totalMinutes ~/ 60;
      final int minutes = totalMinutes % 60;
      if (minutes == 0) {
        return "$hours ${AppLocalizations.of(context)!.hoursShort}";
      }
      return "$hours ${AppLocalizations.of(context)!.hoursShort} $minutes ${AppLocalizations.of(context)!.minutesShort}";
    }
  }
}