enum TripSearchPriority {
  departure('DEPARTURE'),
  arrival('ARRIVAL'),
  walking('WALKING'),
  price('PRICE'),
  weekdays('WEEKDAYS'),
  balanced('BALANCED');

  final String apiValue;

  const TripSearchPriority(this.apiValue);
}

/// Local search preferences, balanced by default until a priority is selected.
class TripSearchPreferences {
  static const defaultOrder = [
    TripSearchPriority.departure,
    TripSearchPriority.arrival,
    TripSearchPriority.walking,
    TripSearchPriority.price,
    TripSearchPriority.weekdays,
  ];

  final TripSearchPriority priority;
  final List<TripSearchPriority> order;
  final bool hasCustomOrder;
  final int departureMinutes;

  /// Manually selected clock time, independent of the departure's calendar day.
  /// Null means arrival follows the route's calculated duration.
  final int? manualArrivalMinutes;

  TripSearchPreferences({
    required this.departureMinutes,
    this.priority = TripSearchPriority.balanced,
    List<TripSearchPriority> order = defaultOrder,
    this.hasCustomOrder = false,
    int? manualArrivalMinutes,
  }) : manualArrivalMinutes = manualArrivalMinutes == null
           ? null
           : manualArrivalMinutes % 1440,
       order = List.unmodifiable(order) {
    if (departureMinutes < 0 || departureMinutes >= 1440) {
      throw ArgumentError.value(departureMinutes, 'departureMinutes');
    }
    if (order.length != defaultOrder.length ||
        order.toSet().length != defaultOrder.length ||
        !order.every(defaultOrder.contains)) {
      throw ArgumentError.value(order, 'order');
    }
  }

  static int parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String formatTime(int minutes) =>
      '${((minutes % 1440) ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  String get departureTime => formatTime(departureMinutes);

  int arrivalMinutes(int durationSeconds) {
    final manualTime = manualArrivalMinutes;
    if (manualTime == null) {
      return departureMinutes + (durationSeconds / 60).ceil();
    }
    return manualTime + (manualTime < departureMinutes ? 1440 : 0);
  }

  List<TripSearchPriority> visibleOrder(bool isRegular) => [
    for (final item in order)
      if (isRegular || item != TripSearchPriority.weekdays) item,
  ];

  TripSearchPreferences select(TripSearchPriority value) => _copy(
    priority: value,
    order: hasCustomOrder && value != TripSearchPriority.balanced
        ? [value, ...order.where((item) => item != value)]
        : order,
  );

  TripSearchPreferences withOrder(List<TripSearchPriority> values) => _copy(
    priority: values.first,
    order: [...values, ...order.where((item) => !values.contains(item))],
    hasCustomOrder: true,
  );

  TripSearchPreferences withoutCustomOrder() =>
      _copy(order: defaultOrder, hasCustomOrder: false);

  TripSearchPreferences withDeparture(int minutes) =>
      _copy(departureMinutes: minutes);

  TripSearchPreferences withArrival(int minuteOfDay) =>
      _copy(manualArrivalMinutes: minuteOfDay);

  TripSearchPreferences withAutomaticArrival() => _copy(clearArrival: true);

  TripSearchPreferences forRegularRide(bool isRegular) => _copy(
    priority: !isRegular && priority == TripSearchPriority.weekdays
        ? TripSearchPriority.balanced
        : priority,
  );

  TripSearchPreferences _copy({
    TripSearchPriority? priority,
    List<TripSearchPriority>? order,
    bool? hasCustomOrder,
    int? departureMinutes,
    int? manualArrivalMinutes,
    bool clearArrival = false,
  }) => TripSearchPreferences(
    departureMinutes: departureMinutes ?? this.departureMinutes,
    priority: priority ?? this.priority,
    order: order ?? this.order,
    hasCustomOrder: hasCustomOrder ?? this.hasCustomOrder,
    manualArrivalMinutes: clearArrival
        ? null
        : manualArrivalMinutes ?? this.manualArrivalMinutes,
  );
}
