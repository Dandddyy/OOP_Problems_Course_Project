import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'app_scrollbar.dart';
import 'keyboard_dismiss_on_background_tap.dart';
import 'keyboard_motion_coordinator.dart';

/// Shared coordinated scroll viewport for the routed authentication screens.
class AuthKeyboardScrollLayout extends StatefulWidget {
  final LayoutWidgetBuilder builder;

  const AuthKeyboardScrollLayout({super.key, required this.builder});

  @override
  State<AuthKeyboardScrollLayout> createState() =>
      _AuthKeyboardScrollLayoutState();
}

class _AuthKeyboardScrollLayoutState extends State<AuthKeyboardScrollLayout> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardMotionCoordinator(
      scrollController: _scrollController,
      // The auth Scaffold body still occupies the full window. Safe-area
      // padding lives inside the scroll content, so none of the keyboard inset
      // has already been excluded from this viewport.
      reservedBottomInset: 0,
      builder: (context, constraints, scrollPhysics, bottomScrollExtent) {
        return KeyboardDismissOnBackgroundTap(
          child: AppScrollbar(
            controller: _scrollController,
            mainAxisMargin: 0,
            padding: EdgeInsets.fromLTRB(
              MediaQuery.paddingOf(context).left,
              MediaQuery.paddingOf(context).top + AppDimens.gapSm,
              AppScrollbar.screenRightInsetOf(context),
              MediaQuery.paddingOf(context).bottom + AppDimens.gapLg,
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: scrollPhysics,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              // Keep the coordinator's temporary closing extent outside the
              // stable content canvas.
              padding: EdgeInsets.only(bottom: bottomScrollExtent),
              child: ConstrainedBox(
                // Center the auth composition in the currently unobscured
                // viewport. Once its natural height reaches the top boundary,
                // only the remaining focused-field overflow is scrolled.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: widget.builder(context, constraints),
              ),
            ),
          ),
        );
      },
    );
  }
}
