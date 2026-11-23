import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_layer_visibility.dart';
import 'route_path_geometry.dart';
import 'route_map_surface.dart';

/// One presentation per route revision, independent of camera/form rebuilds.
class RouteReveal extends StatefulWidget {
  static const lineDuration = Duration(milliseconds: 1000);
  static const markerDuration = Duration(milliseconds: 200);
  // Leave time for the last marker to fade in before handing over to the glint.
  static const duration = Duration(milliseconds: 1200);
  static const cameraDuration = Duration(milliseconds: 500);
  static const dimDuration = Duration(milliseconds: 200);
  static const replacementDuration = Duration(milliseconds: 1400);

  final List<LatLng> points;
  final Object revision;
  final bool ready;
  final CameraFit? updateCameraFit;
  final List<Widget> children;

  const RouteReveal({
    super.key,
    required this.points,
    required this.revision,
    required this.children,
    this.ready = true,
    this.updateCameraFit,
  });

  @override
  State<RouteReveal> createState() => _RouteRevealState();
}

class _RouteRevealState extends State<RouteReveal>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _layerKey = GlobalKey();
  late final AnimationController _progress;
  late final AnimationController _cameraProgress;
  late final Animation<double> _initialLine;
  late final Animation<double> _replacementLine;
  late final Animation<double> _previousOpacity;
  late List<LatLng> _points;
  List<LatLng>? _previousPoints;
  RoutePathGeometry? _previousGeometry;
  RoutePathGeometry? _geometry;
  MapController? _mapController;
  StreamSubscription<MapEvent>? _cameraEvents;
  MapCamera? _cameraStart;
  MapCamera? _cameraTarget;
  bool _cameraPending = false;
  bool _cameraMoving = false;
  Crs? _crs;
  ScrollPosition? _scrollPosition;
  Animation<double>? _navigation;
  bool _checkScheduled = false;
  bool _started = false;
  bool _complete = false;
  bool _reduceMotion = false;
  bool _active = true;
  bool _mapPresented = true;

  @override
  void initState() {
    super.initState();
    _points = List.of(widget.points);
    _progress = AnimationController(vsync: this, duration: RouteReveal.duration)
      ..addStatusListener(_handleStatus);
    _cameraProgress = AnimationController(
      vsync: this,
      duration: RouteReveal.cameraDuration,
    )..addListener(_moveCamera);
    _initialLine = _progress.drive(
      CurveTween(
        curve: Interval(
          0,
          RouteReveal.lineDuration.inMicroseconds /
              RouteReveal.duration.inMicroseconds,
        ),
      ),
    );
    _replacementLine = _progress.drive(
      CurveTween(
        curve: Interval(
          RouteReveal.dimDuration.inMicroseconds /
              RouteReveal.replacementDuration.inMicroseconds,
          (RouteReveal.dimDuration + RouteReveal.lineDuration).inMicroseconds /
              RouteReveal.replacementDuration.inMicroseconds,
        ),
      ),
    );
    _previousOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.6,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: RouteReveal.dimDuration.inMicroseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.6),
        weight: RouteReveal.lineDuration.inMicroseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.6,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: RouteReveal.markerDuration.inMicroseconds.toDouble(),
      ),
    ]).animate(_progress);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _mapPresented = RouteMapSurfaceScope.isPresented(context);
    final controller = MapController.of(context);
    if (!identical(controller, _mapController)) {
      _cameraEvents?.cancel();
      _mapController = controller;
      _cameraEvents = controller.mapEventStream.listen(_handleCameraEvent);
    }
    final scroll = Scrollable.maybeOf(context)?.position;
    if (!identical(scroll, _scrollPosition)) {
      _scrollPosition?.removeListener(_queueCheck);
      _scrollPosition = scroll;
      scroll?.addListener(_queueCheck);
    }
    final navigation = ModalRoute.of(context)?.animation;
    if (!identical(navigation, _navigation)) {
      _navigation?.removeStatusListener(_handleNavigation);
      _navigation = navigation;
      navigation?.addStatusListener(_handleNavigation);
    }
    _active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _queueCheck();
  }

  bool get _appResumed =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void didUpdateWidget(RouteReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision ||
        !listEquals(_points, widget.points)) {
      // Only keep the route that was actually presented, not an unseen update.
      _previousPoints = _previousPoints != null && !_started
          ? _previousPoints
          : _started || _complete
          ? _points
          : null;
      _cameraProgress.stop();
      _cameraMoving = false;
      _cameraPending =
          _previousPoints != null && widget.updateCameraFit != null;
      _points = List.of(widget.points);
      _geometry = null;
      _crs = null;
      _started = false;
      _complete = false;
      _progress.duration = _previousPoints == null
          ? RouteReveal.duration
          : RouteReveal.replacementDuration;
      _progress.reset();
    }
    _queueCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && (_started || _cameraMoving)) {
      _finish();
    }
    _queueCheck();
  }

  @override
  void didChangeMetrics() => _queueCheck();

  void _handleNavigation(AnimationStatus _) => _queueCheck();

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_complete) {
      setState(() {
        _complete = true;
        _previousPoints = null;
        _previousGeometry = null;
      });
    }
  }

  void _finish() {
    if (_cameraMoving && _cameraTarget != null) {
      _mapController!.move(_cameraTarget!.center, _cameraTarget!.zoom);
    }
    _cameraProgress.stop();
    _cameraMoving = false;
    _cameraPending = false;
    if (!_complete) _progress.value = 1;
  }

  MapCamera _fittedCamera() {
    final camera = _mapController!.camera;
    final fitted = widget.updateCameraFit!.fit(camera);
    final target = camera.withPosition(
      center: fitted.center,
      zoom: camera.clampZoom(fitted.zoom),
    );
    return MapOptions.of(context).cameraConstraint.constrain(target) ?? camera;
  }

  void _startCamera() {
    _cameraPending = false;
    _cameraStart = _mapController!.camera;
    _cameraTarget = _fittedCamera();
    final start = _cameraStart!;
    final target = _cameraTarget!;
    if (_reduceMotion ||
        (start.projectAtZoom(start.center) - start.projectAtZoom(target.center))
                    .distance <
                0.01 &&
            (start.zoom - target.zoom).abs() < 0.0001) {
      _mapController!.move(target.center, target.zoom);
      _startDrawing();
      return;
    }
    _cameraMoving = true;
    _cameraProgress.forward(from: 0);
  }

  void _moveCamera() {
    if (!_cameraMoving || !mounted) return;
    final start = _cameraStart!;
    final target = _cameraTarget!;
    final t = Curves.easeInOutCubic.transform(_cameraProgress.value);
    final center = start.unprojectAtZoom(
      Offset.lerp(
        start.projectAtZoom(start.center, RoutePathGeometry.referenceZoom),
        start.projectAtZoom(target.center, RoutePathGeometry.referenceZoom),
        t,
      )!,
      RoutePathGeometry.referenceZoom,
    );
    _mapController!.move(center, start.zoom + (target.zoom - start.zoom) * t);
    if (_cameraProgress.value == 1) {
      _cameraMoving = false;
      _startDrawing();
    }
  }

  void _handleCameraEvent(MapEvent event) {
    if (_cameraMoving &&
        event.source != MapEventSource.mapController &&
        event.source != MapEventSource.nonRotatedSizeChange &&
        (event is MapEventWithMove || event is MapEventMoveStart)) {
      // A deliberate map gesture takes priority over the automatic flight.
      _cameraProgress.stop();
      _cameraMoving = false;
      _startDrawing();
    }
  }

  void _startDrawing() {
    if (_started || _complete) return;
    _started = true;
    if (_reduceMotion) {
      _finish();
    } else {
      _progress.forward();
    }
  }

  void _queueCheck() {
    if (_checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || _complete) return;
      final visible = isMapLayerVisible(context, _layerKey);
      final active = _active && _appResumed;
      if (_reduceMotion || _geometry == null) {
        if ((_cameraPending || _cameraMoving) &&
            widget.updateCameraFit != null) {
          final target = _fittedCamera();
          _cameraTarget = target;
          _mapController!.move(target.center, target.zoom);
        }
        _finish();
      } else if ((_started || _cameraMoving) && (!active || !visible)) {
        _finish();
      } else if (!_started &&
          !_cameraMoving &&
          widget.ready &&
          _mapPresented &&
          active &&
          visible &&
          (_navigation == null ||
              _navigation!.status == AnimationStatus.completed)) {
        if (_cameraPending) {
          _startCamera();
        } else {
          _startDrawing();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_queueCheck);
    _navigation?.removeStatusListener(_handleNavigation);
    _progress.dispose();
    _cameraEvents?.cancel();
    _cameraProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crs = MapCamera.of(context).crs;
    if (_crs != crs) {
      _crs = crs;
      _geometry = RoutePathGeometry.fromPoints(_points, crs);
      _previousGeometry = _previousPoints == null
          ? null
          : RoutePathGeometry.fromPoints(_previousPoints!, crs);
    }
    _queueCheck();
    return RouteRevealScope(
      progress: _reduceMotion ? const AlwaysStoppedAnimation(1.0) : _progress,
      lineProgress: _previousPoints == null ? _initialLine : _replacementLine,
      previousGeometry: _previousGeometry,
      previousOpacity: _previousOpacity,
      replacing: _previousPoints != null,
      geometry: _geometry,
      points: _points,
      complete: _complete || _reduceMotion,
      child: RepaintBoundary(
        key: _layerKey,
        child: Stack(fit: StackFit.expand, children: widget.children),
      ),
    );
  }
}

class RouteRevealScope extends InheritedWidget {
  final Animation<double> progress;
  final Animation<double> lineProgress;
  final RoutePathGeometry? previousGeometry;
  final Animation<double> previousOpacity;
  final bool replacing;
  final RoutePathGeometry? geometry;
  final List<LatLng> points;
  final bool complete;

  const RouteRevealScope({
    super.key,
    required this.progress,
    required this.lineProgress,
    required this.previousGeometry,
    required this.previousOpacity,
    required this.replacing,
    required this.geometry,
    required this.points,
    required this.complete,
    required super.child,
  });

  static RouteRevealScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RouteRevealScope>();

  @override
  bool updateShouldNotify(RouteRevealScope oldWidget) =>
      progress != oldWidget.progress ||
      previousGeometry != oldWidget.previousGeometry ||
      geometry != oldWidget.geometry ||
      complete != oldWidget.complete;
}

class RoutePolylineLayer extends StatefulWidget {
  static const colorDuration = Duration(milliseconds: 300);
  final Color color;
  final double strokeWidth;

  const RoutePolylineLayer({
    super.key,
    required this.color,
    this.strokeWidth = 4,
  });

  @override
  State<RoutePolylineLayer> createState() => _RoutePolylineLayerState();
}

class _RoutePolylineLayerState extends State<RoutePolylineLayer> {
  Color? _paintedColor;
  Color? _previousColor;
  RoutePathGeometry? _previousGeometry;

  @override
  Widget build(BuildContext context) {
    final reveal = RouteRevealScope.maybeOf(context)!;
    if (!identical(_previousGeometry, reveal.previousGeometry)) {
      _previousGeometry = reveal.previousGeometry;
      _previousColor = _paintedColor ?? widget.color;
    }
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.color),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : RoutePolylineLayer.colorDuration,
      curve: Curves.easeInOut,
      builder: (context, color, _) {
        _paintedColor = color!;
        return _buildLine(context, reveal, color);
      },
    );
  }

  Widget _buildLine(
    BuildContext context,
    RouteRevealScope reveal,
    Color color,
  ) {
    if (reveal.complete || reveal.geometry == null) {
      return PolylineLayer(
        // Match the original geometry used by the reveal and glint painters.
        simplificationTolerance: 0,
        polylines: [
          if (reveal.points.length >= 2)
            Polyline(
              points: reveal.points,
              color: color,
              strokeWidth: widget.strokeWidth,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
        ],
      );
    }
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: MobileLayerTransformer(
          child: CustomPaint(
            size: camera.size,
            painter: _RouteRevealPainter(
              reveal.geometry!,
              camera,
              reveal.lineProgress,
              color,
              widget.strokeWidth,
              reveal.previousGeometry,
              _previousColor ?? color,
              reveal.previousOpacity,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteRevealPainter extends CustomPainter {
  final RoutePathGeometry geometry;
  final MapCamera camera;
  final Animation<double> progress;
  final Color color;
  final double strokeWidth;
  final RoutePathGeometry? previousGeometry;
  final Color previousColor;
  final Animation<double> previousOpacity;

  _RouteRevealPainter(
    this.geometry,
    this.camera,
    this.progress,
    this.color,
    this.strokeWidth,
    this.previousGeometry,
    this.previousColor,
    this.previousOpacity,
  ) : super(repaint: Listenable.merge([progress, previousOpacity]));

  @override
  void paint(Canvas canvas, Size size) {
    final old = previousGeometry;
    if (old != null && previousOpacity.value > 0) {
      _draw(
        canvas,
        size,
        old,
        1,
        previousColor.withValues(
          alpha: previousColor.a * previousOpacity.value,
        ),
      );
    }
    _draw(canvas, size, geometry, progress.value, color);
  }

  void _draw(
    Canvas canvas,
    Size size,
    RoutePathGeometry geometry,
    double fraction,
    Color color,
  ) {
    if (fraction <= 0) return;
    final scale = camera.getZoomScale(
      camera.zoom,
      RoutePathGeometry.referenceZoom,
    );
    final origin = camera.getOffsetFromOrigin(geometry.origin);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.drawPath(
      geometry.metric.extractPath(0, geometry.metric.length * fraction),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = strokeWidth / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RouteRevealPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      camera != oldDelegate.camera ||
      color != oldDelegate.color ||
      previousGeometry != oldDelegate.previousGeometry ||
      previousColor != oldDelegate.previousColor ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// Reveals only the map marker; the editable list is available immediately.
class RouteRevealMarker extends StatelessWidget {
  final LatLng point;
  final double? fractionHint;
  final Widget child;

  const RouteRevealMarker({
    super.key,
    required this.point,
    this.fractionHint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reveal = RouteRevealScope.maybeOf(context);
    if (reveal == null || reveal.complete || reveal.geometry == null) {
      return child;
    }
    final fraction = reveal.geometry!.fractionAt(
      point,
      fractionHint: fractionHint,
    );
    final duration = reveal.replacing
        ? RouteReveal.replacementDuration
        : RouteReveal.duration;
    final start =
        ((reveal.replacing ? RouteReveal.dimDuration.inMilliseconds : 0) +
            fraction * RouteReveal.lineDuration.inMilliseconds) /
        duration.inMilliseconds;
    final end =
        start +
        RouteReveal.markerDuration.inMilliseconds / duration.inMilliseconds;
    final opacity = reveal.progress.drive(
      CurveTween(
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ),
    );
    return AnimatedBuilder(
      animation: opacity,
      child: RepaintBoundary(child: child),
      builder: (context, child) => IgnorePointer(
        ignoring: opacity.value <= 0,
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: opacity.drive(Tween(begin: 0.82, end: 1.0)),
            child: child,
          ),
        ),
      ),
    );
  }
}
