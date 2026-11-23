import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/navigation/route_arguments.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/template_model.dart';
import '../../services/map_configuration.dart';
import '../../services/template_api_service.dart';
import '../../services/user_session.dart';
import '../../services/notification_service.dart';
import '../../utils/route_formatters.dart';
import '../../widgets/address_widgets.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_content_switcher.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/animated_touch_templates.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import '../../widgets/map/route_map_surface.dart';
import '../../widgets/top_bar_widget.dart';
import '../../widgets/shimmer_placeholder.dart';

class SavedTemplatesScreen extends StatefulWidget {
  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;

  const SavedTemplatesScreen({
    super.key,
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required this.selectedDays,
  });

  @override
  State<SavedTemplatesScreen> createState() => _SavedTemplatesScreenState();
}

class _SavedTemplatesScreenState extends State<SavedTemplatesScreen> {
  final TemplateApiService _templateApiService = TemplateApiService(ApiClient().dio);

  bool _isLoading = true;
  List<TemplateResponseModel> _templates = [];

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();

  bool get _isDriver => UserSession().currentMode == AppMode.driver;
  Color get _pinColor => _isDriver ? AppColors.driverAccent : AppColors.passengerAccent;
  Color get _iconColor => _isDriver ? AppColors.driver : AppColors.passenger;
  Color get _polyColor => _isDriver ? AppColors.driverRouteLine : AppColors.passengerRouteLine;

  final Set<String> _deletingTemplateIds = <String>{};

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    try {
      final minimumLoadingTime = Future<void>.delayed(
        AppDurations.minimumScreenLoading,
      );

      final parsedTemplates = await _templateApiService.getTemplates(
        isDriver: _isDriver,
      );

      if (!mounted) return;

      await Future.wait([
        minimumLoadingTime,
        // Miniatures must not keep the entire list behind its skeleton.
        // A timeout only stops waiting; cards can reuse the pending images.
        _precacheMapImages(parsedTemplates).timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () {},
        ),
      ]);

      if (mounted) {
        setState(() {
          _templates = parsedTemplates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationService.showError(e);
      }
    }
  }

  Future<void> _precacheMapImages(List<TemplateResponseModel> templates) async {
    final mapAccessToken = MapConfiguration().mapAccessToken;
    if (mapAccessToken == null) return;

    final urlsToPrecache = templates.map((item) {
      final template = item.template;
      final encodedPolyline = Uri.encodeComponent(template.routePolyline);
      final polyHex = _polyColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase();
      final pinHex = _pinColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase();

      final routePath = 'path-4+$polyHex-1.0($encodedPolyline)';
      final startMarker = 'pin-s+$pinHex(${template.startLon},${template.startLat})';
      final endMarker = 'pin-s+ffffff(${template.endLon},${template.endLat})';
      final overlays = '$routePath,$startMarker,$endMarker';

      return 'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/static/'
          '$overlays/auto/160x160@2x?padding=25,25,25,25&access_token=$mapAccessToken';
    }).toList();
    await Future.wait(urlsToPrecache.map((url) {
      return precacheImage(
        NetworkImage(url),
        context,
        onError: (error, stackTrace) {
          // Optional warmup: the card's errorBuilder shows the map fallback.
        },
      );
    }).toList());
  }

  Future<void> _deleteTemplate(String id) async {
    if (_deletingTemplateIds.contains(id)) return;

    final confirmed = await AppDialogs.show(
      context,
      title: AppLocalizations.of(context)!.deleteTemplate,
      content: AppLocalizations.of(context)!.sureToDeleteTemplate,
      primaryButtonText: AppLocalizations.of(context)!.delete,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    if (_deletingTemplateIds.contains(id)) return;

    setState(() {
      _deletingTemplateIds.add(id);
    });

    try {
      await _templateApiService.deleteTemplate(id);

      if (!mounted) return;

      final index = _templates.indexWhere(
            (item) => item.template.id == id,
      );

      if (index == -1) {
        setState(() {
          _deletingTemplateIds.remove(id);
        });
        return;
      }

      final removedItem = _templates[index];

      _listKey.currentState?.removeItem(
        index,
            (context, animation) {
          return _buildAnimatedTemplateItem(
            removedItem,
            animation,
            forceDisabled: true,
          );
        },
        duration: const Duration(milliseconds: 500),
      );

      setState(() {
        _templates.removeAt(index);
        _deletingTemplateIds.remove(id);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _deletingTemplateIds.remove(id);
      });

      NotificationService.showError(error);
    }
  }

  Widget _buildAnimatedTemplateItem(
      TemplateResponseModel itemData,
      Animation<double> animation, {
        bool forceDisabled = false,
      }) {
    final templateData = itemData.template;

    final isDeleting = forceDisabled ||
        _deletingTemplateIds.contains(templateData.id);

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: const Interval(
          0,
          0.5,
          curve: Curves.easeInCubic,
        ),
      ),
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(
            0.5,
            1,
            curve: Curves.linear,
          ),
        ),
        child: _TemplateCard(
          key: ValueKey(templateData.id),
          template: templateData,
          iconColor: _iconColor,
          pinColor: _pinColor,
          polyColor: _polyColor,
          isDeleting: isDeleting,
          onDelete: () {
            _deleteTemplate(templateData.id);
          },
          onSelect: () {
            final origin = templateData.originAddress;
            final destination = templateData.destinationAddress;

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
                  isFromSavedTemplates: true,
                  preloadedRouteWithStops: itemData.toRouteWithStopsModel(),
                  waypoints: templateData.waypoints.map((waypoint) {
                    return LatLng(
                      waypoint.lat,
                      waypoint.lon,
                    );
                  }).toList(),
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
                  isFromSavedTemplates: true,
                  preloadedRoute: templateData.toRouteModel(),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = AppBottomSafeFadeOverlay.extentOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppTopBarOverlayLayout(
        title: AppLocalizations.of(context)!.savedTemplates,
        leadingIcon: Icons.arrow_back_rounded,
        onLeadingTap: () => context.pop(),
        contentOverlap: AppDimens.gapSm,
        bodyBuilder: (context, topInset) {
          return Stack(
            children: [
              Positioned.fill(
                child: AppContentSwitcher(
                  child: _isLoading
                      ? _buildSkeletonList(
                          topInset: topInset,
                          bottomInset: safeBottom,
                        )
                      : _templates.isEmpty
                      ? Padding(
                          padding: EdgeInsets.only(top: topInset),
                          child: _buildEmptyState(),
                        )
                      : AppScrollbar(
                          controller: _scrollController,
                          mainAxisMargin: 0,
                          padding: EdgeInsets.only(
                            top: AppTopBarOverlayLayout.contentInsetOf(context),
                            bottom: AppScrollbar.screenBottomInsetOf(
                              context,
                              clearance: AppDimens.gapLg,
                            ),
                            right: AppScrollbar.screenRightInsetOf(context),
                          ),
                          child: AnimatedList(
                            key: _listKey,
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              top: topInset,
                              bottom: safeBottom,
                            ),
                            physics: const BouncingScrollPhysics(),
                            initialItemCount: _templates.length,
                            itemBuilder: (context, index, animation) {
                              return _buildAnimatedTemplateItem(
                                _templates[index],
                                animation,
                              );
                            },
                          ),
                        ),
                ),
              ),

              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomSafeFadeOverlay(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Align(
      key: const ValueKey('empty_state'),
      alignment: const Alignment(0, -0.25),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gap2xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                color: Colors.white24,
                size: 40,
              ),
            ),
            const SizedBox(height: AppDimens.gapXl),
            Text(
              AppLocalizations.of(context)!.noSavedTemplates,
              style: AppText.screenTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.gapMd),
            Text(
              AppLocalizations.of(context)!.routeWillAppear,
              style: AppText.bodySecondary.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList({
    required double topInset,
    required double bottomInset,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return ListView.builder(
      key: const ValueKey('skeleton_list'),
      primary: false,
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(
            left: AppDimens.pagePadding,
            right: AppDimens.pagePadding,
            top: AppDimens.gapSm,
            bottom: AppDimens.gapXl,
          ),
          padding: const EdgeInsets.all(AppDimens.gapLg),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.surfaceBr,
            border: Border.all(
              color: AppColors.borderSubtle,
              width: AppDimens.borderWidth,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonMetric(
                    l10n.travelTime,
                    RouteFormatters.formatDuration(context, 1800),
                  ),
                  const SizedBox(width: AppDimens.gapXl),
                  _buildSkeletonMetric(
                    l10n.distance,
                    RouteFormatters.formatDistance(context, 12000),
                  ),
                  const Spacer(),
                  const ShimmerBlock(
                    width: 42,
                    height: 42,
                    borderRadius: AppRadius.small,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.gapLg),
              Row(
                children: [
                  const ShimmerBlock(
                    width: 80,
                    height: 80,
                    borderRadius: AppRadius.medium,
                  ),
                  const SizedBox(width: AppDimens.gapLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSkeletonAddressLine(iconSize: 18),
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: AppDimens.gapSm,
                            horizontal: 2,
                          ),
                          height: AppDimens.dividerThickness,
                          color: AppColors.borderSubtle,
                        ),
                        _buildSkeletonAddressLine(iconSize: 21),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const ShimmerBlock(
                width: double.infinity,
                height: AppDimens.compactHeight,
                borderRadius: AppRadius.medium,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerPlaceholder(child: Text(label, style: AppText.metricLabel)),
        const SizedBox(height: AppDimens.gapXs),
        ShimmerPlaceholder(
          child: Text(value, style: AppText.metricValueCompact),
        ),
      ],
    );
  }

  Widget _buildSkeletonAddressLine({required double iconSize}) {
    return Row(
      children: [
        ShimmerBlock(
          width: iconSize,
          height: iconSize,
          borderRadius: iconSize / 2,
        ),
        const SizedBox(width: AppDimens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerPlaceholder(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(' ', style: AppText.listTitle, maxLines: 1),
                ),
              ),
              const SizedBox(height: 2),
              const FractionallySizedBox(
                widthFactor: 0.7,
                child: ShimmerPlaceholder(
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(' ', style: AppText.listSubtitle, maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final VoidCallback onDelete;
  final VoidCallback onSelect;
  final Color pinColor;
  final Color iconColor;
  final Color polyColor;
  final bool isDeleting;

  const _TemplateCard({
    super.key,
    required this.template,
    required this.onDelete,
    required this.onSelect,
    required this.pinColor,
    required this.iconColor,
    required this.polyColor,
    this.isDeleting = false,
  });



  @override
  Widget build(BuildContext context) {
    final mapAccessToken = MapConfiguration().mapAccessToken;

    return IgnorePointer(
      ignoring: isDeleting,
      child: AnimatedOpacity(
        duration: AppDurations.fieldState,
        opacity: isDeleting ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.only(
            left: AppDimens.pagePadding,
            right: AppDimens.pagePadding,
            top: AppDimens.gapSm,
            bottom: AppDimens.gapXl,
          ),
          padding: const EdgeInsets.all(AppDimens.gapLg),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.surfaceBr,
            border: Border.all(
              color: AppColors.borderSoft,
              width: AppDimens.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.travelTime,
                        style: AppText.metricLabel,
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        RouteFormatters.formatDuration(context, template.totalDurationSeconds),
                        style: AppText.metricValueCompact,
                      ),
                    ],
                  ),

                  const SizedBox(width: AppDimens.gapXl),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.distance,
                        style: AppText.metricLabel,
                      ),
                      const SizedBox(height: AppDimens.gapXs),
                      Text(
                        RouteFormatters.formatDistance(context, template.totalDistanceMeters),
                        style: AppText.metricValueCompact,
                      ),
                    ],
                  ),

                  const Spacer(),

                  AnimatedTouchItem(
                    onTap: onDelete,
                    normalColor: AppColors.surface,
                    pressedColor: Colors.redAccent.withValues(alpha: 0.2),
                    pressedScale: 0.95,
                    borderRadius: AppRadius.smallBr,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.compactControlBr,
                      color: Colors.black12,
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.compactControlBr,
                      child: Builder(
                        builder: (context) {
                          if (mapAccessToken == null) return const SizedBox();
                          final encodedPolyline = Uri.encodeComponent(template.routePolyline);
                          final polyHex = polyColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase();
                          final pinHex = pinColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase();
                          final routePath = 'path-4+$polyHex-1.0($encodedPolyline)';
                          final startMarker = 'pin-s+$pinHex(${template.startLon},${template.startLat})';
                          final endMarker = 'pin-s+ffffff(${template.endLon},${template.endLat})';
                          final overlays = '$routePath,$startMarker,$endMarker';
                          final staticMapUrl = 'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/static/'
                              '$overlays'
                              '/auto/160x160@2x'
                              '?padding=25,25,25,25'
                              '&access_token=$mapAccessToken';

                          return Image.network(
                            staticMapUrl,
                            fit: BoxFit.cover,
                            frameBuilder: (context, child, frame, synchronous) {
                              if (synchronous) return child;
                              return TweenAnimationBuilder<double>(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : RouteMapSurface.fadeDuration,
                                curve: Curves.easeOut,
                                tween: Tween(end: frame == null ? 0.0 : 1.0),
                                child: child,
                                builder: (context, opacity, image) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (opacity < 1)
                                      const RouteMapPlaceholder(),
                                    Opacity(opacity: opacity, child: image),
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.map_rounded, color: Colors.white24, size: 30);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AddressLine(
                          icon: Icons.radio_button_checked,
                          iconColor: iconColor,
                          title: template.startShortAddress,
                          iconSize: 18,
                          subtitle: template.startSubtitle,
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: AppDimens.gapSm,
                            horizontal: 2,
                          ),
                          height: AppDimens.dividerThickness,
                          color: AppColors.borderSubtle,
                        ),

                        _AddressLine(
                          icon: Icons.location_on,
                          iconColor: Colors.white70,
                          title: template.endShortAddress,
                          iconSize: 21,
                          subtitle: template.endSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              AnimatedTouchItem(
                onTap: onSelect,
                normalColor: AppColors.surfacePressed,
                pressedColor: AppColors.surfaceStrong,
                borderRadius: AppRadius.compactControlBr,
                child: SizedBox(
                  height: AppDimens.compactHeight,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.select,
                      style: AppText.compactButton,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double iconSize;
  final String? subtitle;

  const _AddressLine({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.iconSize = 18.0,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: AppDimens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.listTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppText.listSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
