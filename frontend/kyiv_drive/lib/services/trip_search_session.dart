import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error_codes.dart';
import '../models/trip_search_model.dart';
import '../utils/uuid.dart';
import 'trip_search_api_service.dart';

/// Owns one results screen's data and recovery. No requests run until [start].
class TripSearchSession extends ChangeNotifier {
  final TripSearchGateway _api;
  final DateTime Function() _now;
  final String Function() _requestId;
  final Duration idleTimeout;
  final Duration heartbeatInterval;
  final int maxRestoreItems;
  final bool automaticHeartbeat;

  TripSearchSession(
    this._api, {
    DateTime Function()? now,
    String Function()? requestId,
    this.idleTimeout = const Duration(minutes: 5),
    this.heartbeatInterval = const Duration(minutes: 1),
    this.maxRestoreItems = 200,
    this.automaticHeartbeat = true,
  }) : _now = now ?? DateTime.now,
       _requestId = requestId ?? generateUuidV4;

  List<TripSearchResultModel> _items = const [];
  List<TripSearchResultModel> get items => _items;
  TripSearchRequestModel? _original;
  TripSearchPreferencesRequestModel? _desired;
  TripSearchPreferencesRequestModel? get preferences => _desired;
  TripSearchPageModel? _page;
  TripSearchPageModel? get page => _page;
  String? _serverId;
  String? _nextCursor;
  String? _previousCursor;
  bool get hasMore => _nextCursor != null;
  bool get hasPrevious => _previousCursor != null;
  DateTime? _expiresAt;
  DateTime? get expiresAt => _expiresAt;
  Object? _error;
  Object? get error => _error;
  bool _errorPending = false;

  /// Returns the latest foreground error once for a UI notification.
  Object? takeError() {
    if (!_errorPending) return null;
    _errorPending = false;
    return _error;
  }

  Object? _backgroundError;
  Object? get backgroundError => _backgroundError;
  bool _visible = false;
  bool _requiresRefresh = false;
  bool get requiresRefresh => _requiresRefresh;
  bool _resultsUpdated = false;
  bool get resultsUpdated => _resultsUpdated;
  String? _visibleTripId;
  String? _scrollAnchorTripId;
  String? get scrollAnchorTripId => _scrollAnchorTripId;
  int? get scrollAnchorIndex {
    final index = _items.indexWhere(
      (item) => item.tripId == _scrollAnchorTripId,
    );
    return index < 0 ? null : index;
  }

  int _root = 0;
  int _epoch = 0;
  int _preferencesRevision = 0;
  int _listRevision = 0;
  int get listRevision => _listRevision;
  bool _disposed = false;
  bool _needsFullRecovery = false;
  bool _needsVariantRecovery = false;
  DateTime? _lastActivity;
  DateTime? _lastHeartbeat;
  Timer? _timer;
  CancelToken _cancel = CancelToken();
  Future<void>? _starting;
  String? _startSignature;
  Future<void>? _settings;
  Future<void>? _next;
  Future<void>? _previous;
  Future<void>? _heartbeat;
  Future<_SearchResponse>? _recovery;
  bool get isStarting => _starting != null;
  bool get isUpdatingPreferences => _settings != null;
  bool get isLoadingNext => _next != null;
  bool get isLoadingPrevious => _previous != null;
  bool get isRecovering => _recovery != null;
  bool get isLoading => isStarting || isUpdatingPreferences || isRecovering;

  void setVisible(bool value) {
    if (_disposed) return;
    _visible = value;
    _timer?.cancel();
    _timer = null;
    if (value) {
      _checkIdle();
      if (automaticHeartbeat) {
        _timer = Timer.periodic(
          heartbeatInterval,
          (_) => unawaited(keepAliveIfActive()),
        );
      }
    }
    _notify();
  }

  /// Call from actual scroll/tap activity and report the first visible trip.
  void recordActivity({String? visibleTripId}) {
    if (_disposed) return;
    final wasExpired = _requiresRefresh;
    _checkIdle();
    if (!_requiresRefresh) _lastActivity = _now();
    if (visibleTripId != null) _visibleTripId = visibleTripId;
    if (!wasExpired && _requiresRefresh) _notify();
  }

  void _checkIdle() {
    final expiry = _expiresAt;
    final activity = _lastActivity;
    if (expiry != null &&
        activity != null &&
        !_now().isBefore(expiry) &&
        _now().difference(activity) >= idleTimeout) {
      _requiresRefresh = true;
    }
  }

  Future<void> start(TripSearchRequestModel request) {
    if (_disposed) return Future.value();
    final signature = jsonEncode(request.toJson());
    if (_starting != null && _startSignature == signature) return _starting!;
    _cancel.cancel('Search replaced');
    _cancel = CancelToken();
    final root = ++_root;
    _epoch++;
    _preferencesRevision++;
    _original = request.copyWith(
      requestId: null,
      anchorTripId: null,
      restoreResultCount: null,
    );
    _desired = request.preferences;
    _serverId = null;
    _nextCursor = null;
    _previousCursor = null;
    _settings = null;
    _next = null;
    _previous = null;
    _recovery = null;
    _heartbeat = null;
    _lastHeartbeat = null;
    _error = null;
    _errorPending = false;
    _backgroundError = null;
    _requiresRefresh = false;
    _needsFullRecovery = false;
    _needsVariantRecovery = false;
    _lastActivity = _now();
    _visibleTripId = null;
    final revision = _preferencesRevision;
    _startSignature = signature;
    final execution = request.copyWith(
      requestId: request.requestId ?? _requestId(),
    );
    late final Future<void> work;
    work = _start(execution, root, revision).whenComplete(() {
      if (_root == root && identical(_starting, work)) {
        _starting = null;
        _startSignature = null;
        _notify();
      }
    });
    _starting = work;
    _notify();
    return work;
  }

  Future<void> _start(
    TripSearchRequestModel execution,
    int root,
    int revision,
  ) async {
    try {
      final result = await _api.search(execution, cancelToken: _cancel);
      _ensure(root);
      _adopt(result, execution);
      if (_preferencesRevision == revision) {
        _replace(result, preserveAnchor: false);
      }
    } on _StaleSearchOperation {
      return;
    } catch (error) {
      if (_current(root)) {
        _foregroundFailure(error);
      }
    }
  }

  Future<void> refresh() {
    final request = _original;
    final desired = _desired;
    if (request == null || desired == null) return Future.value();
    return start(
      request.copyWith(
        preferences: desired,
        requestId: null,
        anchorTripId: null,
        restoreResultCount: null,
      ),
    );
  }

  Future<void> updatePreferences(
    TripSearchPreferencesRequestModel preferences,
  ) {
    if (_disposed || _original == null) return Future.value();
    recordActivity();
    _desired = preferences;
    _preferencesRevision++;
    _epoch++;
    if (_requiresRefresh) {
      _notify();
      return Future.value();
    }
    if (_settings != null) return _settings!;
    _error = null;
    _errorPending = false;
    final root = _root;
    late final Future<void> work;
    work = _applySettings(root).whenComplete(() {
      if (_root == root && identical(_settings, work)) {
        _settings = null;
        _notify();
      }
    });
    _settings = work;
    _notify();
    return work;
  }

  Future<void> _applySettings(int root) async {
    final starting = _starting;
    if (starting != null) await starting;
    if (!_current(root) || _serverId == null) return;
    while (_current(root)) {
      final revision = _preferencesRevision;
      final desired = _desired!;
      try {
        final response = await _perform(
          (id) => _api.reprioritize(
            id,
            desired.forApplication(),
            cancelToken: _cancel,
          ),
          root,
          revision: revision,
          preserveAnchor: false,
        );
        if (response.revision != _preferencesRevision) continue;
        _replace(response.page, preserveAnchor: false);
        return;
      } on _StaleSearchOperation {
        if (!_current(root)) return;
      } catch (error) {
        if (!_current(root)) return;
        if (revision != _preferencesRevision) continue;
        _foregroundFailure(error);
        return;
      }
    }
  }

  Future<void> loadNext() => _loadPage(backwards: false);
  Future<void> loadPrevious() => _loadPage(backwards: true);

  Future<void> _loadPage({required bool backwards}) {
    if (_disposed || _serverId == null || isStarting || isUpdatingPreferences) {
      return Future.value();
    }
    recordActivity();
    if (_requiresRefresh) {
      _notify();
      return Future.value();
    }
    final existing = backwards ? _previous : _next;
    if (existing != null) return existing;
    final cursor = backwards ? _previousCursor : _nextCursor;
    if (cursor == null && !_needsFullRecovery && !_needsVariantRecovery) {
      return Future.value();
    }
    final root = _root, epoch = _epoch, revision = _preferencesRevision;
    _error = null;
    _errorPending = false;
    late final Future<void> work;
    work = _readPage(root, epoch, revision, cursor, backwards).whenComplete(() {
      if (_root != root) return;
      if (backwards && identical(_previous, work)) _previous = null;
      if (!backwards && identical(_next, work)) _next = null;
      _notify();
    });
    if (backwards) {
      _previous = work;
    } else {
      _next = work;
    }
    _notify();
    return work;
  }

  Future<void> _readPage(
    int root,
    int epoch,
    int revision,
    String? cursor,
    bool backwards,
  ) async {
    try {
      final response = await _perform(
        (id) => _api.getPage(id, cursor: cursor, cancelToken: _cancel),
        root,
        revision: revision,
        expectedEpoch: epoch,
        preserveAnchor: true,
      );
      _ensure(root, epoch);
      if (response.revision != _preferencesRevision) return;
      if (response.replacement) {
        _replace(response.page, preserveAnchor: true);
      } else {
        final page = response.page;
        final seen = <String>{};
        final combined = backwards
            ? [...page.items, ..._items]
            : [..._items, ...page.items];
        _items = List.unmodifiable(
          combined.where((item) => seen.add(item.tripId)),
        );
        if (backwards) {
          _previousCursor = page.previousCursor;
        } else {
          _nextCursor = page.nextCursor;
        }
        _renewExpiry(page.expiresAt);
        _notify();
      }
    } on _StaleSearchOperation {
      return;
    } catch (error) {
      if (_current(root) && epoch == _epoch) {
        _foregroundFailure(error);
      }
    }
  }

  Future<_SearchResponse> _perform(
    Future<TripSearchPageModel> Function(String) operation,
    int root, {
    required int revision,
    required bool preserveAnchor,
    int? expectedEpoch,
  }) async {
    _ensure(root, expectedEpoch);
    if (_recovery != null) return _recovery!;
    if (_needsFullRecovery) {
      return _recover(root, preserveAnchor: preserveAnchor);
    }
    final id = _serverId!;
    if (_needsVariantRecovery) {
      return _repairVariant(root, preserveAnchor: preserveAnchor);
    }
    try {
      final page = await operation(id);
      _ensure(root, expectedEpoch);
      if (_serverId != id) throw const _StaleSearchOperation();
      _serverId = page.searchId;
      return _SearchResponse(page, false, revision);
    } on _StaleSearchOperation {
      rethrow;
    } catch (error) {
      _ensure(root, expectedEpoch);
      if (_serverId != id) throw const _StaleSearchOperation();
      if (_needsFullRecovery || _requiresNewSearch(error)) {
        return _recover(root, preserveAnchor: preserveAnchor);
      }
      if (_needsVariantRecovery ||
          _code(error) == ApiErrorCodes.tripSearchVariantExpired) {
        return _repairVariant(root, preserveAnchor: preserveAnchor);
      }
      rethrow;
    }
  }

  int get _restoreCount =>
      min(maxRestoreItems, max(_items.length, _page?.pageSize ?? 20));

  Future<_SearchResponse> _shareRecovery(
    int root,
    Future<_SearchResponse> Function() operation,
  ) {
    _ensure(root);
    if (_recovery != null) return _recovery!;
    late final Future<_SearchResponse> work;
    work = operation().whenComplete(() {
      if (_root == root && identical(_recovery, work)) {
        _recovery = null;
        _notify();
      }
    });
    _recovery = work;
    _notify();
    return work;
  }

  Future<_SearchResponse> _repairVariant(
    int root, {
    required bool preserveAnchor,
  }) => _shareRecovery(root, () async {
    final id = _serverId!;
    final revision = _preferencesRevision;
    final settings = _desired!.forApplication(
      anchorTripId: preserveAnchor ? _visibleTripId : null,
      restoreResultCount: preserveAnchor ? _restoreCount : null,
    );
    try {
      final page = await _api.reprioritize(id, settings, cancelToken: _cancel);
      _ensure(root);
      if (_serverId != id) throw const _StaleSearchOperation();
      _serverId = page.searchId;
      _needsVariantRecovery = false;
      return _SearchResponse(page, true, revision);
    } on _StaleSearchOperation {
      rethrow;
    } catch (error) {
      _ensure(root);
      if (_serverId != id) throw const _StaleSearchOperation();
      if (_requiresNewSearch(error)) {
        return _calculateRecovery(root, preserveAnchor: preserveAnchor);
      }
      rethrow;
    }
  });

  Future<_SearchResponse> _recover(int root, {required bool preserveAnchor}) =>
      _shareRecovery(
        root,
        () => _calculateRecovery(root, preserveAnchor: preserveAnchor),
      );

  Future<_SearchResponse> _calculateRecovery(
    int root, {
    required bool preserveAnchor,
  }) async {
    final revision = _preferencesRevision;
    final desired = _desired!;
    var original = _original!;
    final filters = desired.filters;
    original = original.copyWith(
      maxWalkMeters: _expanded(original.maxWalkMeters, filters.maxWalkMeters),
      maxWalkSeconds: _expanded(
        original.maxWalkSeconds,
        filters.maxWalkSeconds,
      ),
      maxTotalWalkSeconds: _expanded(
        original.maxTotalWalkSeconds,
        filters.maxTotalWalkSeconds,
      ),
      timeDeviationMinutes: _expanded(
        original.timeDeviationMinutes,
        filters.timeDeviationMinutes,
      ),
    );
    final execution = original.copyWith(
      preferences: desired,
      requestId: _requestId(),
      anchorTripId: preserveAnchor ? _visibleTripId : null,
      restoreResultCount: preserveAnchor ? _restoreCount : null,
    );
    final page = await _api.search(execution, cancelToken: _cancel);
    _ensure(root);
    _adopt(page, execution);
    _needsFullRecovery = false;
    _needsVariantRecovery = false;
    return _SearchResponse(page, true, revision);
  }

  int? _expanded(int? original, int? requested) => original == null
      ? requested
      : requested == null
      ? original
      : max(original, requested);

  void _adopt(TripSearchPageModel page, TripSearchRequestModel request) {
    _serverId = page.searchId;
    final limits = page.selectionLimits;
    _original = request.copyWith(
      requestId: null,
      anchorTripId: null,
      restoreResultCount: null,
      maxWalkMeters: limits.maxWalkMeters,
      maxWalkSeconds: limits.maxWalkSeconds,
      maxTotalWalkSeconds: limits.maxTotalWalkSeconds,
      timeDeviationMinutes: limits.timeDeviationMinutes,
      pageSize: page.pageSize,
    );
  }

  void _replace(TripSearchPageModel page, {required bool preserveAnchor}) {
    final anchor = preserveAnchor ? _visibleTripId : null;
    _page = page;
    _serverId = page.searchId;
    _items = List.unmodifiable(page.items);
    _nextCursor = page.nextCursor;
    _previousCursor = page.previousCursor;
    _expiresAt = page.expiresAt;
    _scrollAnchorTripId =
        anchor != null && _items.any((item) => item.tripId == anchor)
        ? anchor
        : null;
    _resultsUpdated = anchor != null && _scrollAnchorTripId == null;
    _error = null;
    _errorPending = false;
    _backgroundError = null;
    _needsFullRecovery = false;
    _needsVariantRecovery = false;
    _epoch++;
    _listRevision++;
    _notify();
  }

  Future<void> keepAliveIfActive() {
    final wasExpired = _requiresRefresh;
    if (!_disposed && _visible) _checkIdle();
    if (!wasExpired && _requiresRefresh) _notify();
    if (_disposed ||
        !_visible ||
        _serverId == null ||
        _requiresRefresh ||
        _needsFullRecovery ||
        _needsVariantRecovery ||
        isLoading ||
        _heartbeat != null) {
      return Future.value();
    }
    final activity = _lastActivity;
    if (activity == null || _now().difference(activity) >= heartbeatInterval) {
      return Future.value();
    }
    if (_lastHeartbeat != null &&
        _now().difference(_lastHeartbeat!) < heartbeatInterval) {
      return Future.value();
    }
    final root = _root, id = _serverId!;
    _lastHeartbeat = _now();
    late final Future<void> work;
    work =
        (() async {
          try {
            final result = await _api.keepAlive(id, cancelToken: _cancel);
            if (_current(root) && id == _serverId) {
              _renewExpiry(result.expiresAt);
              _backgroundError = null;
            }
          } catch (error) {
            if (!_current(root) || id != _serverId || _cancelled(error)) return;
            _backgroundError = error;
            if (_code(error) == ApiErrorCodes.tripSearchVariantExpired) {
              _needsVariantRecovery = true;
            } else if (_requiresNewSearch(error)) {
              _needsFullRecovery = true;
            }
          }
        })().whenComplete(() {
          if (_root == root && identical(_heartbeat, work)) {
            _heartbeat = null;
            _notify();
          }
        });
    _heartbeat = work;
    return work;
  }

  void _renewExpiry(DateTime value) {
    if (_expiresAt == null || value.isAfter(_expiresAt!)) _expiresAt = value;
  }

  void acknowledgeResultsUpdated() {
    _resultsUpdated = false;
    _notify();
  }

  void _foregroundFailure(Object error) {
    if (_cancelled(error) || identical(_error, error)) return;
    _error = error;
    _errorPending = true;
    _notify();
  }

  String? _code(Object? error) {
    if (error is! DioException || _cancelled(error)) return null;
    final data = error.response?.data;
    return data is Map && data['code'] is String
        ? data['code'] as String
        : null;
  }

  bool _requiresNewSearch(Object? error) => const {
    ApiErrorCodes.tripSearchExpired,
    ApiErrorCodes.tripSearchChanged,
    ApiErrorCodes.tripSearchGraphChanged,
    ApiErrorCodes.tripSearchNewSearchRequired,
  }.contains(_code(error));
  bool _cancelled(Object error) =>
      error is DioException && error.type == DioExceptionType.cancel;
  bool _current(int root) => !_disposed && root == _root;
  void _ensure(int root, [int? epoch]) {
    if (!_current(root) || (epoch != null && epoch != _epoch)) {
      throw const _StaleSearchOperation();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _root++;
    _timer?.cancel();
    _cancel.cancel('Results closed');
    super.dispose();
  }
}

class _SearchResponse {
  final TripSearchPageModel page;
  final bool replacement;
  final int revision;
  const _SearchResponse(this.page, this.replacement, this.revision);
}

class _StaleSearchOperation implements Exception {
  const _StaleSearchOperation();
}
