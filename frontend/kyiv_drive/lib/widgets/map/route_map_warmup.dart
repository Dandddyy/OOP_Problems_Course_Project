import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

import 'route_map_tiles.dart';

/// One optional warmup attempt per tile. On adoption the visible layer owns
/// the one remaining retry; failed warmup tiles must not receive two more.
class RouteMapWarmup extends ChangeNotifier {
  static const retryDelay = Duration(milliseconds: 200);

  /// Completes when the background tile attempts have settled.
  late final Future<void> completed;
  final String? _url;
  final String _accessToken;
  final _failed = <TileCoordinates>{};
  final _cooldowns = <TileCoordinates, Timer>{};
  bool _adopted = false;
  bool _attached = false;
  bool _disposed = false;

  RouteMapWarmup({
    required RouteMapTilePlan plan,
    required TileLayer layer,
    required ImageConfiguration configuration,
  }) : _url = layer.urlTemplate,
       _accessToken = layer.additionalOptions['accessToken'] ?? '' {
    completed = RouteMapTiles.precache(
      plan: plan,
      layer: layer,
      configuration: configuration,
      isCurrent: () => !_disposed && !_adopted,
      onTileError: (tile) =>
          _failedDuringWarmup(tile, RouteMapTiles.image(tile, layer)),
    );
  }

  void _failedDuringWarmup(TileCoordinates tile, ImageProvider image) {
    if (_disposed || _attached || !_failed.add(tile)) return;
    _cooldowns[tile] = Timer(retryDelay, () {
      unawaited(_releaseFailure(tile, image));
    });
  }

  Future<void> _releaseFailure(
    TileCoordinates tile,
    ImageProvider image,
  ) async {
    if (_disposed) return;
    await image.evict();
    _cooldowns.remove(tile);
    if (!_disposed) notifyListeners();
  }

  // Stop queued background work, but retain in-flight streams in ImageCache.
  void adopt() => _adopted = true;
  bool matches(String? url, String? accessToken) =>
      _url == url && _accessToken == (accessToken ?? '');
  bool get canAttach => _cooldowns.isEmpty;

  Set<TileCoordinates> attach() {
    assert(canAttach);
    _attached = true;
    return Set.of(_failed);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _cooldowns.values) {
      timer.cancel();
    }
    _cooldowns.clear();
    super.dispose();
  }
}

/// The source owns a warmup until take(); the destination then owns it.
class RouteMapWarmupController {
  RouteMapWarmup? _current;
  Object? _request;
  Set<TileCoordinates>? _tiles;

  void warm({
    required RouteMapTilePlan plan,
    required String url,
    required String? accessToken,
    required ImageConfiguration configuration,
    TileProvider Function()? tileProviderFactory,
  }) {
    final request = (
      url,
      accessToken,
      plan.camera.center,
      plan.camera.zoom,
      plan.camera.nonRotatedSize,
      configuration.devicePixelRatio,
      tileProviderFactory,
    );
    if (_request == request && setEquals(_tiles, plan.tiles)) return;
    cancel();
    _request = request;
    _tiles = Set.of(plan.tiles);
    _current = RouteMapWarmup(
      plan: plan,
      configuration: configuration,
      layer: RouteMapTiles.layer(
        url: url,
        accessToken: accessToken,
        maxNativeZoom: 18,
        maxZoom: 20,
        provider:
            tileProviderFactory?.call() ??
            RouteMapTiles.networkProvider(abortObsoleteRequests: false),
      ),
    );
  }

  RouteMapWarmup? take() {
    final warmup = _current;
    _current = null;
    return warmup;
  }

  /// Revalidate the target at the actual tap, even if a source rebuild has not
  /// yet run its background preloader callback for a newly selected address.
  RouteMapWarmup? takeFor({
    required BuildContext context,
    required MapOptions options,
    required String? url,
    required String? accessToken,
    EdgeInsets visibleInsets = EdgeInsets.zero,
    TileProvider Function()? tileProviderFactory,
  }) {
    final size = MediaQuery.sizeOf(context);
    if (url == null || accessToken == null || size.isEmpty || !size.isFinite) {
      cancel();
      return null;
    }
    warm(
      plan: RouteMapTilePlan.initial(
        options: options,
        size: size,
        visibleInsets: visibleInsets,
        maxNativeZoom: 18,
      ),
      url: url,
      accessToken: accessToken,
      configuration: createLocalImageConfiguration(context),
      tileProviderFactory: tileProviderFactory,
    );
    return take();
  }

  void cancel() {
    _current?.dispose();
    _current = null;
    _request = null;
    _tiles = null;
  }

  void dispose() => cancel();
}

/// Warms only the exact destination viewport, without a hidden FlutterMap.
class RouteMapPreloader extends StatefulWidget {
  final RouteMapWarmupController controller;
  final MapOptions options;
  final String? url;
  final String? accessToken;
  final EdgeInsets visibleInsets;
  final bool enabled;
  final TileProvider Function()? tileProviderFactory;

  const RouteMapPreloader({
    super.key,
    required this.controller,
    required this.options,
    required this.url,
    required this.accessToken,
    this.visibleInsets = EdgeInsets.zero,
    this.enabled = true,
    this.tileProviderFactory,
  });

  @override
  State<RouteMapPreloader> createState() => _RouteMapPreloaderState();
}

class _RouteMapPreloaderState extends State<RouteMapPreloader> {
  int _revision = 0;
  @override
  Widget build(BuildContext context) {
    final revision = ++_revision;
    final size = MediaQuery.sizeOf(context);
    final config = createLocalImageConfiguration(context);
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final plan =
        widget.enabled &&
            currentRoute &&
            widget.url != null &&
            widget.accessToken != null &&
            !size.isEmpty &&
            size.isFinite
        ? RouteMapTilePlan.initial(
            options: widget.options,
            size: size,
            visibleInsets: widget.visibleInsets,
            maxNativeZoom: 18,
          )
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      if (plan == null) {
        widget.controller.cancel();
      } else {
        widget.controller.warm(
          plan: plan,
          url: widget.url!,
          accessToken: widget.accessToken,
          configuration: config,
          tileProviderFactory: widget.tileProviderFactory,
        );
      }
    });
    return const SizedBox.shrink();
  }
}
