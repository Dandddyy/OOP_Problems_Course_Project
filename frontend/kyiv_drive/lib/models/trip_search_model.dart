import 'trip_model.dart' show TripPricingType, TripScheduleType;
import 'trip_search_preferences.dart';

const _unchangedSearchValue = Object();

enum TripSearchSort {
  score('SCORE'),
  price('PRICE'),
  walking('WALKING'),
  departure('DEPARTURE'),
  arrival('ARRIVAL');

  final String apiValue;

  const TripSearchSort(this.apiValue);
}

/// ISO order, matching the planning widget: Monday is index zero.
enum TripSearchWeekday {
  monday('MONDAY'),
  tuesday('TUESDAY'),
  wednesday('WEDNESDAY'),
  thursday('THURSDAY'),
  friday('FRIDAY'),
  saturday('SATURDAY'),
  sunday('SUNDAY');

  final String apiValue;

  const TripSearchWeekday(this.apiValue);
}

enum TripSearchScheduleMatch {
  fits('FITS'),
  incomplete('INCOMPLETE'),
  startsLater('STARTS_LATER');

  final String apiValue;

  const TripSearchScheduleMatch(this.apiValue);
}

class TripSearchFiltersRequestModel {
  final int? maxWalkMeters;
  final int? maxWalkSeconds;
  final int? maxTotalWalkSeconds;
  final int? timeDeviationMinutes;

  const TripSearchFiltersRequestModel({
    this.maxWalkMeters,
    this.maxWalkSeconds,
    this.maxTotalWalkSeconds,
    this.timeDeviationMinutes,
  });

  Map<String, dynamic> toJson() => {
    if (maxWalkMeters != null) 'maxWalkMeters': maxWalkMeters,
    if (maxWalkSeconds != null) 'maxWalkSeconds': maxWalkSeconds,
    if (maxTotalWalkSeconds != null) 'maxTotalWalkSeconds': maxTotalWalkSeconds,
    if (timeDeviationMinutes != null)
      'timeDeviationMinutes': timeDeviationMinutes,
  };
}

class TripSearchPreferencesRequestModel {
  final TripSearchPriority priority;
  final List<TripSearchPriority> order;
  final bool hasCustomOrder;
  final TripSearchSort sort;
  final TripSearchFiltersRequestModel filters;
  final bool replace;
  final String? anchorTripId;
  final int? restoreResultCount;

  TripSearchPreferencesRequestModel({
    this.priority = TripSearchPriority.balanced,
    List<TripSearchPriority> order = TripSearchPreferences.defaultOrder,
    this.hasCustomOrder = false,
    this.sort = TripSearchSort.score,
    this.filters = const TripSearchFiltersRequestModel(),
    this.replace = false,
    this.anchorTripId,
    this.restoreResultCount,
  }) : order = List.unmodifiable(order);

  factory TripSearchPreferencesRequestModel.fromPreferences(
    TripSearchPreferences preferences, {
    required bool isRegularRide,
    TripSearchSort sort = TripSearchSort.score,
  }) {
    final visible = preferences.forRegularRide(isRegularRide);
    return TripSearchPreferencesRequestModel(
      priority: visible.priority,
      order: visible.visibleOrder(isRegularRide),
      hasCustomOrder: visible.hasCustomOrder,
      sort: sort,
    );
  }

  TripSearchPreferencesRequestModel forApplication({
    String? anchorTripId,
    int? restoreResultCount,
  }) => TripSearchPreferencesRequestModel(
    priority: priority,
    order: order,
    hasCustomOrder: hasCustomOrder,
    sort: sort,
    filters: filters,
    replace: true,
    anchorTripId: anchorTripId,
    restoreResultCount: restoreResultCount,
  );

  Map<String, dynamic> toJson({bool forSearch = false}) => {
    'priority': priority.apiValue,
    'order': order.map((item) => item.apiValue).toList(),
    'hasCustomOrder': hasCustomOrder,
    'sort': sort.apiValue,
    if (filters.toJson().isNotEmpty) 'filters': filters.toJson(),
    if (!forSearch && replace) 'replace': true,
    if (!forSearch && anchorTripId != null) 'anchorTripId': anchorTripId,
    if (!forSearch && restoreResultCount != null)
      'restoreResultCount': restoreResultCount,
  };
}

class TripSearchRequestModel {
  final double originLat;
  final double originLon;
  final double destinationLat;
  final double destinationLon;
  final TripScheduleType scheduleType;

  /// Calendar date in Ukraine, without conversion to the device's time zone.
  final DateTime date;
  final String departureLocalTime;
  final String arrivalLocalTime;
  final int? arrivalDayOffset;
  final Set<TripSearchWeekday> weekdays;
  final TripSearchPreferencesRequestModel preferences;
  final int? maxWalkMeters;
  final int? maxWalkSeconds;
  final int? maxTotalWalkSeconds;
  final int? timeDeviationMinutes;
  final int? pageSize;
  final String? requestId;
  final String? anchorTripId;
  final int? restoreResultCount;

  TripSearchRequestModel({
    required this.originLat,
    required this.originLon,
    required this.destinationLat,
    required this.destinationLon,
    required this.scheduleType,
    required this.date,
    required this.departureLocalTime,
    required this.arrivalLocalTime,
    this.arrivalDayOffset,
    Set<TripSearchWeekday> weekdays = const {},
    TripSearchPreferencesRequestModel? preferences,
    this.maxWalkMeters,
    this.maxWalkSeconds,
    this.maxTotalWalkSeconds,
    this.timeDeviationMinutes,
    this.pageSize,
    this.requestId,
    this.anchorTripId,
    this.restoreResultCount,
  }) : weekdays = Set.unmodifiable(weekdays),
       preferences = preferences ?? TripSearchPreferencesRequestModel();

  factory TripSearchRequestModel.fromPlanning({
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required DateTime date,
    required bool isRegularRide,
    required List<bool> selectedDays,
    required TripSearchPreferences preferences,
    required int routeDurationSeconds,
    TripSearchSort sort = TripSearchSort.score,
    int? maxWalkMeters,
    int? maxWalkSeconds,
    int? maxTotalWalkSeconds,
    int? timeDeviationMinutes,
    int? pageSize,
  }) {
    if (selectedDays.length != 7) {
      throw ArgumentError.value(
        selectedDays,
        'selectedDays',
        'Expected 7 days',
      );
    }
    if (routeDurationSeconds < 0) {
      throw ArgumentError.value(routeDurationSeconds, 'routeDurationSeconds');
    }
    final arrival = preferences.arrivalMinutes(routeDurationSeconds);
    return TripSearchRequestModel(
      originLat: originLat,
      originLon: originLon,
      destinationLat: destinationLat,
      destinationLon: destinationLon,
      scheduleType: isRegularRide
          ? TripScheduleType.recurring
          : TripScheduleType.oneTime,
      date: date,
      departureLocalTime: preferences.departureTime,
      arrivalLocalTime: TripSearchPreferences.formatTime(arrival),
      arrivalDayOffset: arrival ~/ 1440,
      weekdays: {
        if (isRegularRide)
          for (final day in TripSearchWeekday.values)
            if (selectedDays[day.index]) day,
      },
      preferences: TripSearchPreferencesRequestModel.fromPreferences(
        preferences,
        isRegularRide: isRegularRide,
        sort: sort,
      ),
      maxWalkMeters: maxWalkMeters,
      maxWalkSeconds: maxWalkSeconds,
      maxTotalWalkSeconds: maxTotalWalkSeconds,
      timeDeviationMinutes: timeDeviationMinutes,
      pageSize: pageSize,
    );
  }

  TripSearchRequestModel copyWith({
    TripSearchPreferencesRequestModel? preferences,
    Object? requestId = _unchangedSearchValue,
    Object? anchorTripId = _unchangedSearchValue,
    Object? restoreResultCount = _unchangedSearchValue,
    int? maxWalkMeters,
    int? maxWalkSeconds,
    int? maxTotalWalkSeconds,
    int? timeDeviationMinutes,
    int? pageSize,
  }) => TripSearchRequestModel(
    originLat: originLat,
    originLon: originLon,
    destinationLat: destinationLat,
    destinationLon: destinationLon,
    scheduleType: scheduleType,
    date: date,
    departureLocalTime: departureLocalTime,
    arrivalLocalTime: arrivalLocalTime,
    arrivalDayOffset: arrivalDayOffset,
    weekdays: weekdays,
    preferences: preferences ?? this.preferences,
    maxWalkMeters: maxWalkMeters ?? this.maxWalkMeters,
    maxWalkSeconds: maxWalkSeconds ?? this.maxWalkSeconds,
    maxTotalWalkSeconds: maxTotalWalkSeconds ?? this.maxTotalWalkSeconds,
    timeDeviationMinutes: timeDeviationMinutes ?? this.timeDeviationMinutes,
    pageSize: pageSize ?? this.pageSize,
    requestId: identical(requestId, _unchangedSearchValue)
        ? this.requestId
        : requestId as String?,
    anchorTripId: identical(anchorTripId, _unchangedSearchValue)
        ? this.anchorTripId
        : anchorTripId as String?,
    restoreResultCount: identical(restoreResultCount, _unchangedSearchValue)
        ? this.restoreResultCount
        : restoreResultCount as int?,
  );

  Map<String, dynamic> toJson() => {
    'originLat': originLat,
    'originLon': originLon,
    'destinationLat': destinationLat,
    'destinationLon': destinationLon,
    'scheduleType': scheduleType.apiValue,
    'date': _calendarDate(date),
    'departureLocalTime': departureLocalTime,
    'arrivalLocalTime': arrivalLocalTime,
    if (arrivalDayOffset != null) 'arrivalDayOffset': arrivalDayOffset,
    'weekdays': [
      if (scheduleType == TripScheduleType.recurring)
        for (final day in TripSearchWeekday.values)
          if (weekdays.contains(day)) day.apiValue,
    ],
    ...preferences.toJson(forSearch: true),
    if (maxWalkMeters != null) 'maxWalkMeters': maxWalkMeters,
    if (maxWalkSeconds != null) 'maxWalkSeconds': maxWalkSeconds,
    if (maxTotalWalkSeconds != null) 'maxTotalWalkSeconds': maxTotalWalkSeconds,
    if (timeDeviationMinutes != null)
      'timeDeviationMinutes': timeDeviationMinutes,
    if (pageSize != null) 'pageSize': pageSize,
    if (requestId != null) 'requestId': requestId,
    if (anchorTripId != null) 'anchorTripId': anchorTripId,
    if (restoreResultCount != null) 'restoreResultCount': restoreResultCount,
  };
}

class TripSearchPageModel {
  final String searchId;
  final List<TripSearchResultModel> items;
  final String? nextCursor;
  final bool hasMore;
  final int resultCountAtCreation;
  final DateTime expiresAt;
  final String graphRevision;
  final String formulaVersion;
  final double? priceMedian;
  final TripSearchLimitsModel limits;
  final String? previousCursor;
  final int startOffset;
  final int? anchorIndex;
  final int pageSize;
  final TripSearchLimitsModel? _selectionLimits;
  TripSearchLimitsModel get selectionLimits => _selectionLimits ?? limits;

  const TripSearchPageModel({
    required this.searchId,
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.resultCountAtCreation,
    required this.expiresAt,
    required this.graphRevision,
    required this.formulaVersion,
    required this.priceMedian,
    required this.limits,
    this.previousCursor,
    this.startOffset = 0,
    this.anchorIndex,
    this.pageSize = 20,
    TripSearchLimitsModel? selectionLimits,
  }) : _selectionLimits = selectionLimits;

  factory TripSearchPageModel.fromJson(Map<String, dynamic> json) =>
      TripSearchPageModel(
        searchId: _string(json['searchId']),
        items: _objects(json['items'], TripSearchResultModel.fromJson),
        nextCursor: json['nextCursor'] == null
            ? null
            : _string(json['nextCursor']),
        hasMore: _boolean(json['hasMore']),
        resultCountAtCreation: _integer(json['resultCountAtCreation']),
        expiresAt: _instant(json['expiresAt']),
        graphRevision: _string(json['graphRevision']),
        formulaVersion: _string(json['formulaVersion']),
        priceMedian: json['priceMedian'] == null
            ? null
            : _number(json['priceMedian']),
        limits: TripSearchLimitsModel.fromJson(_object(json['limits'])),
        previousCursor: json['previousCursor'] == null
            ? null
            : _string(json['previousCursor']),
        startOffset: json['startOffset'] == null
            ? 0
            : _integer(json['startOffset']),
        anchorIndex: json['anchorIndex'] == null
            ? null
            : _integer(json['anchorIndex']),
        pageSize: json['pageSize'] == null ? 20 : _integer(json['pageSize']),
        selectionLimits: json['selectionLimits'] == null
            ? null
            : TripSearchLimitsModel.fromJson(_object(json['selectionLimits'])),
      );
}

class TripSearchKeepAliveModel {
  final String searchId;
  final DateTime expiresAt;
  const TripSearchKeepAliveModel({
    required this.searchId,
    required this.expiresAt,
  });
  factory TripSearchKeepAliveModel.fromJson(Map<String, dynamic> json) =>
      TripSearchKeepAliveModel(
        searchId: _string(json['searchId']),
        expiresAt: _instant(json['expiresAt']),
      );
}

class TripSearchLimitsModel {
  final int maxWalkMeters;
  final int maxWalkSeconds;
  final int maxTotalWalkSeconds;
  final int timeDeviationMinutes;
  final int minimumBoardingLeadSeconds;
  final int horizonDays;

  const TripSearchLimitsModel({
    required this.maxWalkMeters,
    required this.maxWalkSeconds,
    required this.maxTotalWalkSeconds,
    required this.timeDeviationMinutes,
    required this.minimumBoardingLeadSeconds,
    required this.horizonDays,
  });

  factory TripSearchLimitsModel.fromJson(Map<String, dynamic> json) =>
      TripSearchLimitsModel(
        maxWalkMeters: _integer(json['maxWalkMeters']),
        maxWalkSeconds: _integer(json['maxWalkSeconds']),
        maxTotalWalkSeconds: _integer(json['maxTotalWalkSeconds']),
        timeDeviationMinutes: _integer(json['timeDeviationMinutes']),
        minimumBoardingLeadSeconds: _integer(
          json['minimumBoardingLeadSeconds'],
        ),
        horizonDays: _integer(json['horizonDays']),
      );
}

class TripSearchResultModel {
  final String tripId;
  final String driverId;
  final String driverName;
  final String? driverAvatarUrl;
  final double driverRating;
  final int driverRatingCount;
  final String carId;
  final String carLabel;

  /// The backend temporarily returns 1/1 until booking availability is implemented.
  final int availableSeats;

  /// Total offered passenger seats, excluding the driver.
  final int totalSeats;
  final TripSearchPointModel pickup;
  final TripSearchPointModel dropoff;
  final TripSearchWalkingMetricModel walkingToPickup;
  final TripSearchWalkingMetricModel walkingFromDropoff;
  final int rideDurationSeconds;
  final int rideDistanceMeters;

  /// Fare for one passenger and one ride, always in Ukrainian hryvnias (UAH).
  final double priceAmount;
  final TripPricingType pricingType;
  final double publishedRate;
  final bool negotiationAllowed;
  final double score;
  final TripSearchScoreComponentsModel components;
  final Set<TripSearchWeekday> matchedWeekdays;
  final int matchedDateCount;
  final int requestedDateCount;
  final List<TripSearchOccurrenceModel> occurrences;
  final TripSearchPreferenceMatchModel preferenceMatch;

  const TripSearchResultModel({
    required this.tripId,
    required this.driverId,
    required this.driverName,
    required this.driverAvatarUrl,
    required this.driverRating,
    required this.driverRatingCount,
    required this.carId,
    required this.carLabel,
    required this.availableSeats,
    required this.totalSeats,
    required this.pickup,
    required this.dropoff,
    required this.walkingToPickup,
    required this.walkingFromDropoff,
    required this.rideDurationSeconds,
    required this.rideDistanceMeters,
    required this.priceAmount,
    required this.pricingType,
    required this.publishedRate,
    required this.negotiationAllowed,
    required this.score,
    required this.components,
    required this.matchedWeekdays,
    required this.matchedDateCount,
    required this.requestedDateCount,
    required this.occurrences,
    required this.preferenceMatch,
  });

  factory TripSearchResultModel.fromJson(Map<String, dynamic> json) =>
      TripSearchResultModel(
        tripId: _string(json['tripId']),
        driverId: _string(json['driverId']),
        driverName: _string(json['driverName']),
        driverAvatarUrl: json['driverAvatarUrl'] == null
            ? null
            : _string(json['driverAvatarUrl']),
        driverRating: _number(json['driverRating']),
        driverRatingCount: _integer(json['driverRatingCount']),
        carId: _string(json['carId']),
        carLabel: _string(json['carLabel']),
        availableSeats: _integer(json['availableSeats']),
        totalSeats: _integer(json['totalSeats']),
        pickup: TripSearchPointModel.fromJson(_object(json['pickup'])),
        dropoff: TripSearchPointModel.fromJson(_object(json['dropoff'])),
        walkingToPickup: TripSearchWalkingMetricModel.fromJson(
          _object(json['walkingToPickup']),
        ),
        walkingFromDropoff: TripSearchWalkingMetricModel.fromJson(
          _object(json['walkingFromDropoff']),
        ),
        rideDurationSeconds: _integer(json['rideDurationSeconds']),
        rideDistanceMeters: _integer(json['rideDistanceMeters']),
        priceAmount: _number(json['priceAmount']),
        pricingType: _enumValue(
          json['pricingType'],
          TripPricingType.values,
          (value) => value.apiValue,
        ),
        publishedRate: _number(json['publishedRate']),
        negotiationAllowed: _boolean(json['negotiationAllowed']),
        score: _number(json['score']),
        components: TripSearchScoreComponentsModel.fromJson(
          _object(json['components']),
        ),
        matchedWeekdays: Set.unmodifiable([
          for (final day in _list(json['matchedWeekdays']))
            _enumValue(
              day,
              TripSearchWeekday.values,
              (value) => value.apiValue,
            ),
        ]),
        matchedDateCount: _integer(json['matchedDateCount']),
        requestedDateCount: _integer(json['requestedDateCount']),
        occurrences: _objects(
          json['occurrences'],
          TripSearchOccurrenceModel.fromJson,
        ),
        preferenceMatch: TripSearchPreferenceMatchModel.fromJson(
          _object(json['preferenceMatch']),
        ),
      );
}

class TripSearchPreferenceMatchModel {
  final bool timeFits;
  final TripSearchScheduleMatch? schedule;

  const TripSearchPreferenceMatchModel({
    required this.timeFits,
    required this.schedule,
  });

  factory TripSearchPreferenceMatchModel.fromJson(Map<String, dynamic> json) =>
      TripSearchPreferenceMatchModel(
        timeFits: _boolean(json['timeFits']),
        schedule: json['schedule'] == null
            ? null
            : _enumValue<TripSearchScheduleMatch>(
                json['schedule'],
                TripSearchScheduleMatch.values,
                (value) => value.apiValue,
              ),
      );
}

class TripSearchPointModel {
  final String? stopId;
  final int sequenceNumber;
  final String name;
  final TripSearchCoordinateModel coordinate;
  final int cumulativeDurationSeconds;
  final int cumulativeDistanceMeters;

  const TripSearchPointModel({
    required this.stopId,
    required this.sequenceNumber,
    required this.name,
    required this.coordinate,
    required this.cumulativeDurationSeconds,
    required this.cumulativeDistanceMeters,
  });

  factory TripSearchPointModel.fromJson(Map<String, dynamic> json) =>
      TripSearchPointModel(
        stopId: json['stopId'] == null ? null : _string(json['stopId']),
        sequenceNumber: _integer(json['sequenceNumber']),
        name: _string(json['name']),
        coordinate: TripSearchCoordinateModel.fromJson(
          _object(json['coordinate']),
        ),
        cumulativeDurationSeconds: _integer(json['cumulativeDurationSeconds']),
        cumulativeDistanceMeters: _integer(json['cumulativeDistanceMeters']),
      );
}

class TripSearchCoordinateModel {
  final double longitude;
  final double latitude;

  const TripSearchCoordinateModel({
    required this.longitude,
    required this.latitude,
  });

  factory TripSearchCoordinateModel.fromJson(Map<String, dynamic> json) =>
      TripSearchCoordinateModel(
        longitude: _number(json['longitude']),
        latitude: _number(json['latitude']),
      );
}

class TripSearchWalkingMetricModel {
  final bool reachable;
  final double distanceMeters;
  final double durationSeconds;

  const TripSearchWalkingMetricModel({
    required this.reachable,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory TripSearchWalkingMetricModel.fromJson(Map<String, dynamic> json) =>
      TripSearchWalkingMetricModel(
        reachable: _boolean(json['reachable']),
        distanceMeters: _number(json['distanceMeters']),
        durationSeconds: _number(json['durationSeconds']),
      );
}

class TripSearchScoreComponentsModel {
  final double departure;
  final double arrival;
  final double walking;
  final double weekdays;
  final double price;
  final double duration;

  const TripSearchScoreComponentsModel({
    required this.departure,
    required this.arrival,
    required this.walking,
    required this.weekdays,
    required this.price,
    required this.duration,
  });

  factory TripSearchScoreComponentsModel.fromJson(Map<String, dynamic> json) =>
      TripSearchScoreComponentsModel(
        departure: _number(json['departure']),
        arrival: _number(json['arrival']),
        walking: _number(json['walking']),
        weekdays: _number(json['weekdays']),
        price: _number(json['price']),
        duration: _number(json['duration']),
      );
}

class TripSearchOccurrenceModel {
  /// Calendar dates of the passenger request and the driver's departure.
  final DateTime requestedDate;
  final DateTime driverDepartureDate;

  /// Absolute instants; retained in UTC rather than converted to device time.
  final DateTime leaveAt;
  final DateTime boardAt;
  final DateTime alightAt;
  final DateTime arriveAt;

  const TripSearchOccurrenceModel({
    required this.requestedDate,
    required this.driverDepartureDate,
    required this.leaveAt,
    required this.boardAt,
    required this.alightAt,
    required this.arriveAt,
  });

  factory TripSearchOccurrenceModel.fromJson(Map<String, dynamic> json) =>
      TripSearchOccurrenceModel(
        requestedDate: _date(json['requestedDate']),
        driverDepartureDate: _date(json['driverDepartureDate']),
        leaveAt: _instant(json['leaveAt']),
        boardAt: _instant(json['boardAt']),
        alightAt: _instant(json['alightAt']),
        arriveAt: _instant(json['arriveAt']),
      );
}

String _calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Expected a JSON object in the search response');
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  throw const FormatException('Expected a JSON array in the search response');
}

List<T> _objects<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    List.unmodifiable(_list(value).map((item) => parse(_object(item))));

String _string(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  throw const FormatException(
    'Expected a non-empty string in the search response',
  );
}

int _integer(Object? value) {
  if (value is int) return value;
  throw const FormatException('Expected an integer in the search response');
}

double _number(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  throw const FormatException(
    'Expected a finite number in the search response',
  );
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  throw const FormatException('Expected a boolean in the search response');
}

T _enumValue<T>(Object? value, List<T> values, String Function(T) apiValue) {
  for (final candidate in values) {
    if (apiValue(candidate) == value) return candidate;
  }
  throw FormatException('Unknown search response enum value: $value');
}

DateTime _instant(Object? value) {
  final parsed = DateTime.tryParse(_string(value));
  if (parsed != null && parsed.isUtc) return parsed;
  throw const FormatException('Expected an ISO-8601 instant with a time zone');
}

DateTime _date(Object? value) {
  final text = _string(value);
  final parsed = DateTime.tryParse(text);
  if (parsed != null && text == _calendarDate(parsed)) return parsed;
  throw const FormatException('Expected a calendar date in YYYY-MM-DD format');
}
