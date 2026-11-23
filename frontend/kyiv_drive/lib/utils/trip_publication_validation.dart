import 'package:flutter/material.dart';
import 'ukraine_time.dart';

enum TripScheduleIssue { nonexistentTime, departureInPast, unselectedWeekday }

int? parsePriceCents(String value) {
  if (!RegExp(r'^\d*(?:[.,]\d{0,2})?$').hasMatch(value) ||
      !RegExp(r'\d').hasMatch(value)) {
    return null;
  }
  final parts = value.replaceAll(',', '.').split('.');
  final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first);
  if (whole == null || whole > 1000) return null;
  final fraction = parts.length == 2 ? parts[1] : '';
  return whole * 100 + int.parse(fraction.padRight(2, '0'));
}

bool isValidTripPrice(String value, {required int upperBoundCents}) {
  final cents = parsePriceCents(value);
  return cents != null && cents > 0 && cents < upperBoundCents;
}

TripScheduleIssue? validateTripSchedule({
  required DateTime date,
  required TimeOfDay time,
  required bool isRegular,
  required List<bool> selectedDays,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final calendarDate = DateTime(date.year, date.month, date.day);
  if (calendarDate.isBefore(UkraineTime.today(current))) {
    return TripScheduleIssue.departureInPast;
  }
  final departure = UkraineTime.departureInstant(date, time.hour, time.minute);
  if (departure == null) return TripScheduleIssue.nonexistentTime;
  if (!departure.isAfter(current.toUtc())) {
    return TripScheduleIssue.departureInPast;
  }
  if (isRegular &&
      selectedDays.contains(true) &&
      (selectedDays.length != 7 || !selectedDays[calendarDate.weekday - 1])) {
    return TripScheduleIssue.unselectedWeekday;
  }
  return null;
}
