import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

class AppTopSafeArea extends StatelessWidget {
  final Widget child;
  final double additionalPadding;

  const AppTopSafeArea({
    super.key,
    required this.child,
    this.additionalPadding = AppDimens.topContentGap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(top: additionalPadding),
        child: child,
      ),
    );
  }
}