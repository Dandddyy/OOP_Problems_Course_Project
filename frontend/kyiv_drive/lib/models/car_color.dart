import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum CarColor {
  white,
  black,
  gray,
  silver,
  red,
  blue,
  green,
  brown,
  beige,
  yellow,
  orange,
  purple
}

extension CarColorExtension on CarColor {
  String get backendValue => name.toUpperCase();

  static CarColor fromBackend(String value) {
    return CarColor.values.firstWhere(
          (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => CarColor.white,
    );
  }

  Color get uiColor {
    switch (this) {
      case CarColor.white:
        return const Color(0xFFF8F9FA);
      case CarColor.black:
        return const Color(0xFF1C1C1E);
      case CarColor.gray:
        return Colors.grey.shade700;
      case CarColor.silver:
        return Colors.grey.shade400;
      case CarColor.red:
        return const Color(0xFFE53935);
      case CarColor.blue:
        return const Color(0xFF1E88E5);
      case CarColor.green:
        return const Color(0xFF43A047);
      case CarColor.brown:
        return const Color(0xFF795548);
      case CarColor.beige:
        return const Color(0xFFD7CCC8);
      case CarColor.yellow:
        return const Color(0xFFFFD54F);
      case CarColor.orange:
        return const Color(0xFFFB8C00);
      case CarColor.purple:
        return const Color(0xFF8E24AA);
    }
  }

  String localizedName(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (this) {
      case CarColor.white: return loc.colorWhite;
      case CarColor.black: return loc.colorBlack;
      case CarColor.gray: return loc.colorGray;
      case CarColor.silver: return loc.colorSilver;
      case CarColor.red: return loc.colorRed;
      case CarColor.blue: return loc.colorBlue;
      case CarColor.green: return loc.colorGreen;
      case CarColor.brown: return loc.colorBrown;
      case CarColor.beige: return loc.colorBeige;
      case CarColor.yellow: return loc.colorYellow;
      case CarColor.orange: return loc.colorOrange;
      case CarColor.purple: return loc.colorPurple;
    }
  }
}