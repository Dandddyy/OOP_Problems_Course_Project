import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:kyiv_drive/screens/route/waypoint_map_selection_screen.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/network/api_client.dart';
import '../../core/map/pin_map_layout.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../models/route_model.dart';
import '../../models/route_with_stops_model.dart';
import '../../services/map_api_service.dart';
import '../../services/map_configuration.dart';
import '../../services/notification_service.dart';
import '../../utils/app_route.dart';
import '../../utils/waypoint_sequence_validation.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/animated_control_lock.dart';
import '../../widgets/animated_value_text.dart';
import '../../widgets/animated_touch_templates.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../widgets/route_preview/route_edit_sheet_header.dart';
import '../../widgets/route_preview/visible_area_drag_listener.dart';
import '../../widgets/route_preview/waypoint_drag_feedback.dart';
import '../../widgets/map/route_glint_layer.dart';
import '../../widgets/map/route_reveal.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_tiles.dart';
import '../../widgets/map/route_map_warmup.dart';
import '../../widgets/map/route_stops_visibility.dart';

class WaypointsEditResult {
  final List<LatLng> waypoints;
  final RouteWithStopsModel routeData;

  WaypointsEditResult(this.waypoints, this.routeData);
}

class WaypointEditItem {
  final String id;
  final LatLng point;
  bool isDeleting;

  WaypointEditItem({
    required this.id,
    required this.point,
    this.isDeleting = false,
  });
}

class WaypointsEditScreen extends StatefulWidget {
  final RouteModel baseRoute;
  final List<LatLng> initialWaypoints;
  final AddressModel origin;
  final AddressModel destination;
  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;

  const WaypointsEditScreen({
    super.key,
    required this.baseRoute,
    required this.initialWaypoints,
    required this.origin,
    required this.destination,
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required this.selectedDays,
  });

  @override
  State<WaypointsEditScreen> createState() => _WaypointsEditScreenState();
}

class _WaypointsEditScreenState extends State<WaypointsEditScreen>
    with SingleTickerProviderStateMixin {
  static const double _initialSheetSize = RouteEditorMapLayout.initialSheetSize;

  final MapApiService _mapApiService = MapApiService(ApiClient().dio);

  late List<WaypointEditItem> _editableWaypoints;

  late List<LatLng> _currentRoutePoints;

  bool _hasChanges = false;
  bool _isApplying = false;
  bool _isExitDialogOpen = false;
  bool _isLeaving = false;
  bool _isWaypointPickerOpen = false;
  bool _isDeleteDialogOpen = false;
  bool _editorMapPresented = false;
  final _addWaypointWarmup = RouteMapWarmupController();
  final _sheetController = DraggableScrollableController();
  CancelToken? _redrawCancelToken;
  final _waypointListKey = GlobalKey<SliverReorderableListState>();
  final _waypointViewportKey = GlobalKey();
  final _sheetHeaderKey = GlobalKey();
  final _bottomActionKey = GlobalKey();
  final _waypointEntryKeys = <String, GlobalKey>{};
  final _waypointEntries = <String, RenderBox>{};
  late final VisibleAreaDragController _visibleDrag;
  late final AnimationController _dragGapRepaint;
  ScrollPosition? _dragScrollPosition;
  String? _draggedId;
  bool _isDropping = false;
  int _dragGeneration = 0;
  bool get _isDragging => _draggedId != null;
  RouteWithStopsModel? _newRouteData;
  late List<LatLng> _currentBaseWaypoints;

  final Color _brandColor = AppColors.driverAccent;

  @override
  void initState() {
    super.initState();
    _visibleDrag = VisibleAreaDragController(
      visibleViewport: _waypointsVisibleViewport,
    );
    _dragGapRepaint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _currentRoutePoints = widget.baseRoute.points;
    _currentBaseWaypoints = List.from(widget.initialWaypoints);

    _editableWaypoints = widget.initialWaypoints
        .map(
          (point) => WaypointEditItem(id: UniqueKey().toString(), point: point),
        )
        .toList();
  }

  Rect? _waypointsVisibleViewport() {
    final viewport = _waypointViewportKey.currentContext?.findRenderObject();
    final header = _sheetHeaderKey.currentContext?.findRenderObject();
    final bottom = _bottomActionKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox ||
        !viewport.attached ||
        header is! RenderBox ||
        !header.attached ||
        bottom is! RenderBox ||
        !bottom.attached) {
      return null;
    }
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    final top = math.max(
      bounds.top,
      header.localToGlobal(Offset.zero).dy +
          header.size.height +
          AppDimens.dividerThickness,
    );
    final end = math.min(
      bounds.bottom,
      bottom.localToGlobal(Offset.zero).dy - AppDimens.gapXs,
    );
    return Rect.fromLTRB(bounds.left, top, bounds.right, math.max(top, end));
  }

  void _startWaypointDrag(int index) {
    final scrollable = Scrollable.of(_waypointListKey.currentContext!);
    _visibleDrag.attach(scrollable);
    _dragScrollPosition?.removeListener(_refreshDragGap);
    _dragScrollPosition = scrollable.position;
    _dragScrollPosition!.addListener(_refreshDragGap);
    ++_dragGeneration;
    setState(() {
      _draggedId = _editableWaypoints[index].id;
      _isDropping = false;
    });
    _refreshDragGap();
  }

  void _refreshDragGap() {
    if (mounted && _isDragging) _dragGapRepaint.forward(from: 0);
  }

  void _dragProxyRemoved(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _dragGeneration || !_isDragging) return;
      _dragScrollPosition?.removeListener(_refreshDragGap);
      _dragScrollPosition = null;
      _dragGapRepaint.stop();
      setState(() {
        _draggedId = null;
        _isDropping = false;
      });
    });
  }

  void _reorderWaypoints(int oldIndex, int newIndex) {
    // The native list commits after its drop animation, while actions stay locked.
    if (!mounted ||
        _isLeaving ||
        !_waypointControlsEnabled ||
        (_isDragging && !_isDropping)) {
      return;
    }
    setState(() {
      final item = _editableWaypoints.removeAt(oldIndex);
      _editableWaypoints.insert(newIndex, item);
      _hasChanges = !_matchesWaypoints(_currentBaseWaypoints);
    });
  }

  bool _matchesWaypoints(List<LatLng> waypoints) {
    if (_editableWaypoints.length != waypoints.length) return false;
    for (int i = 0; i < _editableWaypoints.length; i++) {
      if (_editableWaypoints[i].point != waypoints[i]) {
        return false;
      }
    }
    return true;
  }

  bool get _hasUnsavedChanges => !_matchesWaypoints(widget.initialWaypoints);
  bool get _hasPendingDeletion => _editableWaypoints.any((wp) => wp.isDeleting);
  // Navigation guards must not dim controls during the closing transition.
  bool get _waypointControlsEnabled => !_isApplying && !_hasPendingDeletion;
  bool get _canEditWaypoints =>
      mounted && !_isLeaving && !_isDragging && _waypointControlsEnabled;

  @override
  void dispose() {
    _visibleDrag.dispose();
    _dragScrollPosition?.removeListener(_refreshDragGap);
    _dragGapRepaint.dispose();
    _addWaypointWarmup.dispose();
    _sheetController.dispose();
    _redrawCancelToken?.cancel();
    super.dispose();
  }

  void _leaveWithoutSaving() {
    if (!mounted || _isLeaving) return;
    setState(() => _isLeaving = true);
    _redrawCancelToken?.cancel();
    context.pop(null);
  }

  void _updateChangesState() {
    setState(() => _hasChanges = !_matchesWaypoints(_currentBaseWaypoints));
  }

  Future<void> _requestExit() async {
    if (!mounted ||
        _isExitDialogOpen ||
        _isLeaving ||
        _hasPendingDeletion ||
        _isDragging) {
      return;
    }
    if (_isApplying) {
      _isExitDialogOpen = true;
      final localizations = AppLocalizations.of(context)!;
      final confirmed = await AppDialogs.show(
        context,
        title: localizations.waypointRedrawInProgressTitle,
        content: localizations.waypointRedrawInProgressMessage,
        primaryButtonText: localizations.leave,
        barrierDismissible: true,
        brandColor: AppColors.driver,
      );
      _isExitDialogOpen = false;
      if (mounted && confirmed == true) _leaveWithoutSaving();
      return;
    }
    if (!_hasUnsavedChanges) {
      _leaveWithoutSaving();
      return;
    }

    _isExitDialogOpen = true;
    if (_hasChanges) {
      final action = await AppDialogs.showPendingWaypointChanges(context);
      _isExitDialogOpen = false;
      if (!mounted) return;

      switch (action) {
        case PendingWaypointChangesAction.redraw:
          await _applyChanges();
        case PendingWaypointChangesAction.discard:
          _leaveWithoutSaving();
        case PendingWaypointChangesAction.cancel:
        case null:
          break;
      }
      return;
    }

    final action = await AppDialogs.showUnsavedChanges(context);
    _isExitDialogOpen = false;
    if (!mounted) return;

    switch (action) {
      case UnsavedChangesAction.save:
        await _saveAndClose();
      case UnsavedChangesAction.discard:
        _leaveWithoutSaving();
      case UnsavedChangesAction.cancel:
      case null:
        break;
    }
  }

  Future<void> _saveAndClose() async {
    if (!_canEditWaypoints || _isWaypointPickerOpen || _isDeleteDialogOpen) {
      return;
    }
    if (_hasChanges && !await _applyChanges()) return;
    if (!mounted || _isLeaving || _isExitDialogOpen) return;

    final routeData = _newRouteData;
    setState(() => _isLeaving = true);
    context.pop(
      routeData == null
          ? null
          : WaypointsEditResult(
              _editableWaypoints.map((e) => e.point).toList(),
              routeData,
            ),
    );
  }

  void _addWaypoint(LatLng point) {
    if (!_canEditWaypoints || _editableWaypoints.length >= 15) return;
    setState(() {
      _editableWaypoints.add(
        WaypointEditItem(id: UniqueKey().toString(), point: point),
      );
    });
    _updateChangesState();
  }

  Future<LatLng?> _pickWaypoint({int? editingIndex}) async {
    if (!_canEditWaypoints || _isWaypointPickerOpen || _isDeleteDialogOpen) {
      return null;
    }
    _isWaypointPickerOpen = true;
    final controller = editingIndex == null
        ? _addWaypointWarmup
        : RouteMapWarmupController();
    final options = PinMapLayout.waypoint(
      route: _currentRoutePoints,
      bottomExtent: AppGradientBottomActionBar.extentOf(context),
      editingPoint: editingIndex == null
          ? null
          : _editableWaypoints[editingIndex].point,
    );
    final mapConfig = MapConfiguration();
    final warmup = controller.takeFor(
      context: context,
      options: options,
      url: mapConfig.mapUrlTemplate,
      accessToken: mapConfig.mapAccessToken,
      visibleInsets: PinMapLayout.waypointInsets(
        MediaQuery.viewPaddingOf(context).bottom,
      ),
    );
    if (editingIndex != null) controller.dispose();
    try {
      return await Navigator.push<LatLng>(
        context,
        AppRoute(
          child: WaypointMapSelectionScreen(
            baseRoute: _newRouteData?.route ?? widget.baseRoute,
            existingWaypoints: _editableWaypoints.map((w) => w.point).toList(),
            origin: widget.origin,
            destination: widget.destination,
            editingIndex: editingIndex,
            tileWarmup: warmup,
          ),
        ),
      );
    } finally {
      warmup?.dispose();
      if (mounted) setState(() => _isWaypointPickerOpen = false);
    }
  }

  Future<void> _openAddWaypoint() async {
    if (!_canEditWaypoints || _editableWaypoints.length >= 15) return;
    final point = await _pickWaypoint();
    if (point != null && mounted) _addWaypoint(point);
  }

  Future<void> _editWaypoint(int index) async {
    if (!_canEditWaypoints || index < 0 || index >= _editableWaypoints.length) {
      return;
    }
    final id = _editableWaypoints[index].id;
    final updatedPoint = await _pickWaypoint(editingIndex: index);

    if (updatedPoint != null && mounted && _canEditWaypoints) {
      final currentIndex = _editableWaypoints.indexWhere(
        (item) => item.id == id,
      );
      if (currentIndex < 0) return;
      setState(() {
        _editableWaypoints[currentIndex] = WaypointEditItem(
          id: id,
          point: updatedPoint,
        );
      });
      _updateChangesState();
    }
  }

  Future<void> _removeWaypoint(int index) async {
    if (!_canEditWaypoints ||
        _isWaypointPickerOpen ||
        _isDeleteDialogOpen ||
        index < 0 ||
        index >= _editableWaypoints.length) {
      return;
    }

    final wp = _editableWaypoints[index];

    if (wp.isDeleting) return;

    final displayIndex = index + 1;

    _isDeleteDialogOpen = true;
    final confirmed = await AppDialogs.show(
      context,
      title: AppLocalizations.of(context)!.deleteWaypoint(displayIndex),
      content: AppLocalizations.of(context)!.sureToDeleteWaypoint(displayIndex),
      primaryButtonText: AppLocalizations.of(context)!.delete,
      isDestructive: true,
    );
    _isDeleteDialogOpen = false;

    if (confirmed != true ||
        !mounted ||
        !_canEditWaypoints ||
        !_editableWaypoints.any((item) => item.id == wp.id)) {
      return;
    }

    _waypointListKey.currentState?.cancelReorder();
    setState(() {
      wp.isDeleting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted || _isLeaving) return;

    setState(() {
      _editableWaypoints.removeWhere((item) => item.id == wp.id);
      _waypointEntryKeys.remove(wp.id);
    });

    _updateChangesState();
  }

  Future<bool> _applyChanges() async {
    if (!_canEditWaypoints || _isWaypointPickerOpen || _isDeleteDialogOpen) {
      return false;
    }

    final rawWaypoints = _editableWaypoints.map((e) => e.point).toList();
    final validationIssue = validateWaypointSequence(
      origin: LatLng(widget.origin.lat, widget.origin.lon),
      destination: LatLng(widget.destination.lat, widget.destination.lon),
      waypoints: rawWaypoints,
    );

    if (validationIssue != null) {
      final localizations = AppLocalizations.of(context)!;
      final message = switch (validationIssue.type) {
        WaypointSequenceIssueType.firstMatchesOrigin =>
          localizations.firstWaypointMatchesOrigin,
        WaypointSequenceIssueType.lastMatchesDestination =>
          localizations.lastWaypointMatchesDestination,
        WaypointSequenceIssueType.adjacentWaypointsMatch =>
          localizations.adjacentWaypointsMatch(
            validationIssue.firstWaypointNumber!,
            validationIssue.secondWaypointNumber!,
          ),
      };
      NotificationService.showError(message);
      return false;
    }

    _waypointListKey.currentState?.cancelReorder();
    final cancelToken = CancelToken();
    _redrawCancelToken = cancelToken;
    setState(() {
      _isApplying = true;
    });

    try {
      final results = await Future.wait([
        _mapApiService.getRouteWithStops(
          startLat: widget.origin.lat,
          startLon: widget.origin.lon,
          endLat: widget.destination.lat,
          endLon: widget.destination.lon,
          waypoints: rawWaypoints,
          cancelToken: cancelToken,
        ),
        Future<void>.delayed(const Duration(milliseconds: 600)),
      ]);

      if (mounted && !_isLeaving) {
        final result = results[0] as RouteWithStopsModel;
        setState(() {
          _newRouteData = result;
          _currentRoutePoints = result.route.points;
          _currentBaseWaypoints = List.from(rawWaypoints);
          _hasChanges = false;
          _isApplying = false;
        });
        return true;
      }
    } catch (e) {
      if (mounted && !_isLeaving) {
        setState(() {
          _isApplying = false;
        });
        if (e is DioException && CancelToken.isCancel(e)) return false;
        NotificationService.showError(e);
      }
    } finally {
      if (identical(_redrawCancelToken, cancelToken)) _redrawCancelToken = null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<WaypointsEditResult>(
      canPop:
          _isLeaving ||
          (!_hasUnsavedChanges &&
              !_isApplying &&
              !_hasPendingDeletion &&
              !_isDragging),
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

    final canAddMore = _editableWaypoints.length < 15;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RouteMapPreloader(
            controller: _addWaypointWarmup,
            options: PinMapLayout.waypoint(
              route: _currentRoutePoints,
              bottomExtent: bottomActionExtent,
            ),
            url: mapUrlTemplate,
            accessToken: mapAccessToken,
            visibleInsets: PinMapLayout.waypointInsets(
              MediaQuery.viewPaddingOf(context).bottom,
            ),
            enabled:
                _editorMapPresented &&
                _canEditWaypoints &&
                canAddMore &&
                !_isWaypointPickerOpen,
          ),
          Positioned.fill(
            child: RouteMapSurface(
              url: mapUrlTemplate,
              accessToken: mapAccessToken,
              maxNativeZoom: 18,
              maxZoom: 20,
              onPresented: () {
                if (!_editorMapPresented) {
                  setState(() => _editorMapPresented = true);
                }
              },
              visibleInsets: RouteEditorMapLayout.visibleInsets(screenHeight),
              options: RouteEditorMapLayout.options(
                _currentRoutePoints,
                screenHeight,
              ),
              children: [
                RouteReveal(
                  points: _currentRoutePoints,
                  revision: _newRouteData?.route ?? widget.baseRoute,
                  updateCameraFit: RouteEditorMapLayout.cameraFit(
                    _currentRoutePoints,
                    screenHeight,
                    sheetSize: _sheetController.isAttached
                        ? _sheetController.size
                        : _initialSheetSize,
                  ),
                  children: [
                    RoutePolylineLayer(
                      color: _hasChanges
                          ? AppColors.driverRouteLine.withValues(alpha: 0.5)
                          : AppColors.driverRouteLine,
                    ),

                    RouteGlintLayer(
                      points: _currentRoutePoints,
                      color: AppColors.driverRouteLine,
                      enabled:
                          !_hasChanges && !_isApplying && !_hasPendingDeletion,
                    ),
                    MarkerLayer(
                      markers: [
                        ..._editableWaypoints.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final wp = entry.value;

                          return Marker(
                            key: ValueKey('waypoint-map-${wp.id}'),
                            point: wp.point,
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: RouteStopsVisibility(
                              visible: !wp.isDeleting,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _hasChanges
                                        ? _brandColor.withValues(alpha: 0.8)
                                        : _brandColor,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: AnimatedValueText(
                                      "${index + 1}",
                                      alignment: Alignment.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
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
                                color: _brandColor,
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

          Positioned(
            top: 0,
            left: AppDimens.pagePadding,
            child: AppTopSafeArea(
              child: AbsorbPointer(
                absorbing: _isDragging,
                child: AnimatedControlLock(
                  key: const ValueKey('waypoints-back-lock'),
                  isEnabled: !_hasPendingDeletion,
                  child: AppSquareButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _hasPendingDeletion ? null : _requestExit,
                  ),
                ),
              ),
            ),
          ),

          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _initialSheetSize,
            minChildSize: 0.33,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return AppBottomSheetSurface(
                child: AppScrollbar(
                  controller: scrollController,
                  mainAxisMargin: 0,
                  padding: EdgeInsets.only(
                    top:
                        RouteEditSheetHeader.extent +
                        AppDimens.dividerThickness +
                        AppDimens.gapXs,
                    bottom: bottomActionExtent + AppDimens.gapXs,
                  ),
                  child: Listener(
                    onPointerMove: (_) => _refreshDragGap(),
                    onPointerUp: (_) => _refreshDragGap(),
                    onPointerCancel: (_) => _refreshDragGap(),
                    child: CustomPaint(
                      key: _waypointViewportKey,
                      painter: _draggedId == null
                          ? null
                          : WaypointDragGapPainter(
                              viewportKey: _waypointViewportKey,
                              listKey: _waypointListKey,
                              entries: _waypointEntries,
                              draggedId: _draggedId!,
                              visibleViewport: _waypointsVisibleViewport,
                              repaint: _dragGapRepaint,
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
                              key: _sheetHeaderKey,
                              title: AppLocalizations.of(context)!.waypoints,
                              counterText: "${_editableWaypoints.length} / 15",
                              description: AppLocalizations.of(
                                context,
                              )!.addWaypointsToRedrawAndUpdate,
                            ),
                            bottom: PreferredSize(
                              preferredSize: const Size.fromHeight(
                                AppDimens.dividerThickness,
                              ),
                              child: Divider(
                                color: AppColors.borderMuted,
                                height: AppDimens.dividerThickness,
                                thickness: AppDimens.dividerThickness,
                              ),
                            ),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.only(
                              top: AppDimens.gapSm,
                            ),
                            sliver: SliverReorderableList(
                              key: _waypointListKey,
                              itemCount: _editableWaypoints.length,
                              onReorderItem: _reorderWaypoints,
                              onReorderStart: _startWaypointDrag,
                              onReorderEnd: (_) => _isDropping = true,
                              dragBoundaryProvider: (_) => _visibleDrag,
                              proxyDecorator: (child, index, animation) {
                                final generation = _dragGeneration;
                                return WaypointDragFeedback(
                                  animation: animation,
                                  onRemoved: () =>
                                      _dragProxyRemoved(generation),
                                  child: child,
                                );
                              },
                              itemBuilder: (context, index) {
                                final wp = _editableWaypoints[index];
                                return _buildWaypointItem(wp, index);
                              },
                            ),
                          ),

                          SliverPadding(
                            padding: EdgeInsets.only(
                              top: AppDimens.pagePadding,
                              bottom: bottomActionExtent,
                              left: AppDimens.pagePadding,
                              right: AppDimens.pagePadding,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: canAddMore
                                    ? AbsorbPointer(
                                        absorbing: _isDragging,
                                        child: AnimatedControlLock(
                                          key: const ValueKey(
                                            'waypoints-add-lock',
                                          ),
                                          isEnabled: _waypointControlsEnabled,
                                          child: AnimatedTouchItem(
                                            onTap: _waypointControlsEnabled
                                                ? _openAddWaypoint
                                                : null,
                                            normalColor: AppColors.surface,
                                            pressedColor:
                                                AppColors.surfacePressed,
                                            pressedScale: 0.97,
                                            borderRadius:
                                                AppRadius.compactControlBr,
                                            child: Container(
                                              height: AppDimens.compactHeight,
                                              alignment: Alignment.center,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .add_location_alt_rounded,
                                                    color: Colors.white70,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(
                                                    width: AppDimens.gapSm,
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.addWaypoint,
                                                    style: AppText.compactButton
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AbsorbPointer(
              absorbing: _isDragging,
              child: AppGradientBottomActionBar(
                key: _bottomActionKey,
                child: AuthButton(
                  key: const ValueKey('waypoints-apply-button'),
                  text: _hasChanges
                      ? AppLocalizations.of(context)!.redrawRoute
                      : AppLocalizations.of(context)!.save,
                  color: AppColors.driver,
                  isLoading: _isApplying,
                  onTap: !_waypointControlsEnabled
                      ? null
                      : () {
                          if (_hasChanges) {
                            _applyChanges();
                          } else {
                            _saveAndClose();
                          }
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointItem(WaypointEditItem wp, int index) {
    return WaypointDragEntry(
      key: _waypointEntryKeys.putIfAbsent(wp.id, GlobalKey.new),
      id: wp.id,
      entries: _waypointEntries,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              alignment: AlignmentDirectional.topStart,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: wp.isDeleting
              ? const SizedBox(
                  width: double.infinity,
                  height: 0,
                  key: ValueKey("deleted"),
                )
              : Padding(
                  key: const ValueKey("active"),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.pagePadding,
                    vertical: AppDimens.gapSm,
                  ),
                  child: Builder(
                    builder: (context) {
                      final lift = WaypointDragAppearance.progressOf(context);
                      return Material(
                        key: ValueKey('waypoint-card-${wp.id}'),
                        animationDuration: Duration.zero,
                        color: Color.lerp(
                          Color.alphaBlend(
                            Colors.white.withValues(alpha: 0.03),
                            AppColors.background,
                          ),
                          AppColors.floatingSurface,
                          lift,
                        ),
                        elevation: 6 * lift,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.compactControlBr,
                          side: BorderSide(
                            color: AppColors.borderSubtle,
                            width: AppDimens.borderWidth,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.gapLg + AppDimens.borderWidth,
                            vertical: AppDimens.gapMd + AppDimens.borderWidth,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: AnimatedValueText(
                                    "${index + 1}",
                                    alignment: Alignment.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDimens.gapMd),
                              Expanded(
                                child: AnimatedValueText(
                                  "${AppLocalizations.of(context)!.waypoint} ${index + 1}",
                                  style: AppText.bodyStrong.copyWith(
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AbsorbPointer(
                                absorbing: _isDragging,
                                child: AnimatedControlLock(
                                  key: ValueKey('waypoint-actions-${wp.id}'),
                                  isEnabled: _waypointControlsEnabled,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedTouchItem(
                                        onTap: _waypointControlsEnabled
                                            ? () => _editWaypoint(index)
                                            : null,
                                        normalColor: Colors.transparent,
                                        pressedColor: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        pressedScale: 0.95,
                                        borderRadius: AppRadius.smallBr,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            color: Colors.white54,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppDimens.gapXs),
                                      AnimatedTouchItem(
                                        onTap: _waypointControlsEnabled
                                            ? () => _removeWaypoint(index)
                                            : null,
                                        normalColor: Colors.transparent,
                                        pressedColor: Colors.redAccent
                                            .withValues(alpha: 0.2),
                                        pressedScale: 0.95,
                                        borderRadius: AppRadius.smallBr,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white54,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppDimens.gapXs),
                                      VisibleAreaDragStartListener(
                                        key: ValueKey('waypoint-drag-${wp.id}'),
                                        controller: _visibleDrag,
                                        index: index,
                                        enabled:
                                            _waypointControlsEnabled &&
                                            !_isDragging &&
                                            !_isWaypointPickerOpen &&
                                            !_isDeleteDialogOpen,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          color: Colors.transparent,
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            color: Color.lerp(
                                              AppColors.iconMuted,
                                              AppColors.iconSecondary,
                                              lift,
                                            ),
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
