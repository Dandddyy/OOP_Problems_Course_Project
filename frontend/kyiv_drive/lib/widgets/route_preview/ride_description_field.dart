import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../keyboard_aware_scroll_view.dart';
import '../animated_field_error.dart';
import '../animated_field_text_color.dart';
import '../keyboard_reveal_target.dart';
import '../shimmer_placeholder.dart';

class RideDescriptionField extends StatefulWidget {
  final TextEditingController controller;
  final Color focusColor;
  final Color cursorColor;
  final bool isEnabled;

  /// Skeleton placeholders keep the unlocked text width to avoid a layout jump.
  final bool showDisabledLock;
  final bool showSkeleton;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  /// Lets Flutter reveal the entire decorated field instead of reporting
  /// focus to the legacy keyboard-aware scroll coordinator.
  final bool useKeyboardRevealTarget;
  final EdgeInsets? keyboardRevealVisibilityPadding;

  /// Keeps restoration clear of closed-screen chrome without increasing the
  /// spacing above an open keyboard.
  final EdgeInsets? keyboardRestoreVisibilityPadding;

  const RideDescriptionField({
    super.key,
    required this.controller,
    required this.focusColor,
    required this.cursorColor,
    this.isEnabled = true,
    this.showDisabledLock = true,
    this.showSkeleton = false,
    this.onChanged,
    this.errorText,
    this.useKeyboardRevealTarget = false,
    this.keyboardRevealVisibilityPadding,
    this.keyboardRestoreVisibilityPadding,
  });

  @override
  State<RideDescriptionField> createState() => _RideDescriptionFieldState();
}

class _RideDescriptionFieldState extends State<RideDescriptionField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RideDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isEnabled && !widget.isEnabled) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!mounted) return;

    if (!widget.useKeyboardRevealTarget) {
      KeyboardAwareScrollView.handleFocusChange(context, _focusNode.hasFocus);
    }
    setState(() {});
  }

  void _handleTextChanged(String value) {
    if (_focusNode.hasFocus && !widget.useKeyboardRevealTarget) {
      KeyboardAwareScrollView.handleFocusChange(context, true);
    }
    widget.onChanged?.call(value);
  }

  Color _borderColor() {
    if (widget.showSkeleton) return Colors.transparent;
    if (widget.errorText != null) {
      return AppColors.danger.withValues(alpha: 0.8);
    }
    if (_focusNode.hasFocus && widget.isEnabled) {
      return widget.focusColor.withValues(alpha: 0.35);
    }
    if (!widget.isEnabled) return AppColors.borderMuted;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final hint = AppLocalizations.of(context)!.rideDescriptionHint;
    final hintStyle = AppText.inputHint.copyWith(fontSize: 14, height: 1.35);
    final theme = Theme.of(context);
    final hintBaseStyle = theme.useMaterial3
        ? theme.textTheme.bodyLarge
        : theme.textTheme.titleMedium;
    final inputLineHeight =
        (AppText.inputText.fontSize ?? 16) * (AppText.inputText.height ?? 1);
    final verticalContentPadding =
        (AppDimens.controlHeight -
            inputLineHeight -
            AppDimens.focusBorderWidth * 2) /
        2;

    final field = TextFieldTapRegion(
      groupId: this,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isEnabled
            ? () => FocusScope.of(context).requestFocus(_focusNode)
            : null,
        child: AnimatedContainer(
          duration: AppDurations.fieldState,
          constraints: const BoxConstraints(minHeight: AppDimens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: widget.isEnabled || widget.showSkeleton
                ? AppColors.surface
                : AppColors.surfaceDisabled,
            borderRadius: AppRadius.formControlBr,
            border: Border.all(
              color: _borderColor(),
              width: AppDimens.focusBorderWidth,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedFieldTextColor(
                  color: widget.isEnabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  builder: (textColor) => TextField(
                    key: const ValueKey('ride-description-input'),
                    groupId: this,
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.isEnabled,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.center,
                    minLines: 1,
                    maxLines: null,
                    maxLength: 255,
                    onChanged: _handleTextChanged,
                    cursorColor: widget.cursorColor,
                    cursorHeight: AppDimens.inputCursorHeight,
                    cursorWidth: AppDimens.inputCursorWidth,
                    cursorRadius: const Radius.circular(AppRadius.full),
                    style: AppText.inputText.copyWith(color: textColor),
                    decoration: InputDecoration(
                      hintText: widget.showSkeleton ? null : hint,
                      hint: widget.showSkeleton
                          ? ShimmerPlaceholder(
                              child: Text(
                                hint,
                                style:
                                    hintBaseStyle?.merge(hintStyle) ??
                                    hintStyle,
                              ),
                            )
                          : null,
                      hintStyle: hintStyle,
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: verticalContentPadding,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (!widget.isEnabled && widget.showDisabledLock)
                const Padding(
                  padding: EdgeInsets.only(left: AppDimens.gapSm),
                  child: Icon(
                    Icons.lock_outline,
                    color: AppColors.textDisabled,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final revealField = !widget.useKeyboardRevealTarget
        ? field
        : KeyboardRevealTarget(
            focusNode: _focusNode,
            revealOnFocus:
                widget.keyboardRevealVisibilityPadding != null ||
                widget.keyboardRestoreVisibilityPadding != null,
            visibilityPadding:
                widget.keyboardRevealVisibilityPadding ??
                const EdgeInsets.all(AppDimens.gapLg),
            restoreVisibilityPadding: widget.keyboardRestoreVisibilityPadding,
            child: field,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        revealField,
        AnimatedFieldError(errorText: widget.errorText),
      ],
    );
  }
}
