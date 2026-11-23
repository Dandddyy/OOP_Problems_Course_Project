import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error_codes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip_model.dart';
import '../../models/trip_search_model.dart';
import '../../services/notification_service.dart';
import '../../services/trip_search_api_service.dart';
import '../../utils/uuid.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_content_switcher.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_screen_message.dart';
import '../../widgets/top_bar_widget.dart';
import '../../widgets/trip_search/trip_search_result_card.dart';

enum _SearchBlock { busy, rateLimited }

class TripSearchResultsScreen extends StatefulWidget {
  final TripSearchRequestModel request;
  final TripSearchGateway? api;

  const TripSearchResultsScreen({super.key, required this.request, this.api});

  @override
  State<TripSearchResultsScreen> createState() =>
      _TripSearchResultsScreenState();
}

class _TripSearchResultsScreenState extends State<TripSearchResultsScreen> {
  final _scrollController = ScrollController();
  late final TripSearchGateway _api;
  CancelToken _cancel = CancelToken();
  Timer? _keepAliveCooldown;
  bool _isKeepingAlive = false;
  List<TripSearchResultModel> _items = const [];
  TripSearchPageModel? _page;
  _SearchBlock? _searchBlock;
  Object? _pageError;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  int _generation = 0;

  bool get _isRegularRide =>
      widget.request.scheduleType == TripScheduleType.recurring;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TripSearchApiService(ApiClient().dio);
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_search());
  }

  @override
  void dispose() {
    _keepAliveCooldown?.cancel();
    _cancel.cancel('Results screen closed');
    _scrollController.dispose();
    super.dispose();
  }

  bool _isCurrent(int generation) =>
      generation == _generation && !_cancel.isCancelled;

  Future<void> _keepAliveOnActivity() async {
    final page = _page;
    if (page == null ||
        _isRefreshing ||
        _keepAliveCooldown != null ||
        _isKeepingAlive ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.isCurrentOf(context) != true) {
      return;
    }

    _keepAliveCooldown = Timer(const Duration(minutes: 1), () {
      _keepAliveCooldown = null;
    });
    _isKeepingAlive = true;
    try {
      await _api.keepAlive(page.searchId, cancelToken: _cancel);
    } on Exception {
      // Renewal is best effort. Loaded cards remain usable after cache expiry.
    } finally {
      _isKeepingAlive = false;
    }
  }

  Future<void> _search({bool refresh = false}) async {
    if (_isLoading || _isRefreshing) return;
    _cancel.cancel('Search replaced');
    _cancel = CancelToken();
    final generation = ++_generation;
    setState(() {
      _isLoading = !refresh;
      _isRefreshing = refresh;
      _isLoadingMore = false;
      _searchBlock = null;
    });

    final minimumWait = Completer<void>();
    final timer = Timer(
      AppDurations.minimumScreenLoading,
      minimumWait.complete,
    );
    unawaited(
      _cancel.whenCancel.then((_) {
        if (timer.isActive) {
          timer.cancel();
          minimumWait.complete();
        }
      }),
    );

    try {
      final page = await _api.search(
        widget.request.copyWith(requestId: generateUuidV4()),
        cancelToken: _cancel,
      );
      if (!mounted || !_isCurrent(generation)) return;
      _validatePage(page);
      if (refresh && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      setState(() {
        _page = page;
        _items = page.items;
        _pageError = null;
      });
    } catch (error) {
      if (!mounted || !_isCurrent(generation)) return;
      if (refresh) {
        _showErrorNotification(error);
        return;
      }
      final response = error is DioException ? error.response : null;
      final data = response?.data;
      if (response?.statusCode == 429) {
        setState(() => _searchBlock = _SearchBlock.rateLimited);
        return;
      }
      if (isServiceBusyError(error)) {
        setState(() => _searchBlock = _SearchBlock.busy);
        return;
      }

      if (ModalRoute.of(context)?.isCurrent != true) return;
      final l10n = AppLocalizations.of(context)!;
      final router = GoRouter.maybeOf(context);
      if (response?.statusCode == 400 &&
          data is Map &&
          data['code'] == ApiErrorCodes.tripDepartureInPast &&
          router != null &&
          router.canPop()) {
        final message = data['message'];
        router.pop<String>(
          data['showUser'] == true &&
                  message is String &&
                  message.trim().isNotEmpty
              ? message
              : l10n.publicationDepartureInPast,
        );
        return;
      }
      final message = _errorMessage(l10n, error);
      if (router != null && router.canPop()) {
        router.pop();
      } else {
        await Navigator.of(context).maybePop();
      }
      NotificationService.showError(message);
    } finally {
      await minimumWait.future;
      if (mounted && _isCurrent(generation)) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _schedulePaginationCheck();
      }
    }
  }

  void _maybeLoadMore() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 400) {
      unawaited(_loadNext());
    }
  }

  void _schedulePaginationCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });
  }

  Future<void> _loadNext({bool retry = false}) async {
    final page = _page;
    if (_isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        page == null ||
        !page.hasMore ||
        (_pageError != null && !retry)) {
      return;
    }
    final generation = _generation;
    final cursor = page.nextCursor;
    setState(() {
      _isLoadingMore = true;
      _pageError = null;
    });
    try {
      final next = await _api.getPage(
        page.searchId,
        cursor: cursor,
        cancelToken: _cancel,
      );
      if (!mounted || !_isCurrent(generation)) return;
      _validatePage(next, previousCursor: cursor);
      if (next.searchId != page.searchId) {
        throw const FormatException(
          'A result page belongs to a different search',
        );
      }
      setState(() {
        _items = [..._items, ...next.items];
        _page = next;
      });
    } catch (error) {
      if (mounted && _isCurrent(generation)) {
        setState(() => _pageError = error);
        if (!_requiresNewSearch(error)) _showErrorNotification(error);
      }
    } finally {
      if (mounted && _isCurrent(generation)) {
        setState(() => _isLoadingMore = false);
        _schedulePaginationCheck();
      }
    }
  }

  void _validatePage(TripSearchPageModel page, {String? previousCursor}) {
    if (page.hasMore &&
        (page.nextCursor == null || page.nextCursor == previousCursor)) {
      throw const FormatException('Search pagination did not advance');
    }
    if (page.items.any((item) => item.occurrences.isEmpty)) {
      throw const FormatException('A route has no matched occurrence');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppTopBarOverlayLayout(
        title: l10n.routes,
        fitTitleOnOneLine: true,
        leadingIcon: Icons.arrow_back_rounded,
        onLeadingTap: () => context.pop(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerAction(Icons.sort_rounded, l10n.tripSearchSort),
            const SizedBox(width: AppDimens.gapSm),
            _headerAction(Icons.tune_rounded, l10n.tripSearchFilter),
          ],
        ),
        bodyBuilder: (context, topInset) {
          final bottomInset = AppScrollbar.screenBottomInsetOf(
            context,
            clearance: AppDimens.gapLg,
          );
          final padding = EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            topInset,
            AppDimens.pagePadding,
            bottomInset,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: AppContentSwitcher(
                  child: _isLoading
                      ? ListView.separated(
                          key: const ValueKey('trip-search-skeleton'),
                          padding: padding,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 3,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.gapLg),
                          itemBuilder: (_, _) => TripSearchResultCardSkeleton(
                            isRegularRide: _isRegularRide,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('trip-search-content'),
                          child: _buildContent(context, padding),
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

  Widget _headerAction(IconData icon, String label) => Semantics(
    label: label,
    button: true,
    enabled: true,
    child: AppSquareButton(icon: icon, onTap: () {}, hasShadow: false),
  );

  Widget _buildContent(BuildContext context, EdgeInsets padding) {
    final l10n = AppLocalizations.of(context)!;
    if (_searchBlock == _SearchBlock.rateLimited) {
      return AppScreenMessage(
        topInset: padding.top,
        icon: Icons.schedule_rounded,
        title: l10n.tripSearchRateLimited,
        description: l10n.tryAgainLater,
      );
    }
    if (_searchBlock == _SearchBlock.busy) {
      return AppScreenMessage.serviceBusy(
        context: context,
        topInset: padding.top,
        title: l10n.tripSearchBusy,
        onRetry: _search,
      );
    }
    if (_page == null) return const SizedBox.expand();
    if (_items.isEmpty) {
      return AppScreenMessage(
        topInset: padding.top,
        icon: Icons.route_rounded,
        title: l10n.tripSearchEmpty,
        description: l10n.tripSearchEmptyHint,
      );
    }
    final results = AppScrollbar(
      controller: _scrollController,
      mainAxisMargin: 0,
      padding: EdgeInsets.only(
        top: padding.top,
        bottom: padding.bottom,
        right: AppScrollbar.screenRightInsetOf(context),
      ),
      child: ListView.separated(
        key: const ValueKey('trip-search-results'),
        controller: _scrollController,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount:
            _items.length + (_isLoadingMore || _pageError != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapLg),
        itemBuilder: (context, index) {
          if (index == _items.length) return _paginationFooter(l10n);
          return TripSearchResultCard(
            key: ValueKey('trip-search-result-${_items[index].tripId}'),
            result: _items[index],
            onTap: () {
              // TODO: Open route details when the passenger details screen is implemented.
            },
          );
        },
      ),
    );
    return Listener(
      onPointerDown: (_) => unawaited(_keepAliveOnActivity()),
      onPointerMove: (_) => unawaited(_keepAliveOnActivity()),
      onPointerPanZoomUpdate: (_) => unawaited(_keepAliveOnActivity()),
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) unawaited(_keepAliveOnActivity());
      },
      child: results,
    );
  }

  Widget _paginationFooter(AppLocalizations l10n) {
    if (_isLoadingMore || _isRefreshing) {
      return TripSearchResultCardSkeleton(
        key: const ValueKey('trip-search-loading-more'),
        isRegularRide: _isRegularRide,
      );
    }
    final error = _pageError!;
    final expired = _requiresNewSearch(error);
    return Padding(
      key: const ValueKey('trip-search-page-error'),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.gapLg),
      child: Column(
        children: [
          Text(
            expired ? l10n.tripSearchExpired : l10n.tripSearchLoadMoreFailed,
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
          if (expired) ...[
            const SizedBox(height: AppDimens.gapSm),
            Text(
              _errorMessage(l10n, error),
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppDimens.gapMd),
          AppPillButton(
            onTap: expired
                ? () => _search(refresh: true)
                : () => _loadNext(retry: true),
            hasShadow: false,
            child: Text(
              expired ? l10n.tripSearchRefresh : l10n.retry,
              style: AppText.compactButton,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorNotification(Object error) {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    NotificationService.showError(
      _errorMessage(AppLocalizations.of(context)!, error),
    );
  }

  String _errorMessage(AppLocalizations l10n, Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['showUser'] == true) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return l10n.noInternetConnection;
      }
      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return l10n.requestTimedOut;
      }
    }
    return l10n.somethingWentWrong;
  }

  bool _requiresNewSearch(Object error) {
    if (error is! DioException) return false;
    final data = error.response?.data;
    return error.response?.statusCode == 410 ||
        data is Map &&
            const {
              ApiErrorCodes.tripSearchExpired,
              ApiErrorCodes.tripSearchChanged,
              ApiErrorCodes.tripSearchGraphChanged,
              ApiErrorCodes.tripSearchVariantExpired,
              ApiErrorCodes.tripSearchNewSearchRequired,
            }.contains(data['code']);
  }
}
