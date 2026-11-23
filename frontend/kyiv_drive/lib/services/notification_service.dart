import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_top_notification.dart';

enum NotificationPriority { normal, urgent }

class _NotificationRequest {
  final String message;
  final bool isError;
  final Color? brandColor;
  final NotificationPriority priority;

  const _NotificationRequest({
    required this.message,
    required this.isError,
    this.brandColor,
    this.priority = NotificationPriority.normal,
  });
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;

  final List<_NotificationRequest> _queue = [];
  bool _isShowing = false;
  OverlayEntry? _currentOverlayEntry;

  static void init(GlobalKey<NavigatorState> key) {
    _instance._navigatorKey = key;
  }

  static void showError(
    dynamic error, {
    NotificationPriority priority = NotificationPriority.urgent,
  }) {
    final context = _instance._navigatorKey?.currentContext;
    final overlayState = _instance._navigatorKey?.currentState?.overlay;

    if (context == null || overlayState == null) {
      debugPrint("Не удалось показать ошибку: UI еще не готов");
      return;
    }

    String message = AppLocalizations.of(context)!.somethingWentWrong;

    if (error is String) {
      message = error;
    } else if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['showUser'] == true) {
        final serverMessage = data['message'];
        if (serverMessage is String && serverMessage.trim().isNotEmpty) {
          message = serverMessage;
          debugPrint("Backend Error: $message");
          _instance._enqueueRequest(
            _NotificationRequest(
              message: message,
              isError: true,
              priority: priority,
            ),
          );
          return;
        }
      }
    }

    debugPrint("Error: $error");
    _instance._enqueueRequest(
      _NotificationRequest(message: message, isError: true, priority: priority),
    );
  }

  static void showInfo(
      String message, {
        Color? brandColor,
        NotificationPriority priority =
            NotificationPriority.normal,
      }) {
    final overlay =
        _instance._navigatorKey?.currentState?.overlay;

    if (overlay == null || !overlay.mounted) {
      return;
    }

    _instance._enqueueRequest(
      _NotificationRequest(
        message: message,
        isError: false,
        brandColor: brandColor,
        priority: priority,
      ),
    );
  }

  static void clearQueue() {
    _instance._queue.clear();

    final entry = _instance._currentOverlayEntry;

    if (entry?.mounted == true) {
      entry!.remove();
    }

    _instance._currentOverlayEntry = null;
    _instance._isShowing = false;
  }

  void _enqueueRequest(_NotificationRequest request) {
    if (request.priority == NotificationPriority.urgent) {
      final insertIndex = _queue.indexWhere((e) => e.priority != NotificationPriority.urgent);
      if (insertIndex == -1) {
        _queue.add(request);
      } else {
        _queue.insert(insertIndex, request);
      }
    } else {
      _queue.add(request);
    }

    _processNext();
  }

  void _processNext() {
    if (_isShowing || _queue.isEmpty) return;

    final overlayState =
        _navigatorKey?.currentState?.overlay;

    if (overlayState == null ||
        !overlayState.mounted) {
      return;
    }

    _isShowing = true;

    final request = _queue.removeAt(0);

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return AppTopNotification(
          message: request.message,
          isError: request.isError,
          brandColor: request.brandColor,
          onDismiss: () {
            _finishEntry(entry);
          },
        );
      },
    );

    _currentOverlayEntry = entry;
    overlayState.insert(entry);
  }

  void _finishEntry(OverlayEntry entry) {
    if (!identical(_currentOverlayEntry, entry)) {
      return;
    }

    if (entry.mounted) {
      entry.remove();
    }

    _currentOverlayEntry = null;
    _isShowing = false;

    _processNext();
  }
}
