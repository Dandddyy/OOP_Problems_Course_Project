import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../models/route_model.dart';
import '../../models/route_with_stops_model.dart';
import '../../services/map_configuration.dart';
import '../../utils/route_formatters.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../widgets/route_preview/route_edit_sheet_header.dart';
import '../../widgets/map/route_reveal.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_tiles.dart';

class StopsEditScreen extends StatefulWidget {
  final RouteModel baseRoute;
  final List<StopOnRouteModel> initialStops;
  final AddressModel origin;
  final AddressModel destination;
  final List<LatLng>? waypoints;

  const StopsEditScreen({
    super.key,
    required this.baseRoute,
    required this.initialStops,
    required this.origin,
    required this.destination,
    this.waypoints,
  });

  @override
  State<StopsEditScreen> createState() => _StopsEditScreenState();
}

class _StopsEditScreenState extends State<StopsEditScreen> {
  static const double _initialSheetSize = RouteEditorMapLayout.initialSheetSize;

  late List<StopOnRouteModel> _editableStops;
  late final List<bool> _initialStopsActiveState;
  bool _isExitDialogOpen = false;

  final Color _activeColor = AppColors.driverAccent;

  @override
  void initState() {
    super.initState();
    _initialStopsActiveState = widget.initialStops.map((s) => s.isActive).toList();
    _editableStops = widget.initialStops.map((s) => StopOnRouteModel(
      stopId: s.stopId,
      name: s.name,
      lat: s.lat,
      lon: s.lon,
      etaSeconds: s.etaSeconds,
      distanceMeters: s.distanceMeters,
      isActive: s.isActive,
    )).toList();
  }

  int get _activeStopsCount => _editableStops.where((s) => s.isActive).length;

  bool get _hasUnsavedChanges {
    for (var index = 0; index < _editableStops.length; index++) {
      if (_editableStops[index].isActive != _initialStopsActiveState[index]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _requestExit() async {
    if (_isExitDialogOpen) return;
    if (!_hasUnsavedChanges) {
      context.pop(null);
      return;
    }

    _isExitDialogOpen = true;
    final action = await AppDialogs.showUnsavedChanges(context);
    _isExitDialogOpen = false;
    if (!mounted) return;

    switch (action) {
      case UnsavedChangesAction.save:
        _saveChanges();
      case UnsavedChangesAction.discard:
        context.pop(null);
      case UnsavedChangesAction.cancel:
      case null:
        break;
    }
  }

  void _saveChanges() => context.pop(_editableStops);

  @override
  Widget build(BuildContext context) {
    return PopScope<List<StopOnRouteModel>>(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final bottomActionExtent = AppGradientBottomActionBar.extentOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    final mapUrlTemplate = MapConfiguration().mapUrlTemplate;
    final mapAccessToken = MapConfiguration().mapAccessToken;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: RouteMapSurface(
              url: mapUrlTemplate,
              accessToken: mapAccessToken,
              maxNativeZoom: 18,
              maxZoom: 20,
              visibleInsets: RouteEditorMapLayout.visibleInsets(screenHeight),
              options: RouteEditorMapLayout.options(
                widget.baseRoute.points,
                screenHeight,
              ),
              children: [
                RouteReveal(
                  points: widget.baseRoute.points,
                  revision: widget.baseRoute,
                  children: [
                    const RoutePolylineLayer(color: Colors.white30),

                    MarkerLayer(
                      markers: [
                        ..._editableStops.map(
                          (stop) => Marker(
                            point: LatLng(stop.lat, stop.lon),
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: RouteRevealMarker(
                              key: ValueKey('stop-reveal-${stop.stopId}'),
                              point: LatLng(stop.lat, stop.lon),
                              fractionHint: widget.baseRoute.distanceMeters > 0
                                  ? stop.distanceMeters /
                                        widget.baseRoute.distanceMeters
                                  : null,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    stop.isActive = !stop.isActive;
                                  });
                                },
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: stop.isActive
                                          ? _activeColor
                                          : Colors.black54,
                                      border: Border.all(
                                        color: stop.isActive
                                            ? Colors.white
                                            : Colors.white38,
                                        width: stop.isActive ? 2.5 : 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (widget.waypoints != null)
                          ...widget.waypoints!.map(
                            (wp) => Marker(
                              point: wp,
                              width: 8,
                              height: 8,
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.driverRouteLine.withValues(
                                    alpha: 0.8,
                                  ),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

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
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Icon(
                                Icons.radio_button_checked,
                                color: _activeColor,
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

          Positioned(
            top: 0,
            left: AppDimens.pagePadding,
            child: AppTopSafeArea(
              child: AppSquareButton(
                icon: Icons.arrow_back_rounded,
                onTap: _requestExit,
              ),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: _initialSheetSize,
            minChildSize: 0.33,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return AppBottomSheetSurface(
                child: AppScrollbar(
                  controller: scrollController,
                  mainAxisMargin: 0,
                  padding: EdgeInsets.only(
                    top: RouteEditSheetHeader.extent +
                        AppDimens.dividerThickness +
                        AppDimens.gapXs,
                    bottom: bottomActionExtent + AppDimens.gapXs,
                  ),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                    SliverAppBar(
                      pinned: true,
                      primary: false,
                      automaticallyImplyLeading: false,
                      backgroundColor: AppColors.background,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      centerTitle: false,
                      titleSpacing: 0,
                      toolbarHeight: RouteEditSheetHeader.extent,
                      title: RouteEditSheetHeader(
                        title: AppLocalizations.of(context)!.stops,
                        counterText: "$_activeStopsCount / ${_editableStops.length}",
                        description: AppLocalizations.of(context)!.markStops,
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(AppDimens.dividerThickness),
                        child: Divider(
                          color: AppColors.borderMuted,
                          height: AppDimens.dividerThickness,
                          thickness: AppDimens.dividerThickness,
                        ),
                      ),
                    ),

                    _editableStops.isEmpty
                        ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: AppDimens.pagePadding,
                          bottom: bottomActionExtent,
                          left: AppDimens.gap2xl,
                          right: AppDimens.gap2xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_off_rounded,
                              color: Colors.white24,
                              size: 56,
                            ),
                            const SizedBox(height: AppDimens.gapLg),
                            Text(
                              AppLocalizations.of(context)!.noStopsFound,
                              style: AppText.bodyStrong.copyWith(
                                color: Colors.white54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context)!.noStopsDescription,
                              style: AppText.bodySecondary.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    )
                        : SliverPadding(
                      padding: EdgeInsets.only(
                        bottom: bottomActionExtent,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final stop = _editableStops[index];
                            return _buildStopListItem(stop, index);
                          },
                          childCount: _editableStops.length,
                        ),
                      ),
                    )
                    ],
                  ),
                ),
              );
            },
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppGradientBottomActionBar(
              child: AuthButton(
                onTap: _saveChanges,
                text: AppLocalizations.of(context)!.save,
                color: AppColors.driver,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopListItem(StopOnRouteModel stop, int index) {
    const animDuration = Duration(milliseconds: 200);

    return AnimatedContainer(
      duration: animDuration,
      color: stop.isActive ? Colors.transparent : Colors.white.withValues(alpha: 0.02),
      child: InkWell(
        onTap: () {
          setState(() {
            stop.isActive = !stop.isActive;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.pagePadding,
            vertical: AppDimens.gapLg,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: animDuration,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stop.isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: animDuration,
                    style: TextStyle(
                      color: stop.isActive ? Colors.white : Colors.white30,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    child: Text("${index + 1}"),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.gapLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: animDuration,
                      style: TextStyle(
                        color: stop.isActive ? AppColors.textPrimary : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: stop.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                        decorationColor: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Text(stop.name ?? AppLocalizations.of(context)!.stop),
                    ),
                    const SizedBox(height: 4),

                    AnimatedTheme(
                      data: ThemeData(
                        iconTheme: IconThemeData(
                          color: stop.isActive ? Colors.white54 : Colors.white30,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12),
                          const SizedBox(width: 4),
                          AnimatedDefaultTextStyle(
                            duration: animDuration,
                            style: TextStyle(
                              color: stop.isActive ? Colors.white54 : Colors.white30,
                              fontSize: 12,
                            ),
                            child: Text(RouteFormatters.formatDuration(context, stop.etaSeconds)),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.route_rounded, size: 12),
                          const SizedBox(width: 4),
                          AnimatedDefaultTextStyle(
                            duration: animDuration,
                            style: TextStyle(
                              color: stop.isActive ? Colors.white54 : Colors.white30,
                              fontSize: 12,
                            ),
                            child: Text(RouteFormatters.formatDistance(context, stop.distanceMeters)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: stop.isActive,
                activeTrackColor: AppColors.driver,
                inactiveTrackColor: Colors.white12,
                onChanged: (bool value) {
                  setState(() {
                    stop.isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
