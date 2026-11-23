import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kyiv_drive/screens/route/stops_edit_screen.dart';
import 'package:kyiv_drive/screens/route/waypoints_edit_screen.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/constants/trip_policy.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error_codes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../models/car_models.dart';
import '../../models/route_with_stops_model.dart';
import '../../models/template_model.dart';
import '../../models/trip_model.dart';
import '../../services/car_api_service.dart';
import '../../services/map_api_service.dart';
import '../../services/map_configuration.dart';
import '../../services/template_api_service.dart';
import '../../services/template_save_attempt.dart';
import '../../services/trip_api_service.dart';
import '../../services/trip_publication_attempt.dart';
import '../../services/notification_service.dart';
import '../../utils/app_route.dart';
import '../../utils/date_formatters.dart';
import '../../utils/route_card_reveal.dart';
import '../../utils/scroll_visibility.dart';
import '../../utils/template_save_validation.dart';
import '../../utils/trip_publication_validation.dart';
import '../../utils/ukraine_time.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_screen_message.dart';
import '../../widgets/address_widgets.dart';
import '../../widgets/animated_field_error.dart';
import '../../widgets/animated_control_lock.dart';
import '../../widgets/keyboard_aware_scroll_view.dart';
import '../../widgets/keyboard_dismiss_on_background_tap.dart';
import '../../widgets/keyboard_motion_coordinator.dart';

import '../../widgets/animated_touch_templates.dart';
import '../../widgets/animated_value_text.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../widgets/route_preview/add_car_bottom_sheet.dart';
import '../../widgets/route_preview/car_selector_widget.dart';
import '../../widgets/route_preview/ride_description_field.dart';
import '../../widgets/route_preview/ride_date_time_field.dart';
import '../../widgets/route_preview/ride_negotiation_toggle.dart';
import '../../widgets/route_preview/ride_price_field.dart';
import '../../widgets/route_preview/ride_planning_widgets.dart';
import '../../widgets/route_preview/route_preview_addresses.dart';
import '../../widgets/route_preview/route_preview_footer.dart';
import '../../widgets/route_preview/route_preview_skeleton.dart';
import '../../widgets/route_preview/route_template_action.dart';
import '../../widgets/shimmer_placeholder.dart';
import '../../widgets/dialogs/date_picker_dialog.dart';
import '../../widgets/dialogs/time_picker_dialog.dart';
import '../../widgets/top_bar_widget.dart';
import '../../widgets/map/route_glint_layer.dart';
import '../../widgets/map/route_reveal.dart';
import '../../widgets/map/route_stops_visibility.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_tiles.dart';

enum _PlanningLayoutProjection { current, expanded, collapsed }

class RoutePreviewDriverScreen extends StatefulWidget {
  final AddressModel origin;
  final AddressModel destination;

  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;
  final bool isFromSavedTemplates;

  final RouteWithStopsModel? preloadedRouteWithStops;
  final List<LatLng>? waypoints;

  const RoutePreviewDriverScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required this.selectedDays,
    this.isFromSavedTemplates = false,
    this.preloadedRouteWithStops,
    this.waypoints,
  });

  @override
  State<RoutePreviewDriverScreen> createState() =>
      _RoutePreviewDriverScreenState();
}

class _RoutePreviewDriverScreenState extends State<RoutePreviewDriverScreen>
    with SingleTickerProviderStateMixin {
  static const _planningSizeAnimationDuration = Duration(milliseconds: 300);
  static const _bottomChromeClearance =
      AppDimens.bottomBarShadowClearance + AppDimens.gapLg;

  final MapApiService _mapService = MapApiService(ApiClient().dio);
  final TemplateApiService _templateApiService = TemplateApiService(
    ApiClient().dio,
  );
  final TemplateSaveAttempt _templateSaveAttempt = TemplateSaveAttempt();
  final TripApiService _tripApiService = TripApiService(ApiClient().dio);
  final TripPublicationAttempt _publicationAttempt = TripPublicationAttempt();
  final CarApiService _carApiService = CarApiService(ApiClient().dio);

  CarInitDataModel? _carInitData;
  bool _isCarsLoading = true;
  String? _selectedCarId;
  RouteWithStopsModel? _routeWithStops;
  bool _isLoading = true;
  bool _showSkeleton = true;
  bool _showServiceBusyMessage = false;
  bool _isPreviewMapReady = false;
  bool _isInitialDataReady = false;
  bool _isSavingRoute = false;
  bool _isRefreshingRoute = false;
  bool _needsRouteRefresh = false;
  bool _isPublishingTrip = false;
  bool _hasUncertainPublicationResult = false;
  bool _isStopsView = false;
  bool _isEditButtonNudged = false;

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  RidePriceType _priceType = RidePriceType.fixed;
  bool _negotiationAllowed = true;

  bool _publicationWeekdaysError = false;
  TripScheduleIssue? _publicationScheduleError;
  String? _publicationServerDepartureError;
  bool _publicationCarError = false;
  bool _publicationPriceError = false;
  bool _publicationDescriptionError = false;
  int _publicationRevealGeneration = 0;
  late final Ticker _publicationRevealTicker;
  GlobalKey? _publicationRevealTargetKey;
  bool _publicationRevealFrameScheduled = false;
  bool _publicationRevealOwnsScroll = false;
  (Rect, Rect, double)? _publicationRevealLayout;
  double? _publicationRevealOffset;
  double? _publicationRevealStartOffset;
  Duration _publicationRevealLastLayoutChange = Duration.zero;
  final GlobalKey _publicationWeekdaysKey = GlobalKey();
  final GlobalKey _publicationCarKey = GlobalKey();
  final GlobalKey _publicationPriceKey = GlobalKey();
  final GlobalKey _publicationDescriptionKey = GlobalKey();

  final GlobalKey _planningBlockStartKey = GlobalKey();
  final GlobalKey _planningBlockEndKey = GlobalKey();
  final GlobalKey _planningModeTransitionKey = GlobalKey();
  final GlobalKey _regularPlanningContentKey = GlobalKey();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final GlobalKey _routeCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _planningBlockRevealScheduled = false;
  _PlanningLayoutProjection _scheduledPlanningLayoutProjection =
      _PlanningLayoutProjection.current;

  late bool _isRegularRide;
  late String _selectedTime;
  late DateTime _selectedDateTime;
  late List<bool> _selectedDays;

  Color get _brandColor => AppColors.driver;
  Color get _pinColor => AppColors.driverAccent;
  bool get _isRouteEditorEnabled =>
      !_isPublishingTrip && !_isSavingRoute && !_isRefreshingRoute;

  final Set<String> _deletingCarIds = <String>{};

  late List<LatLng> _currentWaypoints;

  List<LatLng>? _baseWaypoints;
  List<bool>? _baseStopsActiveState;
  bool _isBaseRouteSaved = false;
  bool _isRouteEdited = false;

  bool get _isRouteSaved => _isBaseRouteSaved && !_isRouteEdited;

  List<String> get _weekDays => [
    AppLocalizations.of(context)!.mon,
    AppLocalizations.of(context)!.tue,
    AppLocalizations.of(context)!.wed,
    AppLocalizations.of(context)!.thu,
    AppLocalizations.of(context)!.fri,
    AppLocalizations.of(context)!.sat,
    AppLocalizations.of(context)!.sun,
  ];

  @override
  void initState() {
    super.initState();
    _publicationRevealTicker = createTicker(_schedulePublicationRevealFrame);

    _isRegularRide = widget.isRegularRide;
    _selectedTime = widget.selectedTime;
    _selectedDateTime = widget.selectedDateTime;
    _selectedDays = List.from(widget.selectedDays);
    _isBaseRouteSaved = widget.isFromSavedTemplates;

    _currentWaypoints = widget.waypoints != null
        ? List.from(widget.waypoints!)
        : [];

    if (widget.preloadedRouteWithStops != null) {
      _routeWithStops = widget.preloadedRouteWithStops;
      _isLoading = false;
      _showSkeleton = false;
      _initBaseState();
      _fetchCarsOnly();
    } else {
      _fetchRouteAndCars();
    }
  }

  @override
  void dispose() {
    _publicationRevealGeneration++;
    _publicationRevealTicker.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCarsOnly() async {
    try {
      final carData = await _carApiService.getInitData();
      if (!mounted) return;

      setState(() {
        _carInitData = carData;
        if (carData.myCars.isNotEmpty) {
          _selectedCarId = carData.myCars.first.id;
        }
        _isCarsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCarsLoading = false);
      NotificationService.showError(e);
    }
  }

  Future<void> _fetchRouteAndCars() async {
    try {
      late CarInitDataModel carData;
      await Future.wait<void>([
        _mapService
            .getRouteWithStops(
              startLat: widget.origin.lat,
              startLon: widget.origin.lon,
              endLat: widget.destination.lat,
              endLon: widget.destination.lon,
              waypoints: _currentWaypoints,
            )
            .then((route) {
              if (!mounted) return;
              setState(() {
                _routeWithStops = route;
                _initBaseState();
              });
            }),
        _carApiService.getInitData().then<void>((data) {
          carData = data;
        }),
        Future<void>.delayed(AppDurations.minimumScreenLoading),
      ]);

      if (!mounted) return;

      setState(() {
        _carInitData = carData;
        if (carData.myCars.isNotEmpty) {
          _selectedCarId = carData.myCars.first.id;
        }

        _isCarsLoading = false;
        _isInitialDataReady = true;
        _finishPreviewLoadingIfReady();
      });
    } catch (e) {
      if (!mounted) return;
      if (isServiceBusyError(e)) {
        setState(() {
          _routeWithStops = null;
          _isPreviewMapReady = false;
          _showServiceBusyMessage = true;
          _isLoading = false;
        });
        return;
      }
      context.pop();
      NotificationService.showError(e);
    }
  }

  Future<void> _retryRouteAndCars() async {
    if (_isLoading || !_showServiceBusyMessage) return;
    setState(() {
      _isLoading = true;
      _showSkeleton = true;
    });
    await _fetchRouteAndCars();
  }

  void _initBaseState() {
    _baseWaypoints = List.from(_currentWaypoints);
    _isRouteEdited = false;
    if (_routeWithStops != null) {
      _baseStopsActiveState = _routeWithStops!.stops
          .map((s) => s.isActive)
          .toList();
    }
  }

  void _handleSkeletonFadeEnd() {
    if (_isLoading || !_showSkeleton) return;
    setState(() => _showSkeleton = false);
  }

  void _handleRetryFadeEnd() {
    if (!_isLoading || !_showServiceBusyMessage) return;
    setState(() {
      _showServiceBusyMessage = false;
      _finishPreviewLoadingIfReady();
    });
  }

  void _handlePreviewMapPresented() {
    if (!mounted || _routeWithStops == null || _isPreviewMapReady) return;
    setState(() {
      _isPreviewMapReady = true;
      _finishPreviewLoadingIfReady();
    });
  }

  void _finishPreviewLoadingIfReady() {
    if (_isInitialDataReady && _isPreviewMapReady && !_showServiceBusyMessage) {
      _isLoading = false;
    }
  }

  void _checkChanges() {
    if (_baseWaypoints == null || _baseStopsActiveState == null) return;

    bool isChanged = false;

    if (_currentWaypoints.length != _baseWaypoints!.length) {
      isChanged = true;
    } else {
      for (int i = 0; i < _currentWaypoints.length; i++) {
        if (_currentWaypoints[i] != _baseWaypoints![i]) {
          isChanged = true;
          break;
        }
      }
    }

    if (!isChanged && _routeWithStops != null) {
      final currentStops = _routeWithStops!.stops;
      if (currentStops.length != _baseStopsActiveState!.length) {
        isChanged = true;
      } else {
        for (int i = 0; i < currentStops.length; i++) {
          if (currentStops[i].isActive != _baseStopsActiveState![i]) {
            isChanged = true;
            break;
          }
        }
      }
    }

    setState(() => _isRouteEdited = isChanged);
  }

  void _schedulePlanningBlockReveal({
    _PlanningLayoutProjection projection = _PlanningLayoutProjection.current,
  }) {
    if (_planningBlockRevealScheduled) {
      if (projection != _PlanningLayoutProjection.current) {
        _scheduledPlanningLayoutProjection = projection;
      }
      return;
    }

    _planningBlockRevealScheduled = true;
    _scheduledPlanningLayoutProjection = projection;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projection = _scheduledPlanningLayoutProjection;
      _planningBlockRevealScheduled = false;
      _scheduledPlanningLayoutProjection = _PlanningLayoutProjection.current;

      if (mounted) {
        unawaited(_revealPlanningBlockIfNeeded(projection: projection));
      }
    });
  }

  Future<void> _revealPlanningBlockIfNeeded({
    _PlanningLayoutProjection projection = _PlanningLayoutProjection.current,
  }) async {
    if (!_scrollController.hasClients) return;

    final planningStartRenderObject = _planningBlockStartKey.currentContext
        ?.findRenderObject();
    final planningEndRenderObject = _planningBlockEndKey.currentContext
        ?.findRenderObject();
    final viewportRenderObject = _scrollViewportKey.currentContext
        ?.findRenderObject();
    if (planningStartRenderObject is! RenderBox ||
        planningEndRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox ||
        !planningStartRenderObject.attached ||
        !planningEndRenderObject.attached ||
        !viewportRenderObject.attached) {
      return;
    }

    final planningTopLeft = planningStartRenderObject.localToGlobal(
      Offset.zero,
    );
    final planningBottomRight = planningEndRenderObject.localToGlobal(
      planningEndRenderObject.size.bottomRight(Offset.zero),
    );
    final planningRect = Rect.fromLTRB(
      planningTopLeft.dx,
      planningTopLeft.dy,
      planningBottomRight.dx,
      planningBottomRight.dy,
    );
    var projectedBottomDelta = 0.0;
    if (projection != _PlanningLayoutProjection.current) {
      // The transition clips this child but still lays it out at full height,
      // so both expanded and collapsed targets are known before they are
      // visible.
      final transitionRenderObject = _planningModeTransitionKey.currentContext
          ?.findRenderObject();
      final regularContentRenderObject = _regularPlanningContentKey
          .currentContext
          ?.findRenderObject();
      if (transitionRenderObject is RenderBox &&
          regularContentRenderObject is RenderBox &&
          transitionRenderObject.attached &&
          regularContentRenderObject.attached) {
        final currentTransitionHeight = transitionRenderObject.size.height
            .clamp(0.0, regularContentRenderObject.size.height)
            .toDouble();
        final targetTransitionHeight =
            projection == _PlanningLayoutProjection.expanded
            ? regularContentRenderObject.size.height
            : 0.0;
        projectedBottomDelta = targetTransitionHeight - currentTransitionHeight;
      }
    }
    final viewportRect =
        viewportRenderObject.localToGlobal(Offset.zero) &
        viewportRenderObject.size;
    final visibleRect = Rect.fromLTRB(
      viewportRect.left,
      viewportRect.top +
          AppTopBarOverlayLayout.contentInsetOf(_scrollViewportKey.currentContext!),
      viewportRect.right,
      viewportRect.bottom - _bottomChromeClearance,
    );
    final scrollDelta = calculateMinimalRevealScrollDelta(
      targetRect: planningRect,
      visibleRect: visibleRect,
      projectedBottomDelta: projectedBottomDelta,
    );
    if (scrollDelta.abs() < 0.5) return;

    final position = _scrollController.position;
    final projectedMaxScrollExtent = math.max(
      position.minScrollExtent,
      position.maxScrollExtent + projectedBottomDelta,
    );
    final targetOffset = (position.pixels + scrollDelta)
        .clamp(position.minScrollExtent, projectedMaxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 0.5) return;

    await _scrollController.animateTo(
      targetOffset,
      duration: _planningSizeAnimationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _setPlanningMode({required bool isRegularRide}) {
    if (_isPublishingTrip) return;
    if (_isRegularRide == isRegularRide) return;

    setState(() {
      _isRegularRide = isRegularRide;
      if (!isRegularRide) _publicationWeekdaysError = false;
      _revalidateVisibleScheduleError();
    });

    _schedulePlanningBlockReveal(
      projection: isRegularRide
          ? _PlanningLayoutProjection.expanded
          : _PlanningLayoutProjection.collapsed,
    );
  }

  int get _priceUpperBoundCents => _priceType == RidePriceType.fixed
      ? TripPolicy.fixedPriceUpperBoundCents
      : TripPolicy.perKilometerPriceUpperBoundCents;

  TripScheduleIssue? _currentScheduleIssue() => validateTripSchedule(
    date: _selectedDateTime,
    time: TimeOfDay(
      hour: int.parse(_selectedTime.split(':')[0]),
      minute: int.parse(_selectedTime.split(':')[1]),
    ),
    isRegular: _isRegularRide,
    selectedDays: _selectedDays,
  );

  void _revalidateVisibleScheduleError() {
    if (_publicationScheduleError != null) {
      _publicationServerDepartureError = null;
      _publicationScheduleError = _currentScheduleIssue();
    }
  }

  String? _currentRouteError() {
    if (_needsRouteRefresh) {
      return AppLocalizations.of(context)!.publicationRefreshRouteRequired;
    }
    return validateTemplateSave(
      stopCount: _routeWithStops!.stops.length,
      localizations: AppLocalizations.of(context)!,
    );
  }

  GlobalKey? _firstPublicationErrorKey() {
    if (_publicationWeekdaysError) return _publicationWeekdaysKey;
    if (_publicationScheduleError != null) return _planningBlockEndKey;
    if (_publicationCarError) return _publicationCarKey;
    if (_publicationPriceError) return _publicationPriceKey;
    if (_publicationDescriptionError) return _publicationDescriptionKey;
    return null;
  }

  Future<void> _publishTrip() async {
    if (_isLoading ||
        _isCarsLoading ||
        _isSavingRoute ||
        _isRefreshingRoute ||
        _isPublishingTrip ||
        _routeWithStops == null) {
      return;
    }
    final routeError = _currentRouteError();
    setState(() {
      _publicationWeekdaysError =
          _isRegularRide && !_selectedDays.contains(true);
      _publicationServerDepartureError = null;
      _publicationScheduleError = _currentScheduleIssue();
      _publicationCarError =
          _selectedCarId == null ||
          !(_carInitData?.myCars.any(
                (car) =>
                    car.id == _selectedCarId &&
                    !_deletingCarIds.contains(car.id),
              ) ??
              false);
      _publicationPriceError = !isValidTripPrice(
        _priceController.text,
        upperBoundCents: _priceUpperBoundCents,
      );
      _publicationDescriptionError =
          _descriptionController.text.trim().length >
          TripPolicy.maximumDescriptionLength;
    });
    TripCreateRequestModel? trip;
    List<TripStopCreateRequestModel>? stops;
    if (!_publicationCarError &&
        !_publicationPriceError &&
        !_publicationDescriptionError &&
        !_publicationWeekdaysError &&
        routeError == null) {
      trip = _buildPublicationTrip();
      stops = _routeWithStops!.stops
          .map(
            (stop) => TripStopCreateRequestModel(
              stopId: stop.stopId,
              isEnabled: stop.isActive,
            ),
          )
          .toList();
      // A lost response may belong to a trip that has already departed.
      // Only an unchanged ambiguous retry may bypass this passive time check;
      // the backend still validates it if the first request was not saved.
      if (_publicationScheduleError == TripScheduleIssue.departureInPast &&
          _hasUncertainPublicationResult &&
          _publicationAttempt.matches(trip: trip, stops: stops)) {
        setState(() => _publicationScheduleError = null);
      }
    }
    ++_publicationRevealGeneration;
    if (routeError != null) {
      NotificationService.showError(routeError);
      if (_needsRouteRefresh) {
        _startPublicationErrorReveal(_routeCardKey);
        return;
      }
    }
    if (_firstPublicationErrorKey() != null) {
      _startPublicationErrorReveal(_firstPublicationErrorKey()!);
      return;
    }
    if (routeError != null) return;
    final request = _publicationAttempt.prepare(trip: trip!, stops: stops!);
    _stopPublicationErrorReveal();
    setState(() => _isPublishingTrip = true);
    try {
      await Future.wait([
        _tripApiService.publishTrip(request),
        Future<void>.delayed(const Duration(milliseconds: 600)),
      ]);
      if (!mounted) return;
      NotificationService.showInfo(
        AppLocalizations.of(context)!.tripPublished,
        brandColor: _pinColor,
      );
      context.go('/');
    } catch (error) {
      if (!mounted) return;
      final response = error is DioException ? error.response : null;
      setState(() {
        _isPublishingTrip = false;
        _hasUncertainPublicationResult =
            response == null || (response.statusCode ?? 0) >= 500;
      });
      final data = response?.data;
      if (response?.statusCode == 400 &&
          data is Map &&
          data['code'] == ApiErrorCodes.tripDepartureInPast) {
        final message = data['message'];
        setState(() {
          _publicationScheduleError = TripScheduleIssue.departureInPast;
          _publicationServerDepartureError =
              data['showUser'] == true &&
                  message is String &&
                  message.trim().isNotEmpty
              ? message
              : null;
        });
        ++_publicationRevealGeneration;
        _startPublicationErrorReveal(_planningBlockEndKey);
        return;
      }
      if (isRouteSnapshotChangedError(error)) {
        setState(() => _needsRouteRefresh = true);
        ++_publicationRevealGeneration;
        _startPublicationErrorReveal(_routeCardKey);
      }
      NotificationService.showError(error);
    }
  }

  TripCreateRequestModel _buildPublicationTrip() {
    final route = _routeWithStops!.route;
    final description = _descriptionController.text.trim();
    String addressOrFallback(String? address) =>
        address == null || address.trim().isEmpty
        ? AppLocalizations.of(context)!.unknownLocation
        : address.trim();
    bool day(int index) => _isRegularRide && _selectedDays[index];

    return TripCreateRequestModel(
      carId: _selectedCarId!,
      startShortAddress: addressOrFallback(widget.origin.shortAddress),
      startSubtitle: widget.origin.subtitle,
      endShortAddress: addressOrFallback(widget.destination.shortAddress),
      endSubtitle: widget.destination.subtitle,
      startLat: widget.origin.lat,
      startLon: widget.origin.lon,
      endLat: widget.destination.lat,
      endLon: widget.destination.lon,
      waypoints: _currentWaypoints
          .map(
            (point) =>
                TripWaypointModel(lat: point.latitude, lon: point.longitude),
          )
          .toList(),
      routePolyline: route.polyline,
      totalDistanceMeters: route.distanceMeters,
      totalDurationSeconds: route.durationSeconds,
      scheduleType: _isRegularRide
          ? TripScheduleType.recurring
          : TripScheduleType.oneTime,
      firstDepartureDate: _selectedDateTime,
      departureLocalTime: _selectedTime,
      monday: day(0),
      tuesday: day(1),
      wednesday: day(2),
      thursday: day(3),
      friday: day(4),
      saturday: day(5),
      sunday: day(6),
      pricingType: _priceType == RidePriceType.fixed
          ? TripPricingType.fixed
          : TripPricingType.perKilometer,
      priceAmount: parsePriceCents(_priceController.text)! / 100,
      negotiationAllowed: _negotiationAllowed,
      description: description.isEmpty ? null : description,
    );
  }

  void _startPublicationErrorReveal(GlobalKey targetKey) {
    _publicationRevealTicker.stop();
    _publicationRevealTargetKey = targetKey;
    _publicationRevealFrameScheduled = false;
    _publicationRevealOwnsScroll = false;
    _publicationRevealLayout = null;
    _publicationRevealOffset = null;
    _publicationRevealStartOffset = null;
    _publicationRevealLastLayoutChange = Duration.zero;
    _publicationRevealTicker.start();
  }

  void _stopPublicationErrorReveal() {
    _publicationRevealTicker.stop();
    _publicationRevealTargetKey = null;
    _publicationRevealFrameScheduled = false;
  }

  void _schedulePublicationRevealFrame(Duration elapsed) {
    if (_publicationRevealFrameScheduled) return;
    _publicationRevealFrameScheduled = true;
    final generation = _publicationRevealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _publicationRevealGeneration ||
          !_publicationRevealTicker.isActive) {
        return;
      }
      _publicationRevealFrameScheduled = false;
      _revealPublicationErrorFrame(elapsed);
    });
  }

  bool _handlePublicationScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        notification.metrics.axis == Axis.vertical) {
      ++_publicationRevealGeneration;
      _stopPublicationErrorReveal();
    }
    return false;
  }

  void _revealPublicationErrorFrame(Duration elapsed) {
    if (elapsed >= const Duration(seconds: 2)) {
      _stopPublicationErrorReveal();
      return;
    }
    final targetKey = _publicationRevealTargetKey;
    final currentTarget = _needsRouteRefresh
        ? _routeCardKey
        : _firstPublicationErrorKey();
    if (!_scrollController.hasClients || targetKey != currentTarget) {
      _stopPublicationErrorReveal();
      return;
    }
    final target = targetKey?.currentContext?.findRenderObject();
    final viewport = _scrollViewportKey.currentContext?.findRenderObject();
    if (target is! RenderBox ||
        viewport is! RenderBox ||
        !target.attached ||
        !viewport.attached) {
      _stopPublicationErrorReveal();
      return;
    }
    if (!_publicationRevealOwnsScroll) {
      KeyboardMotionCoordinator.explicitRevealStartedCallbackOf(
        _scrollViewportKey.currentContext!,
      )?.call();
      if (_scrollController.position.isScrollingNotifier.value) {
        // Cancel the old focus reveal at its current position, without a visual jump.
        _scrollController.jumpTo(_scrollController.offset);
      }
      _publicationRevealOwnsScroll = true;
    }
    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    final visible = Rect.fromLTRB(
      viewportRect.left,
      viewportRect.top +
          AppTopBarOverlayLayout.contentInsetOf(
            _scrollViewportKey.currentContext!,
          ),
      viewportRect.right,
      viewportRect.bottom - _bottomChromeClearance,
    );
    if (visible.height <= 0) return;
    final rect = target.localToGlobal(Offset.zero) & target.size;
    final position = _scrollController.position;
    _publicationRevealStartOffset ??= position.pixels;
    // Content coordinates exclude movement caused by our own scrolling.
    final contentRect = rect.shift(Offset(0, position.pixels));
    final previousLayout = _publicationRevealLayout;
    bool rectChanged(Rect before, Rect after) =>
        (before.left - after.left).abs() > 0.1 ||
        (before.top - after.top).abs() > 0.1 ||
        (before.right - after.right).abs() > 0.1 ||
        (before.bottom - after.bottom).abs() > 0.1;
    final layoutChanged =
        previousLayout == null ||
        rectChanged(previousLayout.$1, contentRect) ||
        rectChanged(previousLayout.$2, visible) ||
        (previousLayout.$3 - position.maxScrollExtent).abs() > 0.1;
    if (layoutChanged) {
      _publicationRevealLayout = (
        contentRect,
        visible,
        position.maxScrollExtent,
      );
      _publicationRevealLastLayoutChange = elapsed;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (layoutChanged) {
      final previousOffset = _publicationRevealOffset ?? position.pixels;
      final projectedRect = rect.shift(
        Offset(0, position.pixels - previousOffset),
      );
      final targetRect = targetKey == _routeCardKey
          ? calculateRouteCardRevealTargetRect(
              cardRect: projectedRect,
              visibleRect: visible,
            )
          : Rect.fromLTWH(
              projectedRect.left,
              projectedRect.top,
              projectedRect.width,
              math.min(projectedRect.height, visible.height),
            );
      final delta = calculateMinimalRevealScrollDelta(
        targetRect: targetRect,
        visibleRect: visible,
      );
      _publicationRevealOffset = (previousOffset + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
    }
    // One paced reveal follows the changing destination. Restarting animateTo
    // on every size change would keep resetting its first animation frame.
    final progress = reduceMotion
        ? 1.0
        : Curves.easeOutQuad.transform(
            (elapsed.inMicroseconds /
                    const Duration(milliseconds: 280).inMicroseconds)
                .clamp(0.0, 1.0),
          );
    final startOffset = _publicationRevealStartOffset!;
    final offset =
        (startOffset + (_publicationRevealOffset! - startOffset) * progress)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if ((offset - position.pixels).abs() > 0.1) {
      _scrollController.jumpTo(offset);
    }
    // Finish only after the last frame has reached the updated destination.
    if (elapsed >= (reduceMotion ? Duration.zero : AppDurations.fast) &&
        elapsed - _publicationRevealLastLayoutChange >=
            const Duration(milliseconds: 32) &&
        (_publicationRevealOffset! - position.pixels).abs() < 0.5 &&
        View.of(context).viewInsets.bottom == 0) {
      _stopPublicationErrorReveal();
    }
  }

  String? _scheduleErrorMessage(AppLocalizations localizations) =>
      switch (_publicationScheduleError) {
        TripScheduleIssue.nonexistentTime =>
          localizations.publicationNonexistentTime,
        TripScheduleIssue.departureInPast =>
          _publicationServerDepartureError ??
              localizations.publicationDepartureInPast,
        TripScheduleIssue.unselectedWeekday =>
          localizations.publicationDateNotSelectedWeekday,
        null => null,
      };

  Future<T?> _openRouteEditor<T>(Widget editor) {
    if (!_isRouteEditorEnabled) return Future<T?>.value(null);
    final route = AppRoute<T>(child: editor);
    final result = Navigator.of(context).push<T>(route);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final animation = route.animation;

      if (animation == null || animation.status == AnimationStatus.completed) {
        _resetRouteCardScroll();
        return;
      }

      late AnimationStatusListener listener;
      listener = (status) {
        if (status != AnimationStatus.completed) return;

        animation.removeStatusListener(listener);
        _resetRouteCardScroll();
      };
      animation.addStatusListener(listener);
    });

    return result;
  }

  void _resetRouteCardScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    if ((position.pixels - position.minScrollExtent).abs() < 0.5) return;

    _scrollController.jumpTo(position.minScrollExtent);
  }

  Future<void> _editCar(String carId) async {
    if (_isPublishingTrip || _deletingCarIds.contains(carId)) return;
    final car = _carInitData?.myCars
        .where((car) => car.id == carId)
        .firstOrNull;
    if (car == null) return;

    final updatedCar = await AddCarBottomSheet.show(
      context,
      _carApiService,
      _carInitData!.brands,
      _carInitData!.myCars,
      carToEdit: car,
    );
    if (!mounted || updatedCar == null) return;

    final cars = _carInitData?.myCars;
    final index = cars?.indexWhere((car) => car.id == carId) ?? -1;
    if (index == -1) return;
    setState(() {
      cars![index] = updatedCar;
      if (_selectedCarId == carId) {
        _selectedCarId = updatedCar.id;
        _publicationCarError = false;
      }
    });
  }

  Future<void> _deleteCar(String carId) async {
    if (_isPublishingTrip) return;
    if (_deletingCarIds.contains(carId)) return;

    final cars = _carInitData?.myCars;

    if (cars == null) return;

    final carIndex = cars.indexWhere((car) => car.id == carId);

    if (carIndex == -1) return;

    final car = cars[carIndex];

    final confirmed = await AppDialogs.show(
      context,
      title: AppLocalizations.of(context)!.deleteCar,
      content: AppLocalizations.of(
        context,
      )!.sureToDeleteCar(car.brandName, car.modelName),
      primaryButtonText: AppLocalizations.of(context)!.delete,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    if (_deletingCarIds.contains(carId)) return;

    setState(() {
      _deletingCarIds.add(carId);
    });

    try {
      await _carApiService.deleteCar(carId);

      if (!mounted) return;

      setState(() {
        _deletingCarIds.remove(carId);

        _carInitData!.myCars.removeWhere((car) => car.id == carId);

        if (_selectedCarId == carId) {
          _selectedCarId = _carInitData!.myCars.isNotEmpty
              ? _carInitData!.myCars.first.id
              : null;
        }
        if (_publicationCarError && _selectedCarId != null) {
          _publicationCarError = false;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _deletingCarIds.remove(carId);
        if (_publicationCarError && _selectedCarId == carId) {
          _publicationCarError = false;
        }
      });

      NotificationService.showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBottomBar = !_isLoading && _routeWithStops != null;
    final reserveBottomBar = _showSkeleton || _routeWithStops != null;
    final isRetryTransition = _isLoading && _showServiceBusyMessage;
    final mediaQuery = MediaQuery.of(context);

    return PopScope(
      canPop: !_isPublishingTrip,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        extendBody: _showServiceBusyMessage,
        bottomNavigationBar: reserveBottomBar
            // Scaffold preserves bottom padding when resizing is disabled.
            // Restore the system values so only our gap remains above the IME.
            ? MediaQuery(
                data: mediaQuery,
                child: RoutePreviewBottomAction(
                  showAction: showBottomBar,
                  showSkeleton: _showSkeleton,
                  visible: !_showServiceBusyMessage || isRetryTransition,
                  fadeInOnMount: isRetryTransition,
                  maintainBottomViewPadding: false,
                  bottomInset: mediaQuery.viewInsets.bottom,
                  action: AuthButton(
                    text: AppLocalizations.of(context)!.publishRide,
                    color: _brandColor,
                    isLoading: _isPublishingTrip,
                    onTap:
                        _isCarsLoading ||
                            _isSavingRoute ||
                            _isRefreshingRoute ||
                            _isPublishingTrip
                        ? null
                        : _publishTrip,
                  ),
                ),
              )
            : null,
        body: LayoutBuilder(
          builder: (context, _) {
            // The moving footer already reserves the complete keyboard inset.
            // Only its closed safe-area padding is replaced by the keyboard;
            // the base footer height is present in both viewport sizes.
            final reservedBottomInset = reserveBottomBar
                ? mediaQuery.viewPadding.bottom
                : 0.0;

            return KeyboardMotionCoordinator(
              scrollController: _scrollController,
              scrollPhysics: const BouncingScrollPhysics(),
              reservedBottomInset: reservedBottomInset,
              applyKeyboardInsetToLayout: false,
              builder: (context, _, scrollPhysics, bottomScrollExtent) {
                return KeyboardDismissOnBackgroundTap(
                  child: AppTopBarOverlayLayout(
                    title: AppLocalizations.of(context)!.planingTrip,
                    leadingIcon: Icons.close_rounded,
                    onLeadingTap: _isPublishingTrip
                        ? null
                        : () => context.pop(),
                    isLeadingEnabled: !_isPublishingTrip,
                    clipBehavior: Clip.none,
                    bodyBuilder: (context, topInset) {
                      final padding = EdgeInsets.fromLTRB(
                        AppDimens.pagePadding,
                        topInset,
                        AppDimens.pagePadding,
                        AppDimens.pagePadding +
                            AppDimens.bottomBarShadowClearance +
                            bottomScrollExtent,
                      );
                      return RoutePreviewContentTransition(
                        isLoading: _isLoading,
                        onSkeletonFadeEnd: _handleSkeletonFadeEnd,
                        onRetryFadeEnd: _handleRetryFadeEnd,
                        skeleton: _showSkeleton
                            ? SingleChildScrollView(
                                primary: false,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: padding,
                                child: _buildSkeleton(),
                              )
                            : null,
                        content: _buildPreviewContent(
                          context,
                          padding: padding,
                          scrollPhysics: scrollPhysics,
                        ),
                        error: _showServiceBusyMessage
                            ? MediaQuery(
                                data: mediaQuery,
                                child: AppScreenMessage.serviceBusy(
                                  context: context,
                                  topInset: topInset,
                                  onRetry: _retryRouteAndCars,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewContent(
    BuildContext context, {
    required EdgeInsets padding,
    required ScrollPhysics scrollPhysics,
  }) {
    final routeWithStops = _routeWithStops;
    if (routeWithStops == null) return const SizedBox.shrink();

    return NotificationListener<ScrollNotification>(
      onNotification: _handlePublicationScroll,
      child: Listener(
        onPointerDown: (_) {
          ++_publicationRevealGeneration;
          _stopPublicationErrorReveal();
        },
        child: KeyboardAwareScrollView(
          key: _scrollViewportKey,
          controller: _scrollController,
          clipBehavior: Clip.none,
          scrollbarMainAxisMargin: 0,
          scrollbarPadding: EdgeInsets.only(
            top: AppTopBarOverlayLayout.contentInsetOf(context),
            bottom: AppDimens.pagePadding + AppDimens.bottomBarShadowClearance,
            right: AppScrollbar.screenRightInsetOf(context),
          ),
          padding: padding,
          physics: scrollPhysics,
          child: Column(
            key: const ValueKey('loaded_content'),
            children: [
              RouteEditorTilePreloader(
                points: routeWithStops.route.points,
                url: MapConfiguration().mapUrlTemplate,
                accessToken: MapConfiguration().mapAccessToken,
                enabled: _isPreviewMapReady && !_isLoading,
              ),
              _buildUnifiedRouteCard(),
              const SizedBox(height: AppDimens.gap2xl),
              SectionDivider(
                key: _planningBlockStartKey,
                title: AppLocalizations.of(context)!.scheduleRide,
              ),
              const SizedBox(height: AppDimens.gapLg),
              _buildPlanningSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedRouteCard() {
    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;
    final baseRoute = _routeWithStops!.route;
    final stops = _routeWithStops!.stops;

    return Container(
      key: _routeCardKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.surfaceBr,
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppDimens.borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.surfaceBr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: RoutePreviewHint(
                AppLocalizations.of(context)!.makeSureTheRouteSuitsYou,
              ),
            ),

            TabSwitcher(
              isRightTabSelected: _isStopsView,
              leftTabTitle: AppLocalizations.of(context)!.route,
              rightTabTitle: AppLocalizations.of(context)!.stops,

              backgroundColor: Colors.white.withValues(alpha: 0.03),
              activeColor: Colors.white.withValues(alpha: 0.08),

              outerBorderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.medium),
              ),

              onLeftTap: () {
                if (!_isStopsView) return;
                setState(() {
                  _isStopsView = false;
                  _isEditButtonNudged = _isRouteEditorEnabled;
                });
              },
              onRightTap: () {
                if (_isStopsView) return;
                setState(() {
                  _isStopsView = true;
                  _isEditButtonNudged = _isRouteEditorEnabled;
                });
              },
            ),

            RoutePreviewMapFrame(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: RouteMapSurface(
                        key: const ValueKey('driver-preview-map'),
                        url: mapUrlTemplate,
                        accessToken: mapAccessToken,
                        revealWithParent: _isLoading,
                        onPresented: _handlePreviewMapPresented,
                        options: MapOptions(
                          backgroundColor: AppColors.background,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                          initialCameraFit: CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(baseRoute.points),
                            padding: const EdgeInsets.all(36),
                          ),
                        ),
                        children: [
                          RouteReveal(
                            points: baseRoute.points,
                            revision: baseRoute,
                            ready: !_isLoading && !_showSkeleton,
                            updateCameraFit: CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(baseRoute.points),
                              padding: const EdgeInsets.all(36),
                            ),
                            children: [
                              RoutePolylineLayer(
                                color: _isStopsView
                                    ? Colors.white30
                                    : AppColors.driverRouteLine,
                              ),
                              RouteGlintLayer(
                                points: baseRoute.points,
                                color: AppColors.driverRouteLine,
                                enabled:
                                    !_isStopsView &&
                                    !_isLoading &&
                                    !_showSkeleton &&
                                    !_needsRouteRefresh &&
                                    !_isRefreshingRoute,
                              ),
                              RouteStopsVisibility(
                                visible: _isStopsView,
                                child: MarkerLayer(
                                  markers: [
                                    ...stops.map(
                                      (stop) => Marker(
                                        point: LatLng(stop.lat, stop.lon),
                                        width: 12,
                                        height: 12,
                                        alignment: Alignment.center,
                                        child: RouteRevealMarker(
                                          point: LatLng(stop.lat, stop.lon),
                                          fractionHint:
                                              baseRoute.distanceMeters > 0
                                              ? stop.distanceMeters /
                                                    baseRoute.distanceMeters
                                              : null,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: stop.isActive
                                                  ? _pinColor
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: stop.isActive
                                                    ? Colors.white
                                                    : Colors.white38,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      widget.origin.lat,
                                      widget.origin.lon,
                                    ),
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: AppColors.background,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Icon(
                                          Icons.radio_button_checked,
                                          color: _pinColor,
                                          size: 23,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black87,
                                              offset: Offset(-1.2, -1.2),
                                            ),
                                            Shadow(
                                              color: Colors.black87,
                                              offset: Offset(1.2, -1.2),
                                            ),
                                            Shadow(
                                              color: Colors.black87,
                                              offset: Offset(1.2, 1.2),
                                            ),
                                            Shadow(
                                              color: Colors.black87,
                                              offset: Offset(-1.2, 1.2),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Marker(
                                    point: LatLng(
                                      widget.destination.lat,
                                      widget.destination.lon,
                                    ),
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    child: Transform.translate(
                                      offset: const Offset(0, -12),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned(
                                            top: 3.0,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF1C1C1E),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.location_on,
                                            color: Colors.white,
                                            size: 30,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black87,
                                                offset: Offset(-1.2, -1.2),
                                              ),
                                              Shadow(
                                                color: Colors.black87,
                                                offset: Offset(1.2, -1.2),
                                              ),
                                              Shadow(
                                                color: Colors.black87,
                                                offset: Offset(1.2, 1.2),
                                              ),
                                              Shadow(
                                                color: Colors.black87,
                                                offset: Offset(-1.2, 1.2),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  AnimatedPositioned(
                    top: RoutePreviewMapFrame.editButtonInset,
                    right: _isEditButtonNudged
                        ? 22
                        : RoutePreviewMapFrame.editButtonInset,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    onEnd: () {
                      if (!_isEditButtonNudged || !mounted) return;
                      setState(() => _isEditButtonNudged = false);
                    },
                    child: AnimatedControlLock(
                      key: const ValueKey('publication-editor-lock'),
                      isEnabled: _isRouteEditorEnabled,
                      child: AnimatedTouchItem(
                        onTap: !_isRouteEditorEnabled
                            ? null
                            : () async {
                                if (_isStopsView) {
                                  final List<StopOnRouteModel>? updatedStops =
                                      await _openRouteEditor(
                                        StopsEditScreen(
                                          baseRoute: baseRoute,
                                          initialStops: stops,
                                          origin: widget.origin,
                                          destination: widget.destination,
                                          waypoints: _currentWaypoints,
                                        ),
                                      );

                                  if (updatedStops != null && mounted) {
                                    setState(() {
                                      _routeWithStops = RouteWithStopsModel(
                                        route: baseRoute,
                                        stops: updatedStops,
                                      );
                                    });
                                    _checkChanges();
                                  }
                                } else {
                                  final WaypointsEditResult? result =
                                      await _openRouteEditor(
                                        WaypointsEditScreen(
                                          baseRoute: baseRoute,
                                          initialWaypoints: _currentWaypoints,
                                          origin: widget.origin,
                                          destination: widget.destination,
                                          isRegularRide: _isRegularRide,
                                          selectedDateTime: _selectedDateTime,
                                          selectedTime: _selectedTime,
                                          selectedDays: _selectedDays,
                                        ),
                                      );

                                  if (result != null && mounted) {
                                    setState(() {
                                      _currentWaypoints = result.waypoints;
                                      _routeWithStops = result.routeData;
                                    });
                                    _checkChanges();
                                  }
                                }
                              },
                        normalColor: AppColors.floatingSurface,
                        pressedColor: Color.alphaBlend(
                          Colors.white.withValues(alpha: 0.03),
                          AppColors.floatingSurface,
                        ),
                        pressedScale: 0.95,
                        borderRadius: AppRadius.smallBr,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        child: const SizedBox(
                          width: RoutePreviewMapFrame.editButtonSize,
                          height: RoutePreviewMapFrame.editButtonSize,
                          child: Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            RoutePreviewAddresses(
              origin: AddressRow(
                iconWidget: Icon(
                  Icons.radio_button_checked,
                  color: _brandColor,
                  size: RoutePreviewAddresses.originIconSize,
                ),
                text:
                    widget.origin.shortAddress ??
                    AppLocalizations.of(context)!.unknownLocation,
                subtitle: widget.origin.subtitle,
                textColor: Colors.white,
              ),
              destination: AddressRow(
                iconWidget: const Icon(
                  Icons.location_on,
                  color: Colors.white70,
                  size: RoutePreviewAddresses.destinationIconSize,
                ),
                text:
                    widget.destination.shortAddress ??
                    AppLocalizations.of(context)!.unknownLocation,
                subtitle: widget.destination.subtitle,
                textColor: Colors.white,
              ),
            ),

            RoutePreviewFooter(
              durationSeconds: baseRoute.durationSeconds,
              distanceMeters: baseRoute.distanceMeters,
              action: RouteTemplateAction(
                refreshRequired: _needsRouteRefresh,
                isSaving: _isSavingRoute,
                isRefreshing: _isRefreshingRoute,
                isSaved: _isRouteSaved,
                isEnabled: !_isPublishingTrip,
                accentColor: _pinColor,
                onSave: _saveRoute,
                onRefresh: _refreshRoute,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (_isPublishingTrip ||
        _isSavingRoute ||
        _isRefreshingRoute ||
        _isRouteSaved ||
        _needsRouteRefresh) {
      return;
    }
    final baseRoute = _routeWithStops!.route;
    final stops = _routeWithStops!.stops;
    final validationError = validateTemplateSave(
      stopCount: stops.length,
      localizations: AppLocalizations.of(context)!,
    );
    if (validationError != null) {
      NotificationService.showError(validationError);
      return;
    }

    setState(() {
      _isSavingRoute = true;
    });

    try {
      final String safeStartAddress =
          (widget.origin.shortAddress != null &&
              widget.origin.shortAddress!.trim().isNotEmpty)
          ? widget.origin.shortAddress!
          : AppLocalizations.of(context)!.unknownLocation;

      final String safeEndAddress =
          (widget.destination.shortAddress != null &&
              widget.destination.shortAddress!.trim().isNotEmpty)
          ? widget.destination.shortAddress!
          : AppLocalizations.of(context)!.unknownLocation;

      final templateRequest = _templateSaveAttempt.prepare(
        template: TemplateCreateRequestModel(
          startShortAddress: safeStartAddress,
          startSubtitle: widget.origin.subtitle ?? '',
          startLat: widget.origin.lat,
          startLon: widget.origin.lon,
          endShortAddress: safeEndAddress,
          endSubtitle: widget.destination.subtitle ?? '',
          endLat: widget.destination.lat,
          endLon: widget.destination.lon,
          routePolyline: baseRoute.polyline,
          totalDurationSeconds: baseRoute.durationSeconds,
          totalDistanceMeters: baseRoute.distanceMeters,
          waypoints: _currentWaypoints
              .map(
                (waypoint) => TripWaypointModel(
                  lat: waypoint.latitude,
                  lon: waypoint.longitude,
                ),
              )
              .toList(),
        ),
        stops: stops
            .map(
              (stop) => TemplateStopCreateRequestModel(
                stopId: stop.stopId,
                isEnabled: stop.isActive,
              ),
            )
            .toList(),
      );

      await Future.wait([
        _templateApiService.createTemplate(templateRequest),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);

      if (!mounted) return;
      setState(() {
        _isSavingRoute = false;
        _isBaseRouteSaved = true;
        _initBaseState();
      });

      NotificationService.showInfo(
        AppLocalizations.of(context)!.routeSavedToTemplates,
        brandColor: _pinColor,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingRoute = false);
      _handleRouteError(error);
    }
  }

  void _handleRouteError(Object error) {
    if (isRouteSnapshotChangedError(error)) {
      setState(() => _needsRouteRefresh = true);
      scheduleRouteCardReveal(
        context: context,
        scrollController: _scrollController,
        cardKey: _routeCardKey,
        viewportKey: _scrollViewportKey,
        bottomClearance: _bottomChromeClearance,
      );
    }
    NotificationService.showError(error);
  }

  Future<void> _refreshRoute() async {
    if (_isPublishingTrip ||
        _isRefreshingRoute ||
        _isSavingRoute ||
        !_needsRouteRefresh) {
      return;
    }

    final enabledStops = {
      for (final stop in _routeWithStops!.stops) stop.stopId: stop.isActive,
    };
    setState(() => _isRefreshingRoute = true);
    try {
      final results = await Future.wait([
        _mapService.getRouteWithStops(
          startLat: widget.origin.lat,
          startLon: widget.origin.lon,
          endLat: widget.destination.lat,
          endLon: widget.destination.lon,
          waypoints: _currentWaypoints,
        ),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);
      if (!mounted) return;

      final refreshed = results[0] as RouteWithStopsModel;
      for (final stop in refreshed.stops) {
        stop.isActive = enabledStops[stop.stopId] ?? stop.isActive;
      }
      setState(() {
        _routeWithStops = refreshed;
        _isRefreshingRoute = false;
        _needsRouteRefresh = false;
        _isBaseRouteSaved = false;
        _templateSaveAttempt.reset();
        _initBaseState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRefreshingRoute = false);
      _handleRouteError(error);
    }
  }

  Widget _lockedPublicationControl(Widget child, {Key? key}) =>
      AnimatedControlLock(
        key: key,
        isEnabled: !_isPublishingTrip,
        child: child,
      );

  Future<void> _pickDepartureDate() async {
    if (_isPublishingTrip) return;
    _schedulePlanningBlockReveal();
    final today = UkraineTime.today();
    final pickedDate = await AppDatePickerExtension.showDatePicker(
      context,
      initialDate: _selectedDateTime,
      firstDate: today,
      lastDate: DateTime(
        today.year,
        today.month,
        today.day + TripPolicy.maximumDepartureDaysAhead,
      ),
      selectableDayPredicate: _isRegularRide
          ? (date) => _selectedDays[date.weekday - 1]
          : null,
      brandColor: _brandColor,
    );
    if (!mounted || pickedDate == null || _isPublishingTrip) return;
    setState(() {
      _selectedDateTime = pickedDate;
      _revalidateVisibleScheduleError();
    });
  }

  Future<void> _pickDepartureTime() async {
    if (_isPublishingTrip) return;
    _schedulePlanningBlockReveal();
    final parts = _selectedTime.split(':');
    final pickedTime = await AppTimePicker.showTimePicker(
      context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 12,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
      brandColor: _brandColor,
    );
    if (!mounted || pickedTime == null || _isPublishingTrip) return;
    setState(() {
      final hh = pickedTime.hour.toString().padLeft(2, '0');
      final mm = pickedTime.minute.toString().padLeft(2, '0');
      _selectedTime = '$hh:$mm';
      _revalidateVisibleScheduleError();
    });
  }

  Widget _buildPlanningSection(BuildContext topBarContext) {
    final fieldRevealVisibilityPadding = EdgeInsets.fromLTRB(
      AppDimens.gapLg,
      AppTopBarOverlayLayout.contentInsetOf(topBarContext),
      AppDimens.gapLg,
      _bottomChromeClearance,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lockedPublicationControl(
          SizedBox(
            width: double.infinity,
            child: TabSwitcher(
              isRightTabSelected: _isRegularRide,
              leftTabTitle: AppLocalizations.of(context)!.notRegular,
              rightTabTitle: AppLocalizations.of(context)!.regular,
              activeColor: _brandColor,
              onLeftTap: () {
                _setPlanningMode(isRegularRide: false);
              },
              onRightTap: () {
                _setPlanningMode(isRegularRide: true);
              },
            ),
          ),
          key: const ValueKey('publication-mode-lock'),
        ),

        const SizedBox(height: AppDimens.gapLg),

        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _isRegularRide ? 1 : 0),
          duration: _planningSizeAnimationDuration,
          curve: Curves.easeInOutCubic,
          builder: (context, sizeFactor, child) {
            return ClipRect(
              key: _planningModeTransitionKey,
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: sizeFactor,
                child: Opacity(opacity: sizeFactor, child: child),
              ),
            );
          },
          child: Padding(
            key: _regularPlanningContentKey,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              key: _publicationWeekdaysKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimens.gapSm,
                    bottom: AppDimens.gapSm,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.selectDaysOfWeek,
                    style: AppText.hint,
                  ),
                ),
                _lockedPublicationControl(
                  WeekDaysSelector(
                    weekDays: _weekDays,
                    selectedDays: _selectedDays,
                    activeColor: _brandColor,
                    hasError: _publicationWeekdaysError,
                    onDayTapped: (index) {
                      if (_isPublishingTrip) return;
                      setState(() {
                        _selectedDays[index] = !_selectedDays[index];
                        if (_publicationWeekdaysError &&
                            _selectedDays.contains(true)) {
                          _publicationWeekdaysError = false;
                        }
                        _revalidateVisibleScheduleError();
                      });
                    },
                  ),
                  key: const ValueKey('publication-weekdays-lock'),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.gapSm,
            bottom: AppDimens.gapSm,
          ),
          child: AnimatedValueText(
            _isRegularRide
                ? AppLocalizations.of(context)!.selectFirstRideDateAndTime
                : AppLocalizations.of(context)!.selectDateAndTime,
            style: AppText.hint,
          ),
        ),

        Column(
          key: _planningBlockEndKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RideDateTimeField(
              key: const ValueKey('publication-date-time-field'),
              dateText: DateFormatters.getDisplayDate(
                context,
                _selectedDateTime,
              ),
              timeText: _selectedTime,
              isEnabled: !_isPublishingTrip,
              hasError: _publicationScheduleError != null,
              onDateTap: _pickDepartureDate,
              onTimeTap: _pickDepartureTime,
            ),

            AnimatedFieldError(
              errorText: _scheduleErrorMessage(AppLocalizations.of(context)!),
            ),
          ],
        ),

        const SizedBox(height: AppDimens.gapXl),
        SectionDivider(title: AppLocalizations.of(context)!.rideDetails),
        const SizedBox(height: AppDimens.gapLg),

        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.gapSm,
            right: AppDimens.gapSm,
            bottom: AppDimens.gapSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.chooseCar,
                style: AppText.hint,
              ),
              AnimatedValueText(
                '${_carInitData?.myCars.length ?? 0}/${CarSelectorWidget.maxCars}',
                alignment: AlignmentDirectional.centerEnd,
                style: AppText.hint,
              ),
            ],
          ),
        ),

        _lockedPublicationControl(
          CarSelectorWidget(
            key: _publicationCarKey,
            hasError: _publicationCarError,
            isLoading: _isCarsLoading,
            cars: _carInitData?.myCars ?? [],
            selectedCarId: _selectedCarId,
            deletingCarIds: _deletingCarIds,
            onCarSelected: (carId) {
              if (_isPublishingTrip || _deletingCarIds.contains(carId)) return;

              setState(() {
                _selectedCarId = carId;
                _publicationCarError = false;
              });
            },
            onDeleteCarTap: _deleteCar,
            onEditCarTap: _editCar,
            onAddCarTap: () async {
              if (_isPublishingTrip) return;
              final brands = _carInitData?.brands ?? [];
              final newCar = await AddCarBottomSheet.show(
                context,
                _carApiService,
                brands,
                _carInitData?.myCars ?? const [],
              );

              if (newCar != null && mounted) {
                setState(() {
                  _carInitData!.myCars.add(newCar);
                  _selectedCarId = newCar.id;
                  _publicationCarError = false;
                });
              }
            },
          ),
          key: const ValueKey('publication-car-lock'),
        ),

        const SizedBox(height: AppDimens.gapXl),

        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.gapSm,
            right: AppDimens.gapSm,
            bottom: AppDimens.gapSm,
          ),
          child: Text(
            AppLocalizations.of(context)!.specifyFixedOrPerKilometerPrice,
            style: AppText.hint,
          ),
        ),

        RidePriceField(
          key: _publicationPriceKey,
          controller: _priceController,
          priceType: _priceType,
          errorText: _publicationPriceError ? '' : null,
          isEnabled: !_isPublishingTrip,
          onChanged: (_) {
            if (_publicationPriceError) {
              setState(
                () => _publicationPriceError = !isValidTripPrice(
                  _priceController.text,
                  upperBoundCents: _priceUpperBoundCents,
                ),
              );
            }
          },
          focusColor: _brandColor,
          cursorColor: AppColors.driverText,
          useKeyboardRevealTarget: true,
          keyboardRevealVisibilityPadding: fieldRevealVisibilityPadding,
          onPriceTypeChanged: (priceType) {
            if (_isPublishingTrip) return;
            setState(() {
              _priceType = priceType;
              if (_priceController.text.isNotEmpty || _publicationPriceError) {
                _publicationPriceError = !isValidTripPrice(
                  _priceController.text,
                  upperBoundCents: _priceUpperBoundCents,
                );
              }
            });
          },
        ),

        const SizedBox(height: AppDimens.gapMd),
        _lockedPublicationControl(
          RideNegotiationToggle(
            value: _negotiationAllowed,
            onChanged: _isPublishingTrip
                ? null
                : (value) {
                    if (_isPublishingTrip) return;
                    setState(() => _negotiationAllowed = value);
                  },
          ),
          key: const ValueKey('publication-negotiation-lock'),
        ),

        const SizedBox(height: AppDimens.gapXl),

        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.gapSm,
            right: AppDimens.gapSm,
            bottom: AppDimens.gapSm,
          ),
          child: Text(
            AppLocalizations.of(context)!.describeRideDetails,
            style: AppText.hint,
          ),
        ),

        RideDescriptionField(
          key: _publicationDescriptionKey,
          isEnabled: !_isPublishingTrip,
          errorText: _publicationDescriptionError
              ? AppLocalizations.of(context)!.publicationDescriptionTooLong(
                  TripPolicy.maximumDescriptionLength,
                )
              : null,
          onChanged: (_) {
            if (_publicationDescriptionError) {
              setState(
                () => _publicationDescriptionError =
                    _descriptionController.text.trim().length >
                    TripPolicy.maximumDescriptionLength,
              );
            }
          },
          controller: _descriptionController,
          focusColor: _brandColor,
          cursorColor: AppColors.driverText,
          useKeyboardRevealTarget: true,
          keyboardRevealVisibilityPadding: fieldRevealVisibilityPadding,
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    final l10n = AppLocalizations.of(context)!;

    return RoutePreviewSkeleton(
      key: const ValueKey('skeleton'),
      origin: widget.origin,
      destination: widget.destination,
      isDriver: true,
      isRegularRide: _isRegularRide,
      isStopsView: _isStopsView,
      route: _routeWithStops?.route,
      weekDays: _weekDays,
      selectedDays: _selectedDays,
      dateText: DateFormatters.getDisplayDate(context, _selectedDateTime),
      timeText: _selectedTime,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimens.gapXl),
          SectionDivider(title: l10n.rideDetails, showSkeleton: true),
          const SizedBox(height: AppDimens.gapLg),
          SkeletonFieldHint(
            text: l10n.chooseCar,
            trailing: ShimmerPlaceholder(
              child: Text(
                '${_carInitData?.myCars.length ?? 0}/${CarSelectorWidget.maxCars}',
                style: AppText.hint,
              ),
            ),
          ),
          CarSelectorWidget(
            isLoading: _isCarsLoading,
            showSkeleton: true,
            cars: _carInitData?.myCars ?? const [],
            selectedCarId: _selectedCarId,
            onCarSelected: (_) {},
            onDeleteCarTap: (_) {},
            onAddCarTap: () {},
          ),
          const SizedBox(height: AppDimens.gapXl),
          SkeletonFieldHint(text: l10n.specifyFixedOrPerKilometerPrice),
          RidePriceField(
            controller: _priceController,
            priceType: _priceType,
            onPriceTypeChanged: (_) {},
            focusColor: _brandColor,
            showSkeleton: true,
          ),
          const SizedBox(height: AppDimens.gapMd),
          RideNegotiationToggle(
            value: _negotiationAllowed,
            showSkeleton: true,
          ),
          const SizedBox(height: AppDimens.gapXl),
          SkeletonFieldHint(text: l10n.describeRideDetails),
          RideDescriptionField(
            controller: _descriptionController,
            focusColor: _brandColor,
            cursorColor: AppColors.driverText,
            isEnabled: false,
            showDisabledLock: false,
            showSkeleton: true,
          ),
        ],
      ),
    );
  }
}
