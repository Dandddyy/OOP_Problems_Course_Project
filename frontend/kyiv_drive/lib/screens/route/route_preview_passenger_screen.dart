import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/constants/trip_policy.dart';
import '../../core/navigation/route_arguments.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error_codes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../models/route_model.dart';
import '../../models/template_model.dart';
import '../../models/trip_search_model.dart';
import '../../models/trip_search_preferences.dart';
import '../../services/map_api_service.dart';
import '../../services/map_configuration.dart';
import '../../services/template_api_service.dart';
import '../../services/template_save_attempt.dart';
import '../../services/notification_service.dart';
import '../../utils/date_formatters.dart';
import '../../utils/route_card_reveal.dart';
import '../../utils/scroll_visibility.dart';
import '../../utils/trip_publication_validation.dart';
import '../../utils/ukraine_time.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_screen_message.dart';
import '../../widgets/address_widgets.dart';

import '../../widgets/animated_control_lock.dart';
import '../../widgets/animated_field_error.dart';
import '../../widgets/animated_value_text.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/route_preview/ride_date_time_field.dart';
import '../../widgets/route_preview/ride_planning_widgets.dart';
import '../../widgets/route_preview/route_preview_addresses.dart';
import '../../widgets/route_preview/route_preview_footer.dart';
import '../../widgets/route_preview/route_preview_skeleton.dart';
import '../../widgets/route_preview/route_template_action.dart';
import '../../widgets/route_preview/search_priorities_card.dart';
import '../../widgets/dialogs/date_picker_dialog.dart';
import '../../widgets/dialogs/time_picker_dialog.dart';
import '../../widgets/top_bar_widget.dart';
import '../../widgets/map/route_glint_layer.dart';
import '../../widgets/map/route_reveal.dart';
import '../../widgets/map/route_map_surface.dart';

enum _PlanningLayoutProjection {
  current,
  expanded,
  collapsed,
}

class RoutePreviewPassengerScreen extends StatefulWidget {
  final AddressModel origin;
  final AddressModel destination;

  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;
  final bool isFromSavedTemplates;
  final RouteModel? preloadedRoute;

  const RoutePreviewPassengerScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required this.selectedDays,
    this.isFromSavedTemplates = false,
    this.preloadedRoute,
  });

  @override
  State<RoutePreviewPassengerScreen> createState() => _RoutePreviewPassengerScreenState();
}

class _RoutePreviewPassengerScreenState extends State<RoutePreviewPassengerScreen> {
  static const _planningSizeAnimationDuration = Duration(milliseconds: 300);

  double get _planningBlockBottomClearance =>
      AppBottomActionBar.standardButtonExtentOf(context) +
      AppDimens.bottomBarShadowClearance +
      AppDimens.gapLg;

  final MapApiService _mapService = MapApiService(ApiClient().dio);
  final TemplateApiService _templateApiService = TemplateApiService(ApiClient().dio);
  final TemplateSaveAttempt _templateSaveAttempt = TemplateSaveAttempt();

  RouteModel? _route;
  bool _isLoading = true;
  bool _showSkeleton = true;
  bool _showServiceBusyMessage = false;
  bool _isPreviewMapReady = false;
  bool _isInitialDataReady = false;
  bool _isSavingRoute = false;
  bool _isRefreshingRoute = false;
  bool _needsRouteRefresh = false;
  bool _isRouteSaved = false;

  final GlobalKey _planningBlockStartKey = GlobalKey();
  final GlobalKey _planningBlockEndKey = GlobalKey();
  final GlobalKey _weekdaysKey = GlobalKey();
  final GlobalKey _planningModeTransitionKey = GlobalKey();
  final GlobalKey _regularPlanningContentKey = GlobalKey();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final GlobalKey _routeCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _planningBlockRevealScheduled = false;
  _PlanningLayoutProjection _scheduledPlanningLayoutProjection =
      _PlanningLayoutProjection.current;

  late bool _isRegularRide;
  late TripSearchPreferences _searchPreferences;
  bool _isEditingPriorities = false;
  bool _isOpeningSearch = false;
  bool _weekdaysError = false;
  TripScheduleIssue? _scheduleError;
  String? _serverDepartureError;
  Timer? _searchErrorRevealTimer;
  String get _selectedTime => _searchPreferences.departureTime;
  TimeOfDay get _departureTime => TimeOfDay(
    hour: _searchPreferences.departureMinutes ~/ 60,
    minute: _searchPreferences.departureMinutes % 60,
  );
  late DateTime _selectedDateTime;
  late List<bool> _selectedDays;

  Color get _brandColor => AppColors.passenger;
  Color get _pinColor => AppColors.passengerAccent;

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

    _isRegularRide = widget.isRegularRide;
    _searchPreferences = TripSearchPreferences(
      departureMinutes: TripSearchPreferences.parseTime(widget.selectedTime),
    );
    _selectedDateTime = widget.selectedDateTime;
    _selectedDays = List.from(widget.selectedDays);
    _isRouteSaved = widget.isFromSavedTemplates;

    if (widget.preloadedRoute != null) {
      _route = widget.preloadedRoute;
      _isLoading = false;
      _showSkeleton = false;
    } else {
      _fetchRoute();
    }
  }

  @override
  void dispose() {
    _searchErrorRevealTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoute() async {
    try {
      await Future.wait<void>([
        _mapService
            .getRoute(
              startLat: widget.origin.lat,
              startLon: widget.origin.lon,
              endLat: widget.destination.lat,
              endLon: widget.destination.lon,
            )
            .then((route) {
              if (!mounted) return;
              setState(() => _route = route);
            }),
        Future<void>.delayed(AppDurations.minimumScreenLoading),
      ]);

      if (!mounted) return;

      setState(() {
        _isInitialDataReady = true;
        _finishPreviewLoadingIfReady();
      });
    } catch (e) {
      if (!mounted) return;
      if (isServiceBusyError(e)) {
        setState(() {
          _showServiceBusyMessage = true;
          _isLoading = false;
        });
        return;
      }
      context.pop();
      NotificationService.showError(e);
    }
  }

  Future<void> _retryRoute() async {
    if (_isLoading || !_showServiceBusyMessage) return;
    setState(() {
      _isLoading = true;
      _showSkeleton = true;
    });
    await _fetchRoute();
  }

  void _schedulePlanningBlockReveal({
    _PlanningLayoutProjection projection = _PlanningLayoutProjection.current,
  }) {
    _searchErrorRevealTimer?.cancel();
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
        unawaited(
          _revealPlanningBlockIfNeeded(projection: projection),
        );
      }
    });
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
    if (!mounted || _route == null || _isPreviewMapReady) return;
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

  Future<void> _revealPlanningBlockIfNeeded({
    _PlanningLayoutProjection projection = _PlanningLayoutProjection.current,
    GlobalKey? errorKey,
  }) async {
    if (!_scrollController.hasClients) return;

    final planningStartRenderObject = (errorKey ?? _planningBlockStartKey)
        .currentContext
        ?.findRenderObject();
    final planningEndRenderObject = (errorKey ?? _planningBlockEndKey)
        .currentContext
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
    var projectedScrollExtentDelta = 0.0;
    if (projection == _PlanningLayoutProjection.expanded ||
        projection == _PlanningLayoutProjection.collapsed) {
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
        projectedBottomDelta =
            targetTransitionHeight - currentTransitionHeight;
        projectedScrollExtentDelta = projectedBottomDelta;
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
      viewportRect.bottom - _planningBlockBottomClearance,
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
      position.maxScrollExtent + projectedScrollExtentDelta,
    );
    final targetOffset = (position.pixels + scrollDelta)
        .clamp(position.minScrollExtent, projectedMaxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 0.5) return;

    if (errorKey != null && MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(targetOffset);
      return;
    }
    await _scrollController.animateTo(
      targetOffset,
      duration: _planningSizeAnimationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _setPlanningMode({required bool isRegularRide}) {
    if (_isRegularRide == isRegularRide) return;

    setState(() {
      _isRegularRide = isRegularRide;
      _searchPreferences = _searchPreferences.forRegularRide(isRegularRide);
      if (!isRegularRide) _weekdaysError = false;
      _revalidateVisibleScheduleError();
    });

    _schedulePlanningBlockReveal(
      projection: isRegularRide
          ? _PlanningLayoutProjection.expanded
          : _PlanningLayoutProjection.collapsed,
    );
  }

  TripScheduleIssue? _currentScheduleIssue() => validateTripSchedule(
    date: _selectedDateTime,
    time: _departureTime,
    isRegular: _isRegularRide,
    selectedDays: _selectedDays,
  );

  void _revalidateVisibleScheduleError() {
    if (_scheduleError != null) {
      _serverDepartureError = null;
      _scheduleError = _currentScheduleIssue();
    }
  }

  GlobalKey? get _firstSearchErrorKey => _weekdaysError
      ? _weekdaysKey
      : _scheduleError != null
      ? _planningBlockEndKey
      : null;

  void _revealSearchError(GlobalKey key) {
    _searchErrorRevealTimer?.cancel();

    void reveal() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && key == _firstSearchErrorKey) {
          unawaited(_revealPlanningBlockIfNeeded(errorKey: key));
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    if (key == _planningBlockEndKey &&
        !MediaQuery.disableAnimationsOf(context)) {
      // Include the expanded error text when measuring the date and time field.
      _searchErrorRevealTimer = Timer(AppDurations.fast, reveal);
    } else {
      reveal();
    }
  }

  Future<void> _findRide() async {
    final route = _route;
    if (_isEditingPriorities || _isOpeningSearch || route == null) return;
    setState(() {
      _weekdaysError = _isRegularRide && !_selectedDays.contains(true);
      _serverDepartureError = null;
      _scheduleError = _currentScheduleIssue();
    });
    final errorKey = _firstSearchErrorKey;
    if (errorKey != null) {
      _revealSearchError(errorKey);
      return;
    }
    final request = TripSearchRequestModel.fromPlanning(
      originLat: widget.origin.lat,
      originLon: widget.origin.lon,
      destinationLat: widget.destination.lat,
      destinationLon: widget.destination.lon,
      date: _selectedDateTime,
      isRegularRide: _isRegularRide,
      selectedDays: _selectedDays,
      preferences: _searchPreferences,
      routeDurationSeconds: route.durationSeconds,
    );
    setState(() => _isOpeningSearch = true);
    try {
      final departureError = await context.push<String>(
        '/trip-search-results',
        extra: TripSearchResultsRouteArgs(request: request),
      );
      if (!mounted || departureError == null) return;
      setState(() {
        _scheduleError = TripScheduleIssue.departureInPast;
        _serverDepartureError = departureError;
      });
      _revealSearchError(_planningBlockEndKey);
    } finally {
      if (mounted) setState(() => _isOpeningSearch = false);
    }
  }

  Rect? _prioritiesVisibleViewport() {
    final viewport = _scrollViewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return null;
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    return Rect.fromLTRB(
      bounds.left,
      bounds.top +
          AppTopBarOverlayLayout.contentInsetOf(_scrollViewportKey.currentContext!),
      bounds.right,
      bounds.bottom - _planningBlockBottomClearance,
    );
  }

  Widget _buildSearchPriorities({bool skeleton = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: AppDimens.gap2xl),
      SectionDivider(
        title: AppLocalizations.of(context)!.searchPriorities,
        showSkeleton: skeleton,
      ),
      const SizedBox(height: AppDimens.gapLg),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.gapSm,
          0,
          AppDimens.gapSm,
          AppDimens.gapLg,
        ),
        child: RoutePreviewHint(
          AppLocalizations.of(context)!.searchTimePreferencesHint,
          showSkeleton: skeleton,
        ),
      ),
      SearchPrioritiesCard(
        showSkeleton: skeleton,
        value: _searchPreferences,
        isRegularRide: _isRegularRide,
        routeDurationSeconds: _route?.durationSeconds ?? 1800,
        visibleViewport: skeleton ? null : _prioritiesVisibleViewport,
        onChanged: (value) {
          if (skeleton) return;
          setState(() {
            final departureChanged =
                _searchPreferences.departureMinutes != value.departureMinutes;
            _searchPreferences = value;
            if (departureChanged) _revalidateVisibleScheduleError();
          });
        },
        onEditingChanged: skeleton
            ? null
            : (editing) {
                setState(() => _isEditingPriorities = editing);
              },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final showBottomBar = !_isLoading && _route != null;
    final reserveBottomBar = _showSkeleton || _route != null;
    final isRetryTransition = _isLoading && _showServiceBusyMessage;
    final bottomActionBarExtent = AppBottomActionBar.standardButtonExtentOf(
      context,
    );
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: reserveBottomBar
          ? RoutePreviewBottomAction(
              showAction: showBottomBar,
              showSkeleton: _showSkeleton,
              visible: !_showServiceBusyMessage || isRetryTransition,
              fadeInOnMount: isRetryTransition,
              action: AuthButton(
                text: AppLocalizations.of(context)!.findCompanion,
                color: _brandColor,
                onTap:
                    _isEditingPriorities ||
                        _isOpeningSearch ||
                        _isRefreshingRoute ||
                        _isSavingRoute
                    ? null
                    : _findRide,
              ),
            )
          : null,
      body: AppTopBarOverlayLayout(
        title: AppLocalizations.of(context)!.planingTrip,
        leadingIcon: Icons.close_rounded,
        onLeadingTap: () => context.pop(),
        bodyBuilder: (context, topInset) {
          final padding = EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            topInset,
            AppDimens.pagePadding,
            bottomActionBarExtent +
                AppDimens.pagePadding +
                AppDimens.bottomBarShadowClearance,
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
            content: _buildPreviewContent(context, padding),
            error: _showServiceBusyMessage
                ? MediaQuery(
                    data: mediaQuery,
                    child: AppScreenMessage.serviceBusy(
                      context: context,
                      topInset: topInset,
                      onRetry: _retryRoute,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context, EdgeInsets padding) {
    if (_route == null) return const SizedBox.shrink();

    return AppScrollbar(
      controller: _scrollController,
      mainAxisMargin: 0,
      padding: EdgeInsets.only(
        top: AppTopBarOverlayLayout.contentInsetOf(context),
        bottom: padding.bottom,
        right: AppScrollbar.screenRightInsetOf(context),
      ),
      child: ListView(
        key: _scrollViewportKey,
        controller: _scrollController,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        children: [
          Column(
            key: const ValueKey('loaded_content'),
            children: [
              _buildUnifiedRouteCard(),
              const SizedBox(height: AppDimens.gap2xl),
              SectionDivider(
                key: _planningBlockStartKey,
                title: AppLocalizations.of(context)!.rideDetails,
              ),
              const SizedBox(height: AppDimens.gapLg),
              AnimatedControlLock(
                isEnabled: !_isEditingPriorities,
                child: _buildPlanningSection(),
              ),
              _buildSearchPriorities(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedRouteCard() {
    final route = _route!;
    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;

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
            RoutePreviewMapFrame(
              child: RepaintBoundary(
                child: RouteMapSurface(
                  key: const ValueKey('passenger-preview-map'),
                  url: mapUrlTemplate,
                  accessToken: mapAccessToken,
                  revealWithParent: _isLoading,
                  onPresented: _handlePreviewMapPresented,
                  options: MapOptions(
                    backgroundColor: AppColors.background,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(route.points),
                      padding: const EdgeInsets.all(36.0),
                    ),
                  ),
                  children: [
                    RouteReveal(
                      points: route.points,
                      revision: route,
                      ready: !_isLoading && !_showSkeleton,
                      updateCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(route.points),
                        padding: const EdgeInsets.all(36),
                      ),
                      children: [
                        const RoutePolylineLayer(
                          color: AppColors.passengerRouteLine,
                        ),
                        RouteGlintLayer(
                          points: route.points,
                          color: AppColors.passengerRouteLine,
                          enabled:
                              !_isLoading &&
                              !_showSkeleton &&
                              !_needsRouteRefresh &&
                              !_isRefreshingRoute,
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
                                          color: AppColors.background,
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
              durationSeconds: route.durationSeconds,
              distanceMeters: route.distanceMeters,
              action: RouteTemplateAction(
                refreshRequired: _needsRouteRefresh,
                isSaving: _isSavingRoute,
                isRefreshing: _isRefreshingRoute,
                isSaved: _isRouteSaved,
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
    if (_isSavingRoute ||
        _isRefreshingRoute ||
        _isRouteSaved ||
        _needsRouteRefresh) {
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
          routePolyline: _route!.polyline,
          totalDurationSeconds: _route!.durationSeconds,
          totalDistanceMeters: _route!.distanceMeters,
        ),
        stops: const [],
      );

      await Future.wait([
        _templateApiService.createTemplate(templateRequest),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);

      if (!mounted) return;
      setState(() {
        _isSavingRoute = false;
        _isRouteSaved = true;
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
        bottomClearance: _planningBlockBottomClearance,
      );
    }
    NotificationService.showError(error);
  }

  Future<void> _refreshRoute() async {
    if (_isRefreshingRoute || _isSavingRoute || !_needsRouteRefresh) return;

    setState(() => _isRefreshingRoute = true);
    try {
      final results = await Future.wait([
        _mapService.getRoute(
          startLat: widget.origin.lat,
          startLon: widget.origin.lon,
          endLat: widget.destination.lat,
          endLon: widget.destination.lon,
        ),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);
      if (!mounted) return;

      setState(() {
        _route = results[0] as RouteModel;
        _isRefreshingRoute = false;
        _needsRouteRefresh = false;
        _isRouteSaved = false;
        _templateSaveAttempt.reset();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRefreshingRoute = false);
      _handleRouteError(error);
    }
  }

  Future<void> _pickDepartureDate() async {
    _schedulePlanningBlockReveal();
    final today = UkraineTime.today();
    final pickedDate = await AppDatePickerExtension.showDatePicker(
      context,
      brandColor: _brandColor,
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
    );
    if (!mounted || pickedDate == null) return;
    setState(() {
      _selectedDateTime = pickedDate;
      _revalidateVisibleScheduleError();
    });
  }

  Future<void> _pickDepartureTime() async {
    _schedulePlanningBlockReveal();
    final pickedTime = await AppTimePicker.showTimePicker(
      context,
      brandColor: _brandColor,
      initialTime: _departureTime,
    );
    if (!mounted || pickedTime == null) return;
    setState(() {
      _searchPreferences = _searchPreferences.withDeparture(
        pickedTime.hour * 60 + pickedTime.minute,
      );
      _revalidateVisibleScheduleError();
    });
  }

  String? _scheduleErrorMessage(AppLocalizations localizations) =>
      switch (_scheduleError) {
        TripScheduleIssue.nonexistentTime =>
          localizations.publicationNonexistentTime,
        TripScheduleIssue.departureInPast =>
          _serverDepartureError ?? localizations.publicationDepartureInPast,
        TripScheduleIssue.unselectedWeekday =>
          localizations.publicationDateNotSelectedWeekday,
        null => null,
      };

  Widget _buildPlanningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              key: _weekdaysKey,
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
                WeekDaysSelector(
                  weekDays: _weekDays,
                  selectedDays: _selectedDays,
                  activeColor: _brandColor,
                  hasError: _weekdaysError,
                  onDayTapped: (index) {
                    setState(() {
                      _selectedDays[index] = !_selectedDays[index];
                      if (_weekdaysError && _selectedDays.contains(true)) {
                        _weekdaysError = false;
                      }
                      _revalidateVisibleScheduleError();
                    });
                  },
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
              key: const ValueKey('passenger-schedule-field'),
              dateText: DateFormatters.getDisplayDate(context, _selectedDateTime),
              timeText: _selectedTime,
              hasError: _scheduleError != null,
              onDateTap: _pickDepartureDate,
              onTimeTap: _pickDepartureTime,
            ),
            AnimatedFieldError(
              errorText: _scheduleErrorMessage(AppLocalizations.of(context)!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return RoutePreviewSkeleton(
      key: const ValueKey('skeleton'),
      origin: widget.origin,
      destination: widget.destination,
      isDriver: false,
      isRegularRide: _isRegularRide,
      route: _route,
      weekDays: _weekDays,
      selectedDays: _selectedDays,
      dateText: DateFormatters.getDisplayDate(context, _selectedDateTime),
      timeText: _selectedTime,
      details: _buildSearchPriorities(skeleton: true),
    );
  }
}
