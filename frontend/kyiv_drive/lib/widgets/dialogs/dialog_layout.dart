import 'package:flutter/material.dart';

const _defaultDialogInsetPadding = EdgeInsets.symmetric(
  horizontal: 40,
  vertical: 24,
);

/// Adds system-safe padding to the regular Material dialog margins.
///
/// [Dialog] already adds keyboard [MediaQueryData.viewInsets], while dialogs
/// opened through `showGeneralDialog` are not wrapped in a [SafeArea].
EdgeInsets safeDialogInsetPadding(BuildContext context) {
  final dialogInsetPadding =
      DialogTheme.of(context).insetPadding ?? _defaultDialogInsetPadding;

  return dialogInsetPadding + MediaQuery.paddingOf(context);
}
