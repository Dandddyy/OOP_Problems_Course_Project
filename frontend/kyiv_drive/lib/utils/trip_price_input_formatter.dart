import 'package:flutter/services.dart';
import 'trip_publication_validation.dart';

class TripPriceInputFormatter extends TextInputFormatter {
  final int upperBoundCents;

  const TripPriceInputFormatter({required this.upperBoundCents});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final previousCents = parsePriceCents(oldValue.text);
    if (previousCents != null &&
        previousCents >= upperBoundCents &&
        text.length < oldValue.text.length &&
        RegExp(r'^\d*(?:[.,]\d{0,2})?$').hasMatch(text)) {
      // Allow backspacing a retained fixed price after switching to per-km pricing.
      return newValue;
    }
    final maximumWholeDigits = (upperBoundCents ~/ 100 - 1).toString().length;
    if (!RegExp(
      '^\\d{0,$maximumWholeDigits}(?:[.,]\\d{0,2})?\$',
    ).hasMatch(text)) {
      return oldValue;
    }
    if (text == '.' || text == ',') return newValue;
    final cents = parsePriceCents(text);
    if (cents == null || cents >= upperBoundCents) return oldValue;
    // Keep zero prefixes editable so 0.01 can be typed, but reject a complete zero amount.
    if (cents == 0 && RegExp(r'[.,]\d{2}$').hasMatch(text)) return oldValue;
    return newValue;
  }
}
