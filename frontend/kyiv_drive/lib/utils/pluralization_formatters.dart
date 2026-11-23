import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class PluralizationService {
  /// Универсальный метод склонения для украинского языка.
  /// Работает на основе остатков от деления (modulo 10 и 100).
  static String getPlural({
    required int count,
    required String one, // 1 місце
    required String two, // 2, 3, 4 місця
    required String five, // 0, 5-9, 11-14 місць
  }) {
    final int rem10 = count % 10;
    final int rem100 = count % 100;

    if (rem10 == 1 && rem100 != 11) {
      return one;
    } else if (rem10 >= 2 && rem10 <= 4 && !(rem100 >= 12 && rem100 <= 14)) {
      return two;
    } else {
      return five;
    }
  }

  /// Удобная обертка для форматирования строки с количеством мест.
  /// Возвращает сразу готовую строку, например: "3 місця", "5 місць".
  static String getSeats(BuildContext context, int count) {
    final loc = AppLocalizations.of(context)!;

    final pluralWord = getPlural(
      count: count,
      one: loc.seatOne,
      two: loc.seatTwo,
      five: loc.seatFive,
    );

    return "$count $pluralWord";
  }

  static String getReviews(BuildContext context, int count) {
    final loc = AppLocalizations.of(context)!;

    final pluralWord = Localizations.localeOf(context).languageCode == 'en'
        ? (count == 1 ? loc.reviewOne : loc.reviewFive)
        : getPlural(
            count: count,
            one: loc.reviewOne,
            two: loc.reviewTwo,
            five: loc.reviewFive,
          );

    return '$count $pluralWord';
  }
}
