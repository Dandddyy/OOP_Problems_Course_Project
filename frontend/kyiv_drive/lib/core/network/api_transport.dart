import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

Dio createApiTransport() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
  dio.httpClientAdapter = ApiDeadlineAdapter(
    dio.httpClientAdapter,
    ApiTimeoutProfile.limitFor,
  );
  return dio;
}

enum ApiTimeoutProfile {
  standard(Duration(seconds: 15)),
  route(Duration(seconds: 20)),
  search(Duration(seconds: 40)),
  recalculate(Duration(seconds: 20)),
  stopImport(Duration(seconds: 75));

  const ApiTimeoutProfile(this.limit);

  final Duration limit;

  static Duration limitFor(RequestOptions request) {
    if (request.method.toUpperCase() != 'POST') return standard.limit;
    switch (request.uri.path) {
      case ApiConstants.tripSearchEndpoint:
        return search.limit;
      case ApiConstants.getRouteEndpoint:
      case ApiConstants.getRouteWithStopsEndpoint:
      case ApiConstants.tripEndpoint:
      case ApiConstants.templateEndpoint:
        return route.limit;
      case '/api/stop/import/preview':
      case '/api/stop/import/apply':
        return stopImport.limit;
    }
    final segments = request.uri.pathSegments;
    if (segments.length == 5 &&
        segments[0] == 'api' &&
        segments[1] == 'trip' &&
        segments[2] == 'search' &&
        segments[4] == 'preferences') {
      return recalculate.limit;
    }
    return standard.limit;
  }
}

/// Bounds one HTTP transfer, including the response body and a slow upload.
class ApiDeadlineAdapter implements HttpClientAdapter {
  ApiDeadlineAdapter(this._delegate, this._limitFor);

  final HttpClientAdapter _delegate;
  final Duration Function(RequestOptions) _limitFor;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final limit = _limitFor(options);
    final connectTimeout = options.connectTimeout;
    if (connectTimeout == null ||
        connectTimeout == Duration.zero ||
        connectTimeout > limit) {
      options.connectTimeout = limit;
    }
    options.sendTimeout = limit;
    options.receiveTimeout = limit;

    final clock = Stopwatch()..start();
    final abort = Completer<void>();
    // A session can reuse the caller's CancelToken across many requests.
    final weakAbort = WeakReference(abort);
    cancelFuture?.then((_) {
      final signal = weakAbort.target;
      if (signal != null && !signal.isCompleted) signal.complete();
    });
    void cancelTransfer() {
      if (!abort.isCompleted) abort.complete();
    }

    final timeout = DioException.receiveTimeout(
      timeout: limit,
      requestOptions: options,
    );
    final body = await _delegate
        .fetch(options, requestStream, abort.future)
        .timeout(
          limit,
          onTimeout: () {
            cancelTransfer();
            throw timeout;
          },
        );

    body.stream = _withinDeadline(
      body.stream,
      () => limit - clock.elapsed,
      timeout,
      cancelTransfer,
    );
    return body;
  }

  Stream<Uint8List> _withinDeadline(
    Stream<Uint8List> source,
    Duration Function() remaining,
    DioException timeout,
    void Function() cancelTransfer,
  ) {
    Timer? timer;
    StreamSubscription<Uint8List>? subscription;
    late final StreamController<Uint8List> output;

    void expire() {
      if (output.isClosed) return;
      cancelTransfer();
      output.addError(timeout);
      unawaited(output.close());
      unawaited(subscription?.cancel());
    }

    output = StreamController<Uint8List>(
      onListen: () {
        final budget = remaining();
        if (budget <= Duration.zero) {
          expire();
          return;
        }
        timer = Timer(budget, expire);
        subscription = source.listen(
          (chunk) {
            if (remaining() <= Duration.zero) {
              expire();
            } else if (!output.isClosed) {
              output.add(chunk);
            }
          },
          onError: (Object error, StackTrace stack) {
            timer?.cancel();
            if (!output.isClosed) {
              output.addError(error, stack);
              unawaited(output.close());
            }
          },
          onDone: () {
            timer?.cancel();
            if (remaining() <= Duration.zero) {
              expire();
            } else if (!output.isClosed) {
              unawaited(output.close());
            }
          },
          cancelOnError: true,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return output.stream;
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}
