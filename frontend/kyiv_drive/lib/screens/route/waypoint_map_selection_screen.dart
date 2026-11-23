import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/constants/map_bounds.dart';
import '../../core/map/pin_map_layout.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../models/route_model.dart';
import '../../services/map_configuration.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/pin_painter.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_warmup.dart';

class WaypointMapSelectionScreen extends StatefulWidget {
  final RouteModel baseRoute;
  final List<LatLng> existingWaypoints;
  final AddressModel origin;
  final AddressModel destination;
  final int? editingIndex;
  final RouteMapWarmup? tileWarmup;
  final TileProvider Function()? tileProviderFactory;

  const WaypointMapSelectionScreen({
    super.key,
    required this.baseRoute,
    required this.existingWaypoints,
    required this.origin,
    required this.destination,
    this.editingIndex,
    this.tileWarmup,
    this.tileProviderFactory,
  });

  @override
  State<WaypointMapSelectionScreen> createState() =>
      _WaypointMapSelectionScreenState();
}

class _WaypointMapSelectionScreenState extends State<WaypointMapSelectionScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  bool _isMapMoving = false;

  final double _pinHeight = 45.0;

  double _bottomActionExtent(BuildContext context) {
    return AppGradientBottomActionBar.extentOf(context);
  }

  double _pinOffsetFromCenter(BuildContext context) {
    return _bottomActionExtent(context) / 2 + 3;
  }

  Color get _brandColor => AppColors.driver;
  Color get _pinColor => AppColors.driverAccent;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _pinLocation {
    final camera = _mapController.camera;

    final centerX = camera.size.width / 2;
    final centerY = camera.size.height / 2;

    final pinScreenOffset = Offset(
      centerX,
      centerY - _pinOffsetFromCenter(context),
    );

    return camera.screenOffsetToLatLng(pinScreenOffset);
  }

  void _completeSelection() {
    final pinLocation = _pinLocation;
    if (!KyivServiceArea.contains(pinLocation)) {
      NotificationService.showError(
        AppLocalizations.of(context)!.outOfServiceArea,
      );
      return;
    }

    context.pop(pinLocation);
  }

  @override
  Widget build(BuildContext context) {
    final bottomActionExtent = AppGradientBottomActionBar.extentOf(context);

    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;

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
            visibleInsets: PinMapLayout.waypointInsets(
              MediaQuery.viewPaddingOf(context).bottom,
            ),
            options: PinMapLayout.waypoint(
              route: widget.baseRoute.points,
              bottomExtent: bottomActionExtent,
              editingPoint: widget.editingIndex == null
                  ? null
                  : widget.existingWaypoints[widget.editingIndex!],
              onMapEvent: (MapEvent event) {
                if (event.source == MapEventSource.mapController) return;

                if (event is MapEventMoveStart ||
                    event is MapEventMove ||
                    event is MapEventFlingAnimationStart ||
                    event is MapEventFlingAnimation) {
                  if (!_isMapMoving) setState(() => _isMapMoving = true);
                } else if (event is MapEventFlingAnimationEnd ||
                    event is MapEventFlingAnimationNotStarted) {
                  if (_isMapMoving) setState(() => _isMapMoving = false);
                }
              },
            ),
            children: [
              PolylineLayer(
                simplificationTolerance: 0,
                polylines: [
                  Polyline(
                    points: widget.baseRoute.points,
                    strokeWidth: 4.0,
                    color: Colors.white30,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  ...widget.existingWaypoints
                      .asMap()
                      .entries
                      .where((entry) => entry.key != widget.editingIndex)
                      .map((entry) {
                        final int index = entry.key;
                        final wp = entry.value;

                        return Marker(
                          point: wp,
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pinColor.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "${index + 1}",
                                style: AppText.meta.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }),

                  Marker(
                    point: LatLng(widget.origin.lat, widget.origin.lon),
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
                            color: Color(0xFF1C1C1E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.radio_button_checked,
                          color: _pinColor.withValues(alpha: 0.7),
                          size: 23,
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
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 30,
                          ),
                        ],
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
              padding: EdgeInsets.only(bottom: bottomActionExtent),
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
                          holeColor: AppColors.driverPinHole,
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
                onTap: () => context.pop(),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppGradientBottomActionBar(
              middleOpacity: 0.7,
              middleStop: 0.4,
              child: AuthButton(
                text: widget.editingIndex != null
                    ? AppLocalizations.of(context)!.save
                    : AppLocalizations.of(context)!.add,
                color: _brandColor,
                onTap: _completeSelection,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
