import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';

/// Kept identical for editor layout and its background tile warmup.
abstract final class RouteEditorMapLayout {
  static const initialSheetSize = 0.48;

  static EdgeInsets visibleInsets(double screenHeight) =>
      EdgeInsets.only(bottom: screenHeight * initialSheetSize);

  static CameraFit cameraFit(
    List<LatLng> points,
    double screenHeight, {
    double sheetSize = initialSheetSize,
  }) => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(points),
    padding: EdgeInsets.only(
      top: 100,
      left: 36,
      right: 36,
      bottom: screenHeight * sheetSize + AppDimens.gapLg,
    ),
  );

  static MapOptions options(List<LatLng> points, double screenHeight) =>
      MapOptions(
        backgroundColor: AppColors.background,
        initialCameraFit: cameraFit(points, screenHeight),
        minZoom: 11,
        maxZoom: 18,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(49.86, 29.95),
            const LatLng(50.9, 31.15),
          ),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      );
}

class RouteMapTilePlan {
  final MapCamera camera;
  final Set<TileCoordinates> tiles;

  RouteMapTilePlan._(this.camera, this.tiles);

  factory RouteMapTilePlan.initial({
    required MapOptions options,
    required Size size,
    EdgeInsets visibleInsets = EdgeInsets.zero,
    int maxNativeZoom = 19,
  }) {
    final initial = MapCamera.initialCamera(options).withNonRotatedSize(size);
    final fitted = options.initialCameraFit?.fit(initial) ?? initial;
    final candidate = fitted.withPosition(zoom: initial.clampZoom(fitted.zoom));
    final camera = options.cameraConstraint.constrain(candidate) ?? initial;
    return RouteMapTilePlan.forCamera(
      camera,
      visibleInsets: visibleInsets,
      maxNativeZoom: maxNativeZoom,
    );
  }

  factory RouteMapTilePlan.forCamera(
    MapCamera camera, {
    EdgeInsets visibleInsets = EdgeInsets.zero,
    int maxNativeZoom = 19,
  }) {
    // Same rounding and pixel bounds as flutter_map's TileRangeCalculator.
    final zoom = camera.zoom.round().clamp(0, maxNativeZoom);
    final scale = camera.getZoomScale(camera.zoom, zoom.toDouble());
    final projected = camera.projectAtZoom(camera.center, zoom.toDouble());
    final center = Offset(
      projected.dx.floorToDouble(),
      projected.dy.floorToDouble(),
    );
    final half = Offset(camera.size.width, camera.size.height) / (scale * 2);
    final rect = Rect.fromLTRB(
      center.dx - half.dx + visibleInsets.left / scale,
      center.dy - half.dy + visibleInsets.top / scale,
      center.dx + half.dx - visibleInsets.right / scale,
      center.dy + half.dy - visibleInsets.bottom / scale,
    );
    final tiles = <TileCoordinates>{};
    if (!rect.isEmpty) {
      final world = 1 << zoom;
      for (
        var x = (rect.left / 256).floor();
        x < (rect.right / 256).ceil();
        x++
      ) {
        for (
          var y = (rect.top / 256).floor();
          y < (rect.bottom / 256).ceil();
          y++
        ) {
          if (y >= 0 && y < world) {
            tiles.add(TileCoordinates(x % world, y, zoom));
          }
        }
      }
    }
    return RouteMapTilePlan._(camera, tiles);
  }
}

abstract final class RouteMapTiles {
  static final _neverCancel = Completer<void>().future;

  static TileProvider networkProvider({bool abortObsoleteRequests = true}) =>
      _RouteNetworkTileProvider(abortObsoleteRequests: abortObsoleteRequests);

  static TileLayer layer({
    required String url,
    required String? accessToken,
    required TileProvider provider,
    int maxNativeZoom = 19,
    double maxZoom = double.infinity,
    TileBuilder? tileBuilder,
    ErrorTileCallBack? errorTileCallback,
    bool presented = false,
  }) => TileLayer(
    urlTemplate: url,
    additionalOptions: {'accessToken': accessToken ?? ''},
    tileProvider: provider,
    maxNativeZoom: maxNativeZoom,
    maxZoom: maxZoom,
    tileBuilder: tileBuilder,
    errorTileCallback: errorTileCallback,
    tileDisplay: presented
        ? const TileDisplay.fadeIn(duration: Duration(milliseconds: 200))
        : const TileDisplay.instantaneous(),
  );

  static ImageProvider image(TileCoordinates tile, TileLayer layer) =>
      layer.tileProvider.supportsCancelLoading
      ? layer.tileProvider.getImageWithCancelLoadingSupport(
          tile,
          layer,
          _neverCancel,
        )
      : layer.tileProvider.getImage(tile, layer);

  /// NetworkTileImageProvider returns synchronous keys. Pending downloads do
  /// not count as decoded images, even if ImageCache already calls them live.
  static bool allDecoded(RouteMapTilePlan plan, TileLayer layer) {
    return plan.tiles.every((tile) {
      var decoded = false;
      image(tile, layer).obtainKey(ImageConfiguration.empty).then((key) {
        final status = PaintingBinding.instance.imageCache.statusForKey(key);
        decoded = !status.pending && (status.keepAlive || status.live);
      });
      return decoded;
    });
  }

  /// Warm only the editor's visible starting tiles, at most four at a time.
  /// In-flight images may be adopted by the editor through ImageCache, so don't
  /// cancel them on navigation or close their HTTP client before they settle.
  static Future<void> precache({
    required RouteMapTilePlan plan,
    required TileLayer layer,
    required ImageConfiguration configuration,
    required bool Function() isCurrent,
    void Function(TileCoordinates)? onTileError,
  }) async {
    final tiles = plan.tiles.toList();
    var next = 0;
    Future<void> worker() async {
      while (isCurrent() && next < tiles.length) {
        final tile = tiles[next++];
        final provider = image(tile, layer);
        final stream = provider.resolve(configuration);
        final done = Completer<void>();
        late final ImageStreamListener listener;
        void finish() {
          stream.removeListener(listener);
          if (!done.isCompleted) done.complete();
        }

        listener = ImageStreamListener(
          (info, _) {
            finish();
            info.dispose();
          },
          onError: (Object error, StackTrace? stack) {
            // Warmup is optional. Failed images are not reported as cache hits;
            // the visible map retains its own loading/error handling.
            onTileError?.call(tile);
            finish();
          },
        );
        stream.addListener(listener);
        await done.future;
      }
    }

    try {
      await Future.wait(List.generate(4, (_) => worker()));
    } finally {
      await Future<void>.sync(layer.tileProvider.dispose);
    }
  }
}

/// The visible layer owns the single retry, including decode failures. Avoid
/// NetworkTileProvider's additional default HTTP 503 retries underneath it.
class _RouteNetworkTileProvider extends NetworkTileProvider {
  final http.Client _client;

  _RouteNetworkTileProvider({required bool abortObsoleteRequests})
    : this._(http.Client(), abortObsoleteRequests);

  _RouteNetworkTileProvider._(this._client, bool abortObsoleteRequests)
    : super(httpClient: _client, abortObsoleteRequests: abortObsoleteRequests);

  @override
  Future<void> dispose() {
    _client.close();
    return super.dispose();
  }
}

/// Zero-layout warmup; no hidden second FlutterMap or extra render tree.
class RouteEditorTilePreloader extends StatefulWidget {
  final List<LatLng> points;
  final String? url;
  final String? accessToken;
  final bool enabled;
  final TileProvider Function()? tileProviderFactory;

  const RouteEditorTilePreloader({
    super.key,
    required this.points,
    required this.url,
    required this.accessToken,
    this.enabled = true,
    this.tileProviderFactory,
  });

  @override
  State<RouteEditorTilePreloader> createState() =>
      _RouteEditorTilePreloaderState();
}

class _RouteEditorTilePreloaderState extends State<RouteEditorTilePreloader> {
  Object? _request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(RouteEditorTilePreloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    final size = MediaQuery.sizeOf(context);
    if (!widget.enabled ||
        widget.url == null ||
        widget.points.length < 2 ||
        size.isEmpty) {
      _request = null;
      return;
    }
    final plan = RouteMapTilePlan.initial(
      options: RouteEditorMapLayout.options(widget.points, size.height),
      size: size,
      maxNativeZoom: 18,
      visibleInsets: RouteEditorMapLayout.visibleInsets(size.height),
    );
    final request = (
      widget.url,
      widget.accessToken,
      plan.camera.center,
      plan.camera.zoom,
      size,
    );
    if (_request == request) return;
    _request = request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _request != request) return;
      final provider =
          widget.tileProviderFactory?.call() ??
          RouteMapTiles.networkProvider(abortObsoleteRequests: false);
      final layer = RouteMapTiles.layer(
        url: widget.url!,
        accessToken: widget.accessToken,
        provider: provider,
        maxNativeZoom: 18,
        maxZoom: 20,
      );
      unawaited(
        RouteMapTiles.precache(
          plan: plan,
          layer: layer,
          configuration: createLocalImageConfiguration(context),
          isCurrent: () => mounted && _request == request,
        ),
      );
    });
  }

  @override
  void dispose() {
    _request = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
