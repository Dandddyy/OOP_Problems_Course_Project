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
import '../../services/location_service.dart';
import '../../services/map_api_service.dart';
import '../../services/map_configuration.dart';
import '../../services/notification_service.dart';
import '../../services/user_session.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/animated_control_lock.dart';
import '../../widgets/animated_value_switcher.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/pin_painter.dart';
import '../../widgets/address_widgets.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_warmup.dart';

class MapSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final Future<LatLng?>? userLocation;
  final RouteMapWarmup? tileWarmup;
  final TileProvider Function()? tileProviderFactory;

  final AddressModel? knownOrigin;
  final AddressModel? knownDestination;
  final bool isSelectingDestination;

  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;

  const MapSelectionScreen({
    super.key,
    this.initialLocation,
    this.userLocation,
    this.tileWarmup,
    this.tileProviderFactory,
    this.knownOrigin,
    this.knownDestination,
    this.isSelectingDestination = true,
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required this.selectedDays,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final MapApiService _mapApiService = MapApiService(ApiClient().dio);

  Timer? _debounceTimer;
  int _fetchId = 0;

  AddressModel? _selectedAddressModel;

  String _currentAddress = "";
  String? _currentSubtitle;
  bool _isAddressLoading = true;
  bool _isMapMoving = false;
  bool _isCompleting = false;
  bool _isLocating = false;

  LatLng? _userLocation;

  final double _currentPinBottomOffset = 160.0;
  double get _currentPinOffsetFromCenter => PinMapLayout.addressPinOffset;
  final double _pinHeight = 45.0;

  late final LatLng _initialPinLocation;

  AnimationController? _mapMoveController;

  bool get _isDriver => UserSession().currentMode == AppMode.driver;
  Color get _brandColor => _isDriver ? AppColors.driver : AppColors.passenger;
  Color get _pinColor =>
      _isDriver ? AppColors.driverAccent : AppColors.passengerAccent;
  Color get _pinHoleColor =>
      _isDriver ? AppColors.driverPinHole : AppColors.passengerPinHole;

  @override
  void initState() {
    super.initState();
    _initialPinLocation = widget.initialLocation ?? PinMapLayout.kyiv;
  }

  Future<void> _fetchSilentGps() async {
    if (_isLocating || _isCompleting) return;
    _isLocating = true;

    try {
      final inherited = widget.userLocation;
      final LatLng? point;
      if (inherited != null) {
        point = await inherited;
      } else {
        final pos = await LocationService.getStartupLocation();
        point = LatLng(pos.latitude, pos.longitude);
      }
      if (!mounted || _isCompleting) return;

      setState(() {
        _userLocation = point;
      });
    } catch (_) {
      // A silent marker lookup must not prompt for permissions or show errors.
    } finally {
      _isLocating = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapMoveController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _pinLocation {
    final camera = _mapController.camera;
    final centerX = camera.size.width / 2;
    final centerY = camera.size.height / 2;
    final pinScreenOffset = Offset(
      centerX,
      centerY - _currentPinOffsetFromCenter,
    );
    return camera.screenOffsetToLatLng(pinScreenOffset);
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _debounceTimer?.cancel();
    _fetchId++;

    setState(() {
      _isMapMoving = true;
      _isAddressLoading = true;
      _selectedAddressModel = null;
    });

    final camera = _mapController.camera;
    final globalPoint = camera.projectAtZoom(destLocation, destZoom);

    final newGlobalPoint = Offset(
      globalPoint.dx,
      globalPoint.dy + _currentPinOffsetFromCenter,
    );
    final targetCenter = camera.unprojectAtZoom(newGlobalPoint, destZoom);

    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: targetCenter.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: targetCenter.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    _mapMoveController?.dispose();

    _mapMoveController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: _mapMoveController!,
      curve: Curves.easeInOutCubic,
    );

    _mapMoveController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _isMapMoving = false;
          });
          _onMapStoppedMoving();
        }
      }
    });

    _mapMoveController!.forward();
  }

  Future<void> _fetchAddressForPin() async {
    final targetLatLng = _pinLocation;

    _fetchId++;
    final int currentFetchId = _fetchId;

    if (!KyivServiceArea.contains(targetLatLng)) {
      if (!mounted || currentFetchId != _fetchId || _isMapMoving) return;

      setState(() {
        _selectedAddressModel = null;
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
        if (addressData.shortAddress != null &&
            addressData.shortAddress!.isNotEmpty) {
          _selectedAddressModel = addressData;
          _currentAddress = addressData.shortAddress!;
          _currentSubtitle = addressData.subtitle;
        } else {
          _selectedAddressModel = null;
          _currentAddress = AppLocalizations.of(context)!.unknownLocation;
          _currentSubtitle = null;
        }
        _isAddressLoading = false;
      });
    } catch (e) {
      if (!mounted || currentFetchId != _fetchId || _isMapMoving) return;

      setState(() {
        _selectedAddressModel = null;
        _currentAddress = AppLocalizations.of(context)!.unknownLocation;
        _isAddressLoading = false;
      });
    }
  }

  Future<void> _moveToCurrentLocation({bool showErrors = true}) async {
    if (_isLocating || _isCompleting) return;
    _isLocating = true;

    try {
      final position = await LocationService.getCurrentLocation(
        requestPermission: showErrors,
      );

      if (!mounted || _isCompleting) return;

      final newLatLng = LatLng(position.latitude, position.longitude);

      if (!KyivServiceArea.contains(newLatLng)) {
        if (showErrors && mounted) {
          NotificationService.showError(
            AppLocalizations.of(context)!.outOfServiceArea,
          );
        }
        return;
      }

      setState(() {
        _userLocation = newLatLng;
      });

      _animatedMapMove(newLatLng, 16.0);
    } catch (e) {
      if (!showErrors || !mounted || _isCompleting) return;

      if (e is AppLocationDisabledException) {
        final shouldOpenSettings = await AppDialogs.show(
          context,
          title: AppLocalizations.of(context)!.locationDisabledTitle,
          content: AppLocalizations.of(context)!.locationDisabledContent,
          primaryButtonText: AppLocalizations.of(context)!.enableButton,
          icon: Icons.location_off_rounded,
          brandColor: _brandColor,
          barrierDismissible: true,
        );

        if (shouldOpenSettings != true || !mounted || _isCompleting) {
          return;
        }

        final opened = await LocationService.openSystemLocationSettings();

        debugPrint('openSystemLocationSettings result: $opened');
      } else if (e is AppLocationPermanentException) {
        final shouldOpenSettings = await AppDialogs.show(
          context,
          title: AppLocalizations.of(context)!.locationPermissionDeniedTitle,
          content: AppLocalizations.of(
            context,
          )!.locationPermissionDeniedContent,
          primaryButtonText: AppLocalizations.of(context)!.settingsButton,
          icon: Icons.location_off_rounded,
          brandColor: _brandColor,
          barrierDismissible: true,
        );

        if (shouldOpenSettings != true || !mounted || _isCompleting) {
          return;
        }

        final opened = await LocationService.openAppPermissionSettings();

        debugPrint('openAppPermissionSettings result: $opened');
      } else {
        NotificationService.showError(
          AppLocalizations.of(context)!.locationUnknownErrorToast,
        );
      }
    } finally {
      _isLocating = false;
    }
  }

  void _onMapStoppedMoving() {
    _debounceTimer?.cancel();
    _fetchId++;
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _fetchAddressForPin();
    });
  }

  void _onDonePressed() {
    if (_isCompleting || _isMapMoving || _selectedAddressModel == null) {
      return;
    }

    final selected = _selectedAddressModel!;

    final AddressModel? origin = widget.isSelectingDestination
        ? widget.knownOrigin
        : selected;

    final AddressModel? destination = widget.isSelectingDestination
        ? selected
        : widget.knownDestination;

    if (origin != null && destination != null) {
      final isSameAddress =
          origin.lat == destination.lat && origin.lon == destination.lon;

      if (isSameAddress) {
        NotificationService.showError(
          AppLocalizations.of(context)!.selectDifferentLocations,
        );

        return;
      }
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      if (origin != null && destination != null) {
        if (_isDriver) {
          context.pushReplacement(
            '/route-preview-driver',
            extra: DriverRoutePreviewArgs(
              origin: origin,
              destination: destination,
              isRegularRide: widget.isRegularRide,
              selectedDateTime: widget.selectedDateTime,
              selectedTime: widget.selectedTime,
              selectedDays: widget.selectedDays,
            ),
          );
        } else {
          context.pushReplacement(
            '/route-preview-passenger',
            extra: PassengerRoutePreviewArgs(
              origin: origin,
              destination: destination,
              isRegularRide: widget.isRegularRide,
              selectedDateTime: widget.selectedDateTime,
              selectedTime: widget.selectedTime,
              selectedDays: widget.selectedDays,
            ),
          );
        }
      } else {
        context.pop(selected);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }

      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;
    final addressSubtitle = _currentSubtitle ?? '';

    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          RouteMapSurface(
            mapController: _mapController,
            url: mapAccessToken == null ? null : mapUrlTemplate,
            accessToken: mapAccessToken,
            maxNativeZoom: 18,
            maxZoom: 20,
            warmup: widget.tileWarmup,
            tileProviderFactory: widget.tileProviderFactory,
            visibleInsets: PinMapLayout.addressInsets(
              MediaQuery.viewPaddingOf(context).bottom,
            ),
            options: PinMapLayout.address(
              location: _initialPinLocation,
              onMapReady: () {
                _onMapStoppedMoving();
                _fetchSilentGps();
              },
              onMapEvent: (MapEvent event) {
                if (event.source == MapEventSource.mapController) return;

                if (event is MapEventMoveStart ||
                    event is MapEventMove ||
                    event is MapEventFlingAnimationStart ||
                    event is MapEventFlingAnimation) {
                  _debounceTimer?.cancel();
                  _fetchId++;
                  if (!_isMapMoving) {
                    setState(() {
                      _isMapMoving = true;
                      _isAddressLoading = true;
                      _selectedAddressModel = null;
                    });
                  }
                } else if (event is MapEventFlingAnimationEnd ||
                    event is MapEventFlingAnimationNotStarted) {
                  if (_isMapMoving) {
                    setState(() => _isMapMoving = false);
                    _onMapStoppedMoving();
                  }
                }
              },
            ),
            children: [
              if (_userLocation != null)
                MarkerLayer(
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
                ),
            ],
          ),

          Center(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(bottom: _currentPinBottomOffset),
              child: Transform.translate(
                offset: Offset(0, -_pinHeight / 2),
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
                        size: Size(32, _pinHeight),
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
          ),

          Positioned(
            top: 0,
            left: AppDimens.pagePadding,
            child: AppTopSafeArea(
              child: AppSquareButton(
                icon: Icons.close_rounded,
                onTap: _isCompleting ? null : () => context.pop(),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: AppDimens.pagePadding,
                    bottom: AppDimens.pagePadding,
                  ),
                  child: AnimatedControlLock(
                    key: const ValueKey('map-selection-gps-lock'),
                    isEnabled: !_isCompleting,
                    child: AppSquareButton(
                      icon: Icons.gps_fixed_rounded,
                      iconColor: AppColors.iconSecondary,
                      pressedScale: 0.95,
                      highlightOpacity: 0.03,
                      onTap: _isCompleting
                          ? null
                          : () => _moveToCurrentLocation(showErrors: true),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.large),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 28,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: AppBottomSafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimens.gapXl,
                        left: AppDimens.authPagePadding,
                        right: AppDimens.authPagePadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              minHeight: AppDimens.controlHeight,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const CustomOriginIcon(
                                  color: AppColors.iconSecondary,
                                  size: 28.0,
                                ),
                                const SizedBox(width: AppDimens.gapLg),
                                Expanded(
                                  child: AnimatedValueSwitcher.withSkeleton(
                                    alignment: AlignmentDirectional.centerStart,
                                    showSkeleton: _isAddressLoading,
                                    skeleton: const Column(
                                      key: ValueKey("loading"),
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShimmerBlock(
                                          width: 240,
                                          height: 20,
                                          borderRadius:
                                              AppShimmer.textBorderRadius,
                                        ),
                                        SizedBox(height: AppDimens.gapSm),
                                        ShimmerBlock(width: 140, height: 14),
                                      ],
                                    ),
                                    child: Column(
                                      key: ValueKey((
                                        _currentAddress,
                                        addressSubtitle,
                                      )),
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentAddress,
                                          style: AppText.modalTitle.copyWith(
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (addressSubtitle.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            addressSubtitle,
                                            style: AppText.bodySecondary
                                                .copyWith(
                                                  color: Colors.white54,
                                                  height: 1.2,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimens.gapXl),
                          AuthButton(
                            text: AppLocalizations.of(context)!.done,
                            color: _brandColor,
                            onTap:
                                !_isCompleting &&
                                    !_isMapMoving &&
                                    _selectedAddressModel != null
                                ? _onDonePressed
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
