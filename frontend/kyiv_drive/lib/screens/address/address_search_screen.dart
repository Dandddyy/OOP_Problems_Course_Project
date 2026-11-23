import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../core/navigation/route_arguments.dart';
import '../../core/network/api_client.dart';
import '../../services/notification_service.dart';
import '../../services/user_session.dart';
import '../../widgets/animated_touch_templates.dart';
import '../../l10n/app_localizations.dart';
import '../../models/address_model.dart';
import '../../services/map_api_service.dart';
import '../../services/map_configuration.dart';
import '../../services/location_service.dart';
import '../../core/map/pin_map_layout.dart';
import '../../core/constants/map_bounds.dart';
import '../../widgets/map/route_map_warmup.dart';
import '../../utils/input_validation.dart';
import '../../widgets/address_widgets.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_content_switcher.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/keyboard_dismiss_on_background_tap.dart';
import '../../widgets/top_bar_widget.dart';

class AddressSearchScreen extends StatefulWidget {
  final AddressModel? initialOrigin;
  final AddressModel? initialDestination;
  final bool focusOnDestination;

  final bool isRegularRide;
  final DateTime selectedDateTime;
  final String selectedTime;
  final List<bool> selectedDays;

  const AddressSearchScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.focusOnDestination = true,
    required this.isRegularRide,
    required this.selectedDateTime,
    required this.selectedTime,
    required this.selectedDays,
  });

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  late TextEditingController _originController;
  late TextEditingController _destinationController;
  final ScrollController _resultsScrollController = ScrollController();

  final FocusNode _originFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  final MapApiService _mapApiService = MapApiService(ApiClient().dio);

  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSearchingOrigin = false;

  int _currentSearchId = 0;

  List<AddressModel> _originResultsCache = [];
  List<AddressModel> _destinationResultsCache = [];

  String _lastOriginQuery = "";
  String _lastDestinationQuery = "";

  List<AddressModel> _results = [];

  AddressModel? _selectedOrigin;
  AddressModel? _selectedDestination;

  bool _isTransitioning = false;
  bool _isMapPickerOpen = false;
  final _selectionWarmup = RouteMapWarmupController();
  Future<LatLng?>? _silentLocation;
  LatLng? _gpsMapLocation;
  bool _isPreparingMapLocation = false;

  AddressModel? get _activeMapAddress => _isSearchingOrigin
      ? _selectedOrigin ?? _selectedDestination
      : _selectedDestination ?? _selectedOrigin;

  LatLng get _mapStartLocation {
    final address = _activeMapAddress;
    return address == null
        ? _gpsMapLocation ?? PinMapLayout.kyiv
        : LatLng(address.lat, address.lon);
  }

  void _prepareSilentLocation() {
    if (_selectedOrigin != null ||
        _selectedDestination != null ||
        _silentLocation != null) {
      return;
    }
    _isPreparingMapLocation = true;
    _silentLocation = _fetchMapLocation();
  }

  Future<LatLng?> _fetchMapLocation() async {
    try {
      final pos = await LocationService.getStartupLocation();
      final point = LatLng(pos.latitude, pos.longitude);
      if (!KyivServiceArea.contains(point)) return null;
      if (mounted) {
        _gpsMapLocation = point;
      }
      return point;
    } catch (_) {
      // Optional camera warmup never prompts for permissions or shows errors.
      return null;
    } finally {
      _isPreparingMapLocation = false;
      if (mounted && !_isMapPickerOpen) setState(() {});
    }
  }

  bool get _isDriver => UserSession().currentMode == AppMode.driver;
  Color get _brandColor => _isDriver ? AppColors.driver : AppColors.passenger;
  Color get _cursorColor => _isDriver ? AppColors.driverText : AppColors.passengerText;

  static const _addressSelectionDelay =
  Duration(milliseconds: 150);

  static const _mapSelectionDelay =
  Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _isSearchingOrigin = !widget.focusOnDestination;

    _selectedOrigin = widget.initialOrigin;
    _selectedDestination = widget.initialDestination;
    _prepareSilentLocation();

    final originText = _selectedOrigin?.fullAddress ?? "";
    final destText = _selectedDestination?.fullAddress ?? "";

    _originController = TextEditingController(text: originText);
    _destinationController = TextEditingController(text: destText);

    _lastOriginQuery = originText.trim();
    _lastDestinationQuery = destText.trim();

    if (_selectedOrigin != null) {
      _originResultsCache = [_selectedOrigin!];
    }
    if (_selectedDestination != null) {
      _destinationResultsCache = [_selectedDestination!];
    }

    _originFocus.addListener(() {
      if (_originFocus.hasFocus) {
        setState(() {
          _isSearchingOrigin = true;
          _restoreOrSearch(_originController.text, true);
        });
      }
    });

    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() {
          _isSearchingOrigin = false;
          _restoreOrSearch(_destinationController.text, false);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.focusOnDestination) {
        FocusScope.of(context).requestFocus(_destinationFocus);
      } else {
        FocusScope.of(context).requestFocus(_originFocus);
      }
    });
  }

  @override
  void dispose() {
    _selectionWarmup.dispose();
    _debounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _restoreOrSearch(String query, bool isOrigin) {
    final trimmedQuery = query.trim();

    if (isOrigin) {
      if (trimmedQuery == _lastOriginQuery) {
        setState(() {
          _results = List.from(_originResultsCache);
          _isLoading = false;

          bool isAlreadySelected = _selectedOrigin != null && trimmedQuery == _selectedOrigin!.fullAddress;

          _errorMessage = (_results.isEmpty && trimmedQuery.isNotEmpty && !isAlreadySelected)
              ? AppLocalizations.of(context)!.unknownLocation
              : null;
        });
        return;
      }
    } else {
      if (trimmedQuery == _lastDestinationQuery) {
        setState(() {
          _results = List.from(_destinationResultsCache);
          _isLoading = false;

          bool isAlreadySelected = _selectedDestination != null && trimmedQuery == _selectedDestination!.fullAddress;

          _errorMessage = (_results.isEmpty && trimmedQuery.isNotEmpty && !isAlreadySelected)
              ? AppLocalizations.of(context)!.unknownLocation
              : null;
        });
        return;
      }
    }

    setState(() {
      _results = [];
    });

    _onSearchChanged(query, isOrigin: isOrigin);
  }

  void _onSearchChanged(String query, {required bool isOrigin}) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _currentSearchId++;
    final int searchId = _currentSearchId;
    final trimmedQuery = query.trim();

    if (isOrigin && _selectedOrigin != null && trimmedQuery != _selectedOrigin!.fullAddress) {
      _selectedOrigin = null;
    } else if (!isOrigin && _selectedDestination != null && trimmedQuery != _selectedDestination!.fullAddress) {
      _selectedDestination = null;
    }
    _prepareSilentLocation();

    if (trimmedQuery.isEmpty) {
      setState(() {
        if (isOrigin) {
          _lastOriginQuery = "";
          _originResultsCache = [];
        } else {
          _lastDestinationQuery = "";
          _destinationResultsCache = [];
        }

        if (_isSearchingOrigin == isOrigin) {
          _results = [];
          _isLoading = false;
          _errorMessage = null;
        }
      });
      return;
    }

    if ((isOrigin && trimmedQuery == _lastOriginQuery) ||
        (!isOrigin && trimmedQuery == _lastDestinationQuery)) {

      if (_isSearchingOrigin == isOrigin) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final int validCharsLength = InputValidation.countAddressSearchCharacters(trimmedQuery);

    if (validCharsLength < InputValidation.minimumAddressSearchCharacters) {
      setState(() {
        if (_isSearchingOrigin == isOrigin) {
          _results = [];
          _isLoading = false;
          _errorMessage = null;
        }
      });
      return;
    }

    setState(() {
      if (_isSearchingOrigin == isOrigin) {
        _isLoading = true;
        _errorMessage = null;
      }
    });

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _fetchAutocomplete(trimmedQuery, searchId, isOrigin: isOrigin);
    });
  }

  Future<void> _fetchAutocomplete(String text, int searchId, {required bool isOrigin}) async {
    try {
      final results = await _mapApiService.autocomplete(text: text);

      if (!mounted || searchId != _currentSearchId) return;

      setState(() {
        if (isOrigin) {
          _lastOriginQuery = text;
          _originResultsCache = List.from(results);
        } else {
          _lastDestinationQuery = text;
          _destinationResultsCache = List.from(results);
        }

        if (_isSearchingOrigin == isOrigin) {
          _results = results;
          _isLoading = false;
          if (results.isEmpty) {
            _errorMessage = AppLocalizations.of(context)!.unknownLocation;
          }
        }
      });
    } catch (e) {
      if (!mounted || searchId != _currentSearchId) return;

      setState(() {
        if (_isSearchingOrigin == isOrigin) {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.unknownLocation;
        }
      });
    }
  }

  Future<void> _onAddressSelected(
      AddressModel address, {
        Duration transitionDelay = _addressSelectionDelay,
      }) async {
    if (_isTransitioning) return;

    final displayString = address.fullAddress;

    setState(() {
      if (_isSearchingOrigin) {
        _originController.text = displayString;
        _lastOriginQuery = displayString;
        _selectedOrigin = address;

        _originResultsCache = [address];
        _results = List.from(_originResultsCache);

        if (_selectedDestination == null) {
          FocusScope.of(context).requestFocus(_destinationFocus);
        }
      } else {
        _destinationController.text = displayString;
        _lastDestinationQuery = displayString;
        _selectedDestination = address;

        _destinationResultsCache = [address];
        _results = List.from(_destinationResultsCache);

        if (_selectedOrigin == null) {
          FocusScope.of(context).requestFocus(_originFocus);
        }
      }
    });

    if (_selectedOrigin == null || _selectedDestination == null) {
      return;
    }

    if (_selectedOrigin!.lat == _selectedDestination!.lat &&
        _selectedOrigin!.lon == _selectedDestination!.lon) {
      NotificationService.showError(
        AppLocalizations.of(context)!.selectDifferentLocations,
      );
      return;
    }

    setState(() {
      _isTransitioning = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();

    await Future<void>.delayed(transitionDelay);

    if (!mounted) return;

    _openRoutePreview();
  }

  void _openRoutePreview() {
    if (_isDriver) {
      context.pushReplacement(
        '/route-preview-driver',
        extra: DriverRoutePreviewArgs(
          origin: _selectedOrigin!,
          destination: _selectedDestination!,
          isRegularRide: widget.isRegularRide,
          selectedDateTime: widget.selectedDateTime,
          selectedTime: widget.selectedTime,
          selectedDays: widget.selectedDays,
        ),
      );
    } else {
      context.pushReplacement(
        '/route-preview-passenger',
        extra: PassengerRoutePreviewArgs(
          origin: _selectedOrigin!,
          destination: _selectedDestination!,
          isRegularRide: widget.isRegularRide,
          selectedDateTime: widget.selectedDateTime,
          selectedTime: widget.selectedTime,
          selectedDays: widget.selectedDays,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isTransitioning,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AbsorbPointer(
          absorbing: _isTransitioning,
          child: KeyboardDismissOnBackgroundTap(
            child: Column(
              children: [
                RouteMapPreloader(
                  controller: _selectionWarmup,
                  options: PinMapLayout.address(location: _mapStartLocation),
                  url: MapConfiguration().mapUrlTemplate,
                  accessToken: MapConfiguration().mapAccessToken,
                  visibleInsets: PinMapLayout.addressInsets(
                    MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  enabled: !_isTransitioning &&
                      !_isMapPickerOpen &&
                      (_activeMapAddress != null || !_isPreparingMapLocation),
                ),
                AppTopBar(
                  title: AppLocalizations.of(context)!.route,
                  leadingIcon: Icons.arrow_back_rounded,
                  onLeadingTap: () {
                    if (_isTransitioning) return;

                    FocusManager.instance.primaryFocus?.unfocus();
                    context.pop();
                  },
                  bottomPadding: AppDimens.gapXl,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
                  child: Column(
                    children: [
                      AuthTextField(
                        controller: _originController,
                        focusNode: _originFocus,
                        hint: AppLocalizations.of(context)!.where,
                        icon: Icons.radio_button_checked,
                        focusColor: _brandColor,
                        cursorColor: _cursorColor,
                        inputAction: TextInputAction.go,
                        onChanged: (val) => _onSearchChanged(val, isOrigin: true),
                        formatters: [
                          LengthLimitingTextInputFormatter(100),
                          FilteringTextInputFormatter.deny(
                            InputValidation.disallowedAddressCharacters,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      AuthTextField(
                        controller: _destinationController,
                        focusNode: _destinationFocus,
                        hint: AppLocalizations.of(context)!.whereGoing,
                        icon: Icons.location_on,
                        focusColor: _brandColor,
                        cursorColor: _cursorColor,
                        inputAction: TextInputAction.go,
                        onChanged: (val) => _onSearchChanged(val, isOrigin: false),
                        formatters: [
                          LengthLimitingTextInputFormatter(100),
                          FilteringTextInputFormatter.deny(
                            InputValidation.disallowedAddressCharacters,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.gapXl),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: AppDimens.dividerThickness,
                        color: AppColors.borderMuted,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
                      child: Text(
                        AppLocalizations.of(context)!.suggestedAddresses,
                        style: AppText.caption,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: AppDimens.dividerThickness,
                        color: AppColors.borderMuted,
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: _buildBody(),
                ),

                _buildMapButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final results = _results;
    final isSearchingOrigin = _isSearchingOrigin;
    Widget content;

    if (_errorMessage != null && !_isLoading) {
      content = Center(
        key: const ValueKey("error_state"),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gap2xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                color: AppColors.textDisabled,
                size: 56,
              ),
              const SizedBox(height: AppDimens.gapLg),
              Text(
                _errorMessage!,
                style: AppText.bodyStrong.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.gapMd),
              Text(
                AppLocalizations.of(context)!.refineSearchHint,
                style: AppText.bodySecondary.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (results.isEmpty && _isLoading) {
      content = IgnorePointer(
        key: const ValueKey('skeleton_state'),
        ignoring: true,
        child: ListView.builder(
          primary: false,
          padding: const EdgeInsets.only(top: AppDimens.gapSm),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) {
            final isLast = index == 4;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AddressRow(
                  iconWidget: Icon(
                    isSearchingOrigin
                        ? Icons.near_me_rounded
                        : Icons.location_on_outlined,
                    color: Colors.white24,
                    size: 24,
                  ),
                  text: "",
                  textColor: Colors.transparent,
                  isLoading: true,
                ),
                if (!isLast)
                  Container(
                    height: AppDimens.dividerThickness,
                    color: AppColors.borderMuted,
                    margin: const EdgeInsets.only(
                      left: 56,
                      right: AppDimens.gapLg,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    } else if (results.isEmpty) {
      content = const SizedBox.shrink(key: ValueKey("empty_state"));
    }

    else {
      content = AnimatedOpacity(
        key: const ValueKey("results_state"),
        duration: AppDurations.fieldState,
        opacity: _isLoading ? 0.35 : 1.0,
        child: IgnorePointer(
          ignoring: _isLoading,
          child: AppScrollbar(
            controller: _resultsScrollController,
            mainAxisMargin: AppDimens.gapXs,
            padding: EdgeInsets.only(
              right: AppScrollbar.screenRightInsetOf(context),
            ),
            child: ListView.builder(
              controller: _resultsScrollController,
              padding: const EdgeInsets.only(top: AppDimens.gapSm),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final address = results[index];
                final isLast = index == results.length - 1;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AddressRow(
                      key: ObjectKey(address),
                      iconWidget: Icon(
                        isSearchingOrigin
                            ? Icons.near_me_rounded
                            : Icons.location_on_outlined,
                        color: Colors.white54,
                        size: 24,
                      ),
                      text: address.shortAddress ??
                          AppLocalizations.of(context)!.unknownLocation,
                      subtitle: address.subtitle,
                      textColor: Colors.white,
                      onTap: () {
                        _onAddressSelected(
                          address,
                          transitionDelay: _addressSelectionDelay,
                        );
                      },
                    ),
                    if (!isLast)
                      Container(
                        height: AppDimens.dividerThickness,
                        color: Colors.white10,
                        margin: const EdgeInsets.only(
                          left: 56,
                          right: AppDimens.gapLg,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    final String currentActiveText = _isSearchingOrigin
        ? _originController.text
        : _destinationController.text;

    final bool shouldBeInstant =
        InputValidation.countAddressSearchCharacters(currentActiveText) <
        InputValidation.minimumAddressSearchCharacters;

    if (shouldBeInstant) {
      return content;
    }

    return AppContentSwitcher(
      child: content,
      durationForTransition: (from, to) =>
          from == const ValueKey('skeleton_state') &&
              to == const ValueKey('results_state')
          ? AppDurations.fieldState
          : AppDurations.screenCrossFade,
    );
  }

  Widget _buildMapButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.borderSubtle,
            width: AppDimens.borderWidth,
          ),
        ),
      ),
      child: AppBottomSafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.pagePadding,
            right: AppDimens.pagePadding,
            top: AppDimens.gapMd,
          ),
          child: AnimatedTouchItem(
            onTap: () async {
              if (_isMapPickerOpen || _isTransitioning) return;
              final startLoc = _mapStartLocation;
              final warmup = _selectionWarmup.takeFor(
                context: context,
                options: PinMapLayout.address(location: startLoc),
                url: MapConfiguration().mapUrlTemplate,
                accessToken: MapConfiguration().mapAccessToken,
                visibleInsets: PinMapLayout.addressInsets(
                  MediaQuery.viewPaddingOf(context).bottom,
                ),
              );
              _isMapPickerOpen = true;
              FocusManager.instance.primaryFocus?.unfocus();
              final AddressModel? selectedAddress;
              try {
                selectedAddress = await context.push<AddressModel>(
                  '/map-selection',
                  extra: MapSelectionRouteArgs(
                    initialLocation: startLoc,
                    tileWarmup: warmup,
                    userLocation: _silentLocation,
                    isRegularRide: widget.isRegularRide,
                    selectedDateTime: widget.selectedDateTime,
                    selectedTime: widget.selectedTime,
                    selectedDays: widget.selectedDays,
                  ),
                );
              } finally {
                warmup?.dispose();
                if (mounted) setState(() => _isMapPickerOpen = false);
              }

              if (selectedAddress != null && mounted) {
                await _onAddressSelected(
                  selectedAddress,
                  transitionDelay: _mapSelectionDelay,
                );
              }
            },
            normalColor: AppColors.surface,
            pressedColor: AppColors.surfacePressed,
            pressedScale: 0.97,
            borderRadius: AppRadius.compactControlBr,
            child: SizedBox(
              height: AppDimens.compactHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: AppColors.iconSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Text(
                    AppLocalizations.of(context)!.selectOnMap,
                    style: AppText.compactButton.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
