import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/auth_model.dart';
import '../../services/google_auth_service.dart';
import '../../services/home_map_startup.dart';
import '../../services/user_session.dart';

abstract final class AuthHomeEntry {
  static const _minimumLoading = Duration(milliseconds: 600);

  static Future<void> submit(
    BuildContext context,
    Future<AuthTokens> Function() request,
  ) async {
    final minimumWait = Future<void>.delayed(_minimumLoading);
    try {
      final tokens = await request();
      if (!context.mounted) return;
      await _finish(context, tokens, minimumWait);
    } finally {
      await minimumWait;
    }
  }

  static Future<GoogleAuthResult> signInWithGoogle(
    BuildContext context,
    Future<GoogleAuthResult> Function() request,
  ) async {
    final minimumWait = Completer<void>();
    final timer = Timer(_minimumLoading, minimumWait.complete);
    try {
      final result = await request();
      if (result is GoogleLoginSuccess && context.mounted) {
        await _finish(context, result.tokens, minimumWait.future);
      }
      return result;
    } finally {
      timer.cancel();
    }
  }

  static Future<void> _finish(
    BuildContext context,
    AuthTokens tokens,
    Future<void> minimumWait,
  ) {
    // Location and the authenticated map configuration can load in parallel.
    final location = HomeMapStartup.locate();
    return UserSession().loginSuccess(
      tokens,
      prepareHomeMap: () async {
        final start = await location;
        final prepared = context.mounted
            ? await HomeMapStartup.warmAfterLogin(context, start)
            : start;
        await minimumWait;
        return prepared;
      },
    );
  }
}
