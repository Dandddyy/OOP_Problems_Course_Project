import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/constants/map_bounds.dart';
import '../../core/map/pin_map_layout.dart';
import '../../core/navigation/route_arguments.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../services/home_map_startup.dart';
import '../../services/map_api_service.dart';
import '../../services/map_configuration.dart';
import '../../utils/ukraine_time.dart';
import '../../widgets/animated_touch_templates.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_session.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/address_widgets.dart';
import '../../widgets/pin_painter.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_warmup.dart';

class HomeScreen extends StatefulWidget {
  final HomeMapStart? initialMap;
  final bool startupVisible;
  final VoidCallback? onStartupLocationRequested;
  final VoidCallback? onMapPresented;
  final TileProvider Function()? tileProviderFactory;

  const HomeScreen({
    super.key,
    this.initialMap,
    this.startupVisible = true,
    this.onStartupLocationRequested,
    this.onMapPresented,
    this.tileProviderFactory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  final MapApiService _mapApiService = MapApiService(ApiClient().dio);
  Timer? _debounceTimer;
  int _fetchId = 0;

  AddressModel? _originAddressModel;

  String _currentAddress = "";
  String? _currentSubtitle;

  bool _isAddressLoading = true;
  bool _isAddressFieldPressed = false;

  bool _isLocating = false;
  bool _entryActionsStarted = false;
  bool _userMovedMap = false;
  bool _mapPresented = false;
  final _selectionWarmup = RouteMapWarmupController();

  LatLng? _userLocation;

  static const double _pinBottomPadding = 224.0;

  bool _isMapMoving = false;

  final bool _isRegularRide = false;
  final String _selectedTime = "14:30";
  late final DateTime _selectedDateTime;
  final List<bool> _selectedDays = [true, true, true, true, true, false, false];

  AnimationController? _mapMoveController;

  bool get _isDriver => UserSession().currentMode == AppMode.driver;
  AddressModel? get _availableOrigin =>
      _isAddressLoading ? null : _originAddressModel;

  Color get _brandColor => _isDriver ? AppColors.driver : AppColors.passenger;
  Color get _pinColor => _isDriver ? AppColors.driverAccent : AppColors.passengerAccent;
  Color get _pinHoleColor =>
      _isDriver ? AppColors.driverPinHole : AppColors.passengerPinHole;
  Color get _addressTextColor => _isDriver ? AppColors.driverText : AppColors.passengerText;
  Color get _iconColor => _isDriver ? AppColors.driverAccent : AppColors.passengerAccent;

  static const double pinWidth = 32.0;
  static const double pinHeight = 45.0;

  @override
  void initState() {
    super.initState();

    _selectedDateTime = UkraineTime.today();
    _userLocation = widget.initialMap?.location;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _onMapStoppedMoving();
      _startEntryActions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A nested destination (for example a profile deep link) can cover home
    // before startup finishes. Permission dialogs belong to visible home only.
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startEntryActions();
      });
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.startupVisible && widget.startupVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startEntryActions();
      });
    }
  }

  void _startEntryActions() {
    if (_entryActionsStarted ||
        !widget.startupVisible ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _entryActionsStarted = true;
    _checkWelcomeMessage();
    _checkMapConfig();
    if (widget.initialMap == null ||
        widget.initialMap!.requestPermissionOnHome) {
      widget.onStartupLocationRequested?.call();
      _updateUserLocation(moveMap: true, isAppStart: true);
    }
  }

  @override
  void dispose() {
    _selectionWarmup.dispose();
    _debounceTimer?.cancel();
    _mapMoveController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _checkWelcomeMessage() {
    if (UserSession().consumeWelcomeEvent) {
      final name = UserSession().name ?? "";
      NotificationService.showInfo(
        AppLocalizations.of(context)!.greeting(name),
        brandColor: _iconColor,
      );
    }
  }

  void _checkMapConfig() {
    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;

    if (mapUrlTemplate == null || mapAccessToken == null) {
      NotificationService.showError(null);
    }
  }

  LatLng get _pinLocation {
    final camera = _mapController.camera;
    final centerX = camera.size.width / 2;
    final centerY = camera.size.height / 2;
    final pinScreenOffset = Offset(centerX, centerY - PinMapLayout.homePinOffset);
    return camera.screenOffsetToLatLng(pinScreenOffset);
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _debounceTimer?.cancel();
    _fetchId++;
    setState(() {
      _isMapMoving = true;
      _isAddressLoading = true;
    });

    final camera = _mapController.camera;
    final globalPoint = camera.projectAtZoom(destLocation, destZoom);
    final newGlobalPoint = Offset(
      globalPoint.dx,
      globalPoint.dy + PinMapLayout.homePinOffset,
    );
    final targetCenter = camera.unprojectAtZoom(newGlobalPoint, destZoom);

    final latTween = Tween<double>(begin: camera.center.latitude, end: targetCenter.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: targetCenter.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    _mapMoveController?.dispose();

    _mapMoveController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    Animation<double> animation = CurvedAnimation(parent: _mapMoveController!, curve: Curves.easeInOutCubic);

    _mapMoveController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        setState(() {
          _isMapMoving = false;
        });
        _onMapStoppedMoving();
      }
    });

    _mapMoveController!.forward();
  }

  Future<void> _updateUserLocation({
    required bool moveMap,
    bool isAppStart = false,
  }) async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
    });

    try {
      final position =
      await LocationService.getCurrentLocation();

      if (!mounted) return;

      final newLatLng = LatLng(position.latitude, position.longitude);
      final bool isInside = KyivServiceArea.contains(newLatLng);

      if (!isInside) {
        if (isAppStart) {
          return;
        } else {
          NotificationService.showError(
              AppLocalizations.of(context)!.outOfServiceArea
          );
          return;
        }
      }

      setState(() {
        _userLocation = newLatLng;
      });

      if (moveMap && (!isAppStart || !_userMovedMap)) {
        _animatedMapMove(newLatLng, 16.0);
      } else {
        _onMapStoppedMoving();
      }

    } catch (e) {
      if (!mounted) return;

      if (isAppStart) return;

      if (e is AppLocationDisabledException) {
        final shouldOpenSettings = await AppDialogs.show(
          context,
          title: AppLocalizations.of(context)!
              .locationDisabledTitle,
          content: AppLocalizations.of(context)!
              .locationDisabledContent,
          primaryButtonText: AppLocalizations.of(context)!
              .enableButton,
          icon: Icons.location_off_rounded,
          brandColor: _brandColor,
          barrierDismissible: true,
        );

        if (shouldOpenSettings != true || !mounted) {
          return;
        }

        final opened =
        await LocationService.openSystemLocationSettings();

        debugPrint(
          'openSystemLocationSettings result: $opened',
        );
      }
      else if (e is AppLocationPermanentException) {
        final shouldOpenSettings = await AppDialogs.show(
          context,
          title: AppLocalizations.of(context)!
              .locationPermissionDeniedTitle,
          content: AppLocalizations.of(context)!
              .locationPermissionDeniedContent,
          primaryButtonText: AppLocalizations.of(context)!
              .settingsButton,
          icon: Icons.location_off_rounded,
          brandColor: _brandColor,
          barrierDismissible: true,
        );

        if (shouldOpenSettings != true || !mounted) {
          return;
        }

        final opened =
        await LocationService.openAppPermissionSettings();

        debugPrint(
          'openAppPermissionSettings result: $opened',
        );
      }
      else if (e is AppLocationDeniedException) {
        NotificationService.showError(AppLocalizations.of(context)!.allowLocationAccessToast);
      }
      else {
        NotificationService.showError(AppLocalizations.of(context)!.locationUnknownErrorToast);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _fetchAddressForPin() async {
    final targetLatLng = _pinLocation;
    _fetchId++;
    final int currentFetchId = _fetchId;

    if (!KyivServiceArea.contains(targetLatLng)) {
      if (!mounted || currentFetchId != _fetchId || _isMapMoving) return;

      setState(() {
        _originAddressModel = null;
        _currentAddress = AppLocalizations.of(context)!.outOfServiceArea;
        _currentSubtitle = null;
        _isAddressLoading = false;
      });
      return;
    }

    try {
      final addressData = await _mapApiService.reverseGeocode(
        lat: targetLatLng.latitude,
        lon: targetLatLng.longitude,
      );

      if (!mounted || currentFetchId != _fetchId || _isMapMoving) return;

      setState(() {
        if (addressData.shortAddress != null && addressData.shortAddress!.isNotEmpty) {
          _originAddressModel = addressData;
          _currentAddress = addressData.shortAddress!;
          _currentSubtitle = addressData.subtitle;
        } else {
          _originAddressModel = null;
          _currentAddress = AppLocalizations.of(context)!.unknownLocation;
          _currentSubtitle = null;
        }
        _isAddressLoading = false;
      });

    } catch (e) {
      if (!mounted || currentFetchId != _fetchId || _isMapMoving) return;

      setState(() {
        _originAddressModel = null;
        _currentAddress = AppLocalizations.of(context)!.unknownLocation;
        _isAddressLoading = false;
      });
    }
  }

  void _onMapStoppedMoving() {
    _debounceTimer?.cancel();
    _fetchId++;
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _fetchAddressForPin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;

    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          RouteMapPreloader(
            controller: _selectionWarmup,
            options: PinMapLayout.address(
              location: _availableOrigin == null
                  ? PinMapLayout.kyiv
                  : LatLng(_availableOrigin!.lat, _availableOrigin!.lon),
            ),
            url: mapUrlTemplate,
            accessToken: mapAccessToken,
            visibleInsets: PinMapLayout.addressInsets(bottomPadding),
            enabled: widget.startupVisible &&
                _mapPresented &&
                !_isMapMoving &&
                _availableOrigin != null,
            tileProviderFactory: widget.tileProviderFactory,
          ),
          _buildMapLayer(
            mapUrlTemplate: mapUrlTemplate,
            mapAccessToken: mapAccessToken,
            safeBottom: bottomPadding,
          ),

          _buildPin(),

          _buildTopBar(),

          _buildBottomPanel(
            bottomPadding: bottomPadding,
          ),
        ],
      ),
    );
  }

  Widget _buildMapLayer({
    required String? mapUrlTemplate,
    required String? mapAccessToken,
    required double safeBottom,
  }) {
    return RouteMapSurface(
      mapController: _mapController,
      url: mapAccessToken == null ? null : mapUrlTemplate,
      accessToken: mapAccessToken,
      maxNativeZoom: 18,
      maxZoom: 20,
      visibleInsets: PinMapLayout.homeInsets(safeBottom),
      tileProviderFactory: widget.tileProviderFactory,
      warmup: widget.initialMap?.tileWarmup,
      onPresented: () {
        if (!_mapPresented) setState(() => _mapPresented = true);
        widget.onMapPresented?.call();
      },
      options: PinMapLayout.home(
        location: widget.initialMap?.location,
        onMapEvent: _handleMapEvent,
      ),
      children: [
        if (_userLocation != null) _buildUserLocationMarker(),
      ],
    );
  }

  void _handleMapEvent(MapEvent event) {
    if (event.source == MapEventSource.mapController) return;

    if (event is MapEventMoveStart ||
        event is MapEventMove ||
        event is MapEventFlingAnimationStart ||
        event is MapEventFlingAnimation) {
      _userMovedMap = true;
      _debounceTimer?.cancel();
      _fetchId++;

      if (!_isMapMoving) {
        setState(() {
          _isMapMoving = true;
          _isAddressLoading = true;
        });
      }
    } else if (event is MapEventFlingAnimationEnd ||
        event is MapEventFlingAnimationNotStarted) {
      if (_isMapMoving) {
        setState(() {
          _isMapMoving = false;
        });
        _onMapStoppedMoving();
      }
    }
  }

  Widget _buildUserLocationMarker() {
    return MarkerLayer(
      markers: [
        Marker(
          point: _userLocation!,
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade400,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: _pinBottomPadding),
        child: Transform.translate(
          offset: const Offset(0, -pinHeight / 2),
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isMapMoving ? 0.5 : 0.9,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    scale: _isMapMoving ? 0.8 : 0.6,
                    child: Container(
                      width: 12,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _pinColor.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _pinColor.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                transform: Matrix4.translationValues(
                  0,
                  _isMapMoving ? -15 : 0,
                  0,
                ),
                child: CustomPaint(
                  size: const Size(pinWidth, pinHeight),
                  painter: PinPainter(
                    color: _pinColor,
                    holeColor: _pinHoleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: AppDimens.pagePadding,
      right: AppDimens.pagePadding,
      child: AppTopSafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppPillButton(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.iconSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!.myRides,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                AppSquareButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: AppDimens.gapMd),
                ListenableBuilder(
                  listenable: UserSession(),
                  builder: (context, _) {
                    return AppAvatarButton(
                      avatarUrl: UserSession().avatarUrl,
                      onTap: () => context.push('/profile'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel({
    required double bottomPadding,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: 0,
      right: 0,
      bottom: _isMapMoving
          ? -(PinMapLayout.homePanelHeight + bottomPadding + 150)
          : 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildGpsButton(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildGpsButton() {
    return Padding(
      padding: const EdgeInsets.only(
        right: AppDimens.pagePadding,
        bottom: AppDimens.gapLg,
      ),
      child: AppSquareButton(
        icon: Icons.gps_fixed_rounded,
        iconColor: AppColors.iconSecondary,
        pressedScale: 0.95,
        highlightOpacity: 0.03,
        onTap: () => _updateUserLocation(
          moveMap: true,
          isAppStart: false,
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return AppBottomSheetSurface(
      child: AppBottomSafeArea(
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppDimens.gapXl,
            left: AppDimens.pagePadding,
            right: AppDimens.pagePadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAddressCard(),
              const SizedBox(height: AppDimens.gapMd),
              _buildSavedTemplatesButton(),
              const SizedBox(height: AppDimens.gapXl),
              _buildAdPlaceholder(),
            ],
          ),
        ),
      ),
    );
  }

  void _setAddressFieldPressed(bool pressed) {
    if (_isAddressFieldPressed == pressed) return;
    setState(() => _isAddressFieldPressed = pressed);
  }

  Widget _buildAddressCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.formControlBr,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.formControlBr,
        child: Column(
          children: [
            AddressRow(
              iconWidget: CustomOriginIcon(color: _iconColor),
              text: _currentAddress,
              subtitle: _currentSubtitle,
              textColor: _addressTextColor,
              isLoading: _isAddressLoading,
              onTap: () => _openAddressSearch(focusOnDestination: false),
              onPressedChanged: _setAddressFieldPressed,
              pressedBackgroundColor: const Color(0x08FFFFFF),
            ),
            AnimatedContainer(
              duration: Duration(
                milliseconds: _isAddressFieldPressed ? 150 : 300,
              ),
              curve: Curves.easeOutCubic,
              height: 1,
              color: Colors.white10,
              margin: _isAddressFieldPressed
                  ? EdgeInsets.zero
                  : const EdgeInsets.only(
                      left: 52,
                      right: AppDimens.gapLg,
                    ),
            ),
            AddressRow(
              iconWidget: const Icon(
                Icons.location_on,
                color: AppColors.iconSecondary,
                size: 26,
              ),
              text: AppLocalizations.of(context)!.whereGoing,
              textColor: Colors.white54,
              trailing: const Icon(
                Icons.map_rounded,
                color: AppColors.iconSecondary,
                size: 24,
              ),
              onTap: () => _openAddressSearch(focusOnDestination: true),
              onTrailingTap: _openDestinationMapSelection,
              onPressedChanged: _setAddressFieldPressed,
              pressedBackgroundColor: const Color(0x08FFFFFF),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddressSearch({
    required bool focusOnDestination,
    AddressModel? initialOrigin,
  }) {
    context.push(
      '/address-search',
      extra: AddressSearchRouteArgs(
        initialOrigin: initialOrigin ?? _availableOrigin,
        focusOnDestination: focusOnDestination,
        isRegularRide: _isRegularRide,
        selectedDateTime: _selectedDateTime,
        selectedTime: _selectedTime,
        selectedDays: _selectedDays,
      ),
    );
  }

  void _openDestinationMapSelection() {
    final origin = _availableOrigin;
    if (origin == null) {
      _openAddressSearch(
        focusOnDestination: true,
        initialOrigin: null,
      );
      return;
    }

    final warmup = _selectionWarmup.takeFor(
      context: context,
      options: PinMapLayout.address(location: LatLng(origin.lat, origin.lon)),
      url: MapConfiguration().mapUrlTemplate,
      accessToken: MapConfiguration().mapAccessToken,
      visibleInsets: PinMapLayout.addressInsets(
        MediaQuery.viewPaddingOf(context).bottom,
      ),
      tileProviderFactory: widget.tileProviderFactory,
    );
    unawaited(
      context.push(
        '/map-selection',
        extra: MapSelectionRouteArgs(
          tileWarmup: warmup,
          userLocation: _userLocation == null ? null : Future.value(_userLocation),
          initialLocation: LatLng(origin.lat, origin.lon),
          knownOrigin: origin,
          isSelectingDestination: true,
          isRegularRide: _isRegularRide,
          selectedDateTime: _selectedDateTime,
          selectedTime: _selectedTime,
          selectedDays: _selectedDays,
        ),
      ).whenComplete(() => warmup?.dispose()),
    );
  }

  Widget _buildSavedTemplatesButton() {
    return AnimatedTouchItem(
      onTap: _openSavedTemplates,
      normalColor: AppColors.surface,
      pressedColor: AppColors.surfacePressed,
      pressedScale: 0.97,
      borderRadius: AppRadius.formControlBr,
      child: Container(
        height: AppDimens.compactHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              child: Icon(
                Icons.bookmark_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimens.gapLg),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.savedTemplates,
                style: AppText.bodyStrong,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _openSavedTemplates() {
    context.push(
      '/saved-templates',
      extra: SavedTemplatesRouteArgs(
        isRegularRide: _isRegularRide,
        selectedDateTime: _selectedDateTime,
        selectedTime: _selectedTime,
        selectedDays: _selectedDays,
      ),
    );
  }

  Widget _buildAdPlaceholder() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: AppRadius.smallBr,
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Center(
        child: Text(
          "Ad Space (320x50)",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
