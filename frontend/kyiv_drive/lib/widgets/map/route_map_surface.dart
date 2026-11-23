import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/constants/app_ui_tokens.dart';
import 'route_map_tiles.dart';
import 'route_map_warmup.dart';

class RouteMapSurface extends StatefulWidget {
  static const waitLimit = Duration(milliseconds: 1500);
  static const minimumPlaceholderDuration = AppDurations.minimumScreenLoading;
  static const retryDelay = RouteMapWarmup.retryDelay;
  static const fadeDuration = Duration(milliseconds: 200);

  final MapOptions options;
  final MapController? mapController;
  final String? url;
  final String? accessToken;
  final int maxNativeZoom;
  final double maxZoom;
  final EdgeInsets visibleInsets;
  final List<Widget> children;

  /// Lets the enclosing loading transition reveal the prepared map.
  final bool revealWithParent;
  final VoidCallback? onPresented;
  final TileProvider Function()? tileProviderFactory;
  final RouteMapWarmup? warmup;

  const RouteMapSurface({
    super.key,
    required this.options,
    this.mapController,
    required this.url,
    required this.accessToken,
    required this.children,
    this.maxNativeZoom = 19,
    this.maxZoom = double.infinity,
    this.visibleInsets = EdgeInsets.zero,
    this.revealWithParent = false,
    this.onPresented,
    this.tileProviderFactory,
    this.warmup,
  });

  @override
  State<RouteMapSurface> createState() => _RouteMapSurfaceState();
}

class _RouteMapSurfaceState extends State<RouteMapSurface> {
  final _tiles = <TileCoordinates, TileImage>{};
  final _retriedTiles = <TileCoordinates>{};
  final _retryTimers = <TileCoordinates, Timer>{};
  TileProvider? _provider;
  bool _providerAttached = false;
  RouteMapTilePlan? _plan;
  Timer? _deadline;
  Timer? _minimumWait;
  int _sourceRevision = 0;
  bool _minimumElapsed = false;
  bool _initialCacheChecked = false;
  bool _showMap = false;
  bool _presented = false;
  bool _checkScheduled = false;
  bool _notifyScheduled = false;
  bool _notified = false;
  bool _initialCameraReady = false;
  bool _initialCameraFrameScheduled = false;
  bool _warmupAttached = false;

  bool get _animateReveal =>
      !widget.revealWithParent && !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _listenToWarmup();
  }

  void _listenToWarmup() {
    widget.warmup?.adopt();
    if (widget.warmup?.matches(widget.url, widget.accessToken) == true) {
      widget.warmup?.addListener(_warmupChanged);
    }
  }

  void _warmupChanged() {
    if (mounted && !_warmupAttached) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_minimumWait != null && reduceMotion) {
      _finishMinimumWait();
    }
  }

  @override
  void didUpdateWidget(RouteMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.accessToken != oldWidget.accessToken ||
        widget.maxNativeZoom != oldWidget.maxNativeZoom ||
        widget.tileProviderFactory != oldWidget.tileProviderFactory ||
        widget.warmup != oldWidget.warmup) {
      _cancelWaits();
      _cancelRetries();
      _sourceRevision++;
      _disposeUnattachedProvider();
      _provider = null; // A mounted old TileLayer owns/disposes its provider.
      _providerAttached = false;
      _plan = null;
      _tiles.clear();
      _initialCacheChecked = false;
      _minimumElapsed = false;
      _showMap = false;
      _presented = false;
      _notified = false;
      _warmupAttached = false;
      oldWidget.warmup?.removeListener(_warmupChanged);
      if (widget.warmup != oldWidget.warmup) oldWidget.warmup?.dispose();
      _listenToWarmup();
    }
    if (_minimumWait != null && widget.revealWithParent) {
      _finishMinimumWait();
    }
  }

  void _queueCheck() {
    if (_checkScheduled || !mounted || _showMap || !_minimumElapsed) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || _showMap || _plan == null || !_minimumElapsed) return;
      if (_plan!.tiles.every((tile) {
        final image = _tiles[tile];
        return image != null && (image.imageInfo != null || image.loadError);
      })) {
        _reveal();
      }
    });
  }

  Widget _tileBuilder(BuildContext context, Widget child, TileImage tile) {
    if (!_showMap && (_plan?.tiles.contains(tile.coordinates) ?? false)) {
      _tiles[tile.coordinates] = tile;
      _queueCheck();
    }
    return child;
  }

  void _handleTileError(TileImage tile, Object error, StackTrace? stack) {
    if (!mounted || tile.cancelLoading.isCompleted) return;
    final retry = _retriedTiles.add(tile.coordinates);
    if (!retry) return;
    // Keep this tile pending during its single retry, rather than releasing
    // the placeholder on the first failed attempt.
    tile.loadError = false;
    tile.loadFinishedAt = null;
    final revision = _sourceRevision;
    _retryTimers[tile.coordinates] = Timer(RouteMapSurface.retryDelay, () {
      _retryTimers.remove(tile.coordinates);
      unawaited(_retryTile(tile, revision));
    });
  }

  Future<void> _retryTile(TileImage tile, int revision) async {
    if (!mounted ||
        revision != _sourceRevision ||
        tile.cancelLoading.isCompleted) {
      return;
    }
    // Error streams can still be cached. Evict only this image, not the map's
    // successful tiles; TileImage.load then subscribes to a fresh stream.
    await tile.imageProvider.evict();
    if (mounted &&
        revision == _sourceRevision &&
        !tile.cancelLoading.isCompleted) {
      tile.load();
    }
  }

  void _finishMinimumWait() {
    _minimumWait?.cancel();
    _minimumWait = null;
    if (!mounted || _showMap) return;
    _minimumElapsed = true;
    _queueCheck();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _cancelWaits() {
    _deadline?.cancel();
    _minimumWait?.cancel();
    _minimumWait = null;
  }

  void _cancelRetries() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retriedTiles.clear();
  }

  void _disposeUnattachedProvider() {
    // The initial camera frame may still be pending: in that case no
    // TileLayer has mounted and taken ownership of this HTTP client yet.
    if (!_providerAttached) _provider?.dispose();
  }

  void _reveal() {
    if (!mounted || _showMap) return;
    _cancelWaits();
    _tiles.clear();
    setState(() {
      _showMap = true;
      _presented = !_animateReveal;
    });
    if (_presented) _notify();
  }

  void _fadeEnded() {
    if (!_showMap || _presented) return;
    setState(() => _presented = true);
    _notify();
  }

  void _notify() {
    if (_notified || _notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!mounted || !_presented || _notified) return;
      _notified = true;
      widget.onPresented?.call();
    });
  }

  @override
  void dispose() {
    widget.warmup?.removeListener(_warmupChanged);
    widget.warmup?.dispose();
    _cancelWaits();
    _cancelRetries();
    _disposeUnattachedProvider();
    _tiles.clear();
    super.dispose();
  }

  Widget _buildTileLayer(BuildContext context, Widget? layer) {
    if (!_initialCameraReady && widget.options.initialCameraFit != null) {
      final camera = MapCamera.of(context);
      if (!_initialCameraFrameScheduled &&
          !camera.nonRotatedSize.isEmpty &&
          camera.nonRotatedSize.isFinite) {
        _initialCameraFrameScheduled = true;
        // FlutterMap applies initialCameraFit after its first nonzero layout.
        // Mount tiles in the following build, when inherited MapCamera has
        // caught up. Otherwise a fast image completion can prune fitted tiles
        // against the old camera and leave unstarted replacements forever.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _initialCameraReady = true);
        });
      }
      return const SizedBox.shrink();
    }
    // This belongs to the map's initialization, not its tile source. Keep it
    // ready on URL/token changes or normal camera moves in the editors.
    _initialCameraReady = true;
    if (!_warmupAttached) {
      final warmup =
          widget.warmup?.matches(widget.url, widget.accessToken) == true
          ? widget.warmup
          : null;
      if (warmup?.canAttach == false) return const SizedBox.shrink();
      _retriedTiles.addAll(warmup?.attach() ?? {});
      _warmupAttached = true;
    }
    if (layer != null) _providerAttached = true;
    return layer ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final animateReveal = !widget.revealWithParent && !reduceMotion;
      final layer = widget.url == null
          ? null
          : RouteMapTiles.layer(
              url: widget.url!,
              accessToken: widget.accessToken,
              provider: _provider ??=
                  widget.tileProviderFactory?.call() ??
                  RouteMapTiles.networkProvider(),
              maxNativeZoom: widget.maxNativeZoom,
              maxZoom: widget.maxZoom,
              tileBuilder: _tileBuilder,
              errorTileCallback: _handleTileError,
              presented: _presented && !reduceMotion,
            );
      if (!size.isEmpty && size.isFinite && !_showMap) {
        final plan = RouteMapTilePlan.initial(
          options: widget.options,
          size: size,
          visibleInsets: widget.visibleInsets,
          maxNativeZoom: widget.maxNativeZoom,
        );
        if (_plan == null || !setEquals(_plan!.tiles, plan.tiles)) {
          _plan = plan;
          _tiles.clear();
        }
        if (!_initialCacheChecked) {
          _initialCacheChecked = true;
          final decodedCache =
              layer != null && RouteMapTiles.allDecoded(plan, layer);
          if (layer == null || decodedCache) {
            // Set the initial opacity before AnimatedOpacity mounts: no flash
            // and no extra fade for already decoded tiles.
            _showMap = true;
            _presented = true;
            _notify();
          } else {
            _minimumElapsed = !animateReveal;
            if (animateReveal) {
              _minimumWait = Timer(
                RouteMapSurface.minimumPlaceholderDuration,
                _finishMinimumWait,
              );
            }
            _deadline = Timer(RouteMapSurface.waitLimit, _reveal);
          }
        }
      }
      return RouteMapSurfaceScope(
        presented: _presented,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_presented && !widget.revealWithParent)
              const Positioned.fill(child: RouteMapPlaceholder()),
            IgnorePointer(
              ignoring: !_presented,
              child: AnimatedOpacity(
                key: const ValueKey('route-map-fade'),
                opacity: _showMap ? 1 : 0,
                duration: animateReveal
                    ? RouteMapSurface.fadeDuration
                    : Duration.zero,
                curve: Curves.easeOut,
                onEnd: _fadeEnded,
                child: FlutterMap(
                  mapController: widget.mapController,
                  options: widget.options,
                  children: [
                    Builder(
                      builder: (context) => _buildTileLayer(
                        context,
                        layer == null
                            ? null
                            : ColorFiltered(
                                key: ObjectKey(_provider),
                                colorFilter: const ColorFilter.matrix(<double>[
                                  1,
                                  0,
                                  0,
                                  0,
                                  -10,
                                  0,
                                  0.95,
                                  0,
                                  0,
                                  -10,
                                  0,
                                  0,
                                  0.88,
                                  0,
                                  -10,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                                child: layer,
                              ),
                      ),
                    ),
                    ...widget.children,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class RouteMapSurfaceScope extends InheritedWidget {
  final bool presented;
  const RouteMapSurfaceScope({
    super.key,
    required this.presented,
    required super.child,
  });
  static bool isPresented(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RouteMapSurfaceScope>()
          ?.presented ??
      true;
  @override
  bool updateShouldNotify(RouteMapSurfaceScope oldWidget) =>
      presented != oldWidget.presented;
}

class RouteMapPlaceholder extends StatefulWidget {
  static const sweepDuration = Duration(milliseconds: 1500);

  const RouteMapPlaceholder({super.key});
  @override
  State<RouteMapPlaceholder> createState() => _RouteMapPlaceholderState();
}

class _RouteMapPlaceholderState extends State<RouteMapPlaceholder>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: RouteMapPlaceholder.sweepDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MapPlaceholderPainter(
            _sweep,
            animate: !MediaQuery.disableAnimationsOf(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// Paint only the loading surface, without rebuilding or masking the map.
class _MapPlaceholderPainter extends CustomPainter {
  static const _gradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color.fromRGBO(255, 255, 255, 0.06),
      Color(0x00FFFFFF),
    ],
    stops: [0, 0.5, 1],
  );

  final Animation<double> progress;
  final bool animate;
  final _backgroundPaint = Paint()..color = AppColors.background;
  final _highlightPaint = Paint();

  _MapPlaceholderPainter(this.progress, {required this.animate})
    : super(repaint: animate ? progress : null);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, _backgroundPaint);
    if (!animate || size.isEmpty) return;

    final width = size.width * 0.8;
    // The band begins/ends completely outside the surface so looping has no
    // jump. Only the band moves; the opaque background never changes colour.
    final left = (size.width + width) * progress.value - width;
    _highlightPaint.shader = _gradient.createShader(
      Rect.fromLTWH(left, 0, width, size.height),
    );
    canvas.drawRect(bounds, _highlightPaint);
  }

  @override
  bool shouldRepaint(_MapPlaceholderPainter oldDelegate) =>
      progress != oldDelegate.progress || animate != oldDelegate.animate;
}
