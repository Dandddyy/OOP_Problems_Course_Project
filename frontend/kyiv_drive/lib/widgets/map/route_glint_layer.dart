import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_layer_visibility.dart';
import 'route_path_geometry.dart';
import 'route_reveal.dart';

/// A decorative highlight above an existing [PolylineLayer], below its markers.
/// The base route is never hidden or animated by this layer.
class RouteGlintLayer extends StatefulWidget {
  static const sweepDuration = Duration(seconds: 4);
  static const pauseDuration = Duration(milliseconds: 1500);

  final List<LatLng> points;
  final Color color;
  final double strokeWidth;
  final bool enabled;

  const RouteGlintLayer({
    super.key,
    required this.points,
    required this.color,
    this.strokeWidth = 4,
    this.enabled = true,
  }) : assert(strokeWidth > 0);

  @override
  State<RouteGlintLayer> createState() => _RouteGlintLayerState();
}

class _RouteGlintLayerState extends State<RouteGlintLayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _paintKey = GlobalKey();
  final _paintEnabled = ValueNotifier(false);
  late final AnimationController _sweep;
  late List<LatLng> _points;
  RoutePathGeometry? _geometry;
  Crs? _crs;
  ScrollPosition? _scrollPosition;
  Timer? _pause;
  bool _visible = false;
  bool _visibilityCheckScheduled = false;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;
  bool _routeCurrent = true;
  bool _appActive = true;
  bool _revealComplete = true;

  @override
  void initState() {
    super.initState();
    _points = List.of(widget.points);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _sweep = AnimationController(
      vsync: this,
      duration: RouteGlintLayer.sweepDuration,
    )..addStatusListener(_handleSweepStatus);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _revealComplete = RouteRevealScope.maybeOf(context)?.complete ?? true;
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _scrollPosition)) {
      _scrollPosition?.removeListener(_queueVisibilityCheck);
      _scrollPosition = position;
      _scrollPosition?.addListener(_queueVisibilityCheck);
    }
    _updatePlayback();
    _queueVisibilityCheck();
  }

  @override
  void didUpdateWidget(RouteGlintLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_points, widget.points)) {
      _points = List.of(widget.points);
      _geometry = null;
      _crs = null;
      _stop();
    }
    _updatePlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updatePlayback();
    if (_appActive) _queueVisibilityCheck();
  }

  @override
  void didChangeMetrics() => _queueVisibilityCheck();

  bool get _mayAnimate =>
      widget.enabled &&
      _geometry != null &&
      _visible &&
      _tickerEnabled &&
      !_reduceMotion &&
      _routeCurrent &&
      _appActive &&
      _revealComplete;

  void _updatePlayback() {
    if (!_mayAnimate) {
      _stop();
      return;
    }
    _paintEnabled.value = true;
    if (!_sweep.isAnimating && _pause == null) _scheduleSweep();
  }

  void _scheduleSweep() {
    // A real idle pause avoids scheduling frames between sweeps.
    _pause = Timer(RouteGlintLayer.pauseDuration, () {
      _pause = null;
      if (mounted && _mayAnimate) _sweep.forward(from: 0);
    });
  }

  void _handleSweepStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _mayAnimate) _scheduleSweep();
  }

  void _stop() {
    _pause?.cancel();
    _pause = null;
    if (_sweep.isAnimating || _sweep.value != 0) _sweep.reset();
    _paintEnabled.value = false;
  }

  void _queueVisibilityCheck() {
    if (_visibilityCheckScheduled || !mounted) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted) return;
      _visible = isMapLayerVisible(context, _paintKey);
      _updatePlayback();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_queueVisibilityCheck);
    _pause?.cancel();
    _sweep.dispose();
    _paintEnabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final reveal = RouteRevealScope.maybeOf(context);
    if (reveal != null) {
      _geometry = reveal.geometry;
      _crs = camera.crs;
    } else if (_crs != camera.crs) {
      _crs = camera.crs;
      _geometry = RoutePathGeometry.fromPoints(_points, camera.crs);
    }
    _queueVisibilityCheck();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          key: _paintKey,
          child: MobileLayerTransformer(
            child: CustomPaint(
              size: camera.size,
              painter: _RouteGlintPainter(
                geometry: _geometry,
                camera: camera,
                progress: _sweep,
                enabled: _paintEnabled,
                color: widget.color,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteGlintPainter extends CustomPainter {
  final RoutePathGeometry? geometry;
  final MapCamera camera;
  final Animation<double> progress;
  final ValueListenable<bool> enabled;
  final Color color;
  final double strokeWidth;

  _RouteGlintPainter({
    required this.geometry,
    required this.camera,
    required this.progress,
    required this.enabled,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: Listenable.merge([progress, enabled]));

  @override
  void paint(Canvas canvas, Size size) {
    final route = geometry;
    final phase = progress.value;
    if (route == null || !enabled.value || phase <= 0 || phase >= 1) return;
    final scale = camera.getZoomScale(
      camera.zoom,
      RoutePathGeometry.referenceZoom,
    );
    if (!scale.isFinite || scale <= 0) return;
    final origin = camera.getOffsetFromOrigin(route.origin);
    final length = route.metric.length;
    final width = length * 0.14;
    final start = (length + width) * phase - width;
    final highlight = Color.lerp(color, Colors.white, 0.7)!;
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.2 / scale);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    // Short, softly weighted slices follow bends instead of using a gradient
    // across the route's bounding rectangle (which would reverse on hairpins).
    const slices = 32;
    for (var i = 0; i < slices; i++) {
      final from = (start + width * i / slices).clamp(0.0, length);
      final to = (start + width * (i + 1) / slices).clamp(0.0, length);
      if (to <= from) continue;
      final envelope = math
          .pow(math.sin(math.pi * (i + 0.5) / slices), 2)
          .toDouble();
      final segment = route.metric.extractPath(from, to);
      canvas.drawPath(
        segment,
        glow..color = highlight.withValues(alpha: envelope * 0.24),
      );
      canvas.drawPath(
        segment,
        core..color = highlight.withValues(alpha: envelope * 0.9),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RouteGlintPainter oldDelegate) =>
      !identical(geometry, oldDelegate.geometry) ||
      camera != oldDelegate.camera ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}
