import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../services/home_map_startup.dart';
import '../../services/user_session.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/map/route_map_warmup.dart';
import '../splash/splash_page.dart';
import 'home_screen.dart';

class HomeMapStartupScreen extends StatefulWidget {
  /// Remaining tile loading continues on the very same map behind the shimmer.
  static const splashTileWait = HomeMapStartup.tileWaitLimit;

  final AppMode mode;
  final TileProvider Function()? tileProviderFactory;

  const HomeMapStartupScreen({
    super.key,
    required this.mode,
    this.tileProviderFactory,
  });

  @override
  State<HomeMapStartupScreen> createState() => _HomeMapStartupScreenState();
}

class _HomeMapStartupScreenState extends State<HomeMapStartupScreen> {
  HomeMapStart? _start;
  RouteMapWarmup? _tileWarmup;
  Timer? _deadline;
  bool _showSplash = true;
  bool _homeVisible = false;
  bool _requestedPermission = false;

  @override
  void initState() {
    super.initState();
    final loginStart = UserSession().takeLoginMapStart();
    if (loginStart == null) {
      unawaited(_prepare());
    } else {
      _start = loginStart;
      _tileWarmup = loginStart.tileWarmup;
      _showSplash = false;
      _homeVisible = true;
    }
  }

  @override
  void didUpdateWidget(HomeMapStartupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      // The old map owns the warmup and disposes it when its mode key changes.
      _tileWarmup = null;
    }
  }

  Future<void> _prepare() async {
    final start = await HomeMapStartup.take();
    if (!mounted) return;
    setState(() => _start = start);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showSplash) return;
      _deadline = Timer(HomeMapStartupScreen.splashTileWait, _revealHome);
    });
  }

  void _revealHome() {
    if (!mounted || !_showSplash) return;
    _deadline?.cancel();
    setState(() {
      _showSplash = false;
      _homeVisible = MediaQuery.disableAnimationsOf(context);
    });
  }

  void _splashHidden() {
    if (!mounted || _showSplash || _homeVisible) return;
    setState(() => _homeVisible = true);
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: !_homeVisible,
          child: AbsorbPointer(
            absorbing: !_homeVisible,
            child: start == null
                ? const ColoredBox(color: AppColors.background)
                : HomeScreen(
                    key: ValueKey(widget.mode),
                    initialMap: HomeMapStart(
                      location: start.location,
                      requestPermissionOnHome:
                          start.requestPermissionOnHome &&
                          !_requestedPermission,
                      tileWarmup: _tileWarmup,
                    ),
                    startupVisible: _homeVisible,
                    onStartupLocationRequested: () =>
                        _requestedPermission = true,
                    onMapPresented: _revealHome,
                    tileProviderFactory: widget.tileProviderFactory,
                  ),
          ),
        ),
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            key: const ValueKey('home-startup-splash'),
            opacity: _showSplash ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : RouteMapSurface.fadeDuration,
            curve: Curves.easeOut,
            onEnd: _splashHidden,
            child: _homeVisible
                ? const SizedBox.shrink()
                : const SplashPage(prepareHomeMap: false),
          ),
        ),
      ],
    );
  }
}
