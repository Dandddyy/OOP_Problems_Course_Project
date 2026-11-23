import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_ui_tokens.dart';
import '../l10n/app_localizations.dart';
import 'animated_control_lock.dart';
import 'animated_field_error.dart';
import 'animated_field_icon.dart';
import 'animated_field_text_color.dart';
import 'animated_touch_templates.dart';
import 'animated_value_switcher.dart';
import 'app_scrollbar.dart';
import 'keyboard_aware_scroll_view.dart';
import 'keyboard_reveal_target.dart';

const double _anchoredOverlayGap = AppDimens.gapXs;

class _AnchoredOverlayPlacement {
  final bool opensAbove;
  final double maxSurfaceHeight;

  const _AnchoredOverlayPlacement({
    required this.opensAbove,
    required this.maxSurfaceHeight,
  });
}

class _AnchoredOverlayGeometryTracker with WidgetsBindingObserver {
  final VoidCallback markNeedsBuild;

  _AnchoredOverlayGeometryTracker({required this.markNeedsBuild});

  ScrollPosition? _scrollPosition;
  bool _isActive = false;

  void start(BuildContext context) {
    if (!_isActive) {
      WidgetsBinding.instance.addObserver(this);
      _isActive = true;
    }

    final scrollPosition = Scrollable.maybeOf(context)?.position;
    if (identical(scrollPosition, _scrollPosition)) return;

    _scrollPosition?.removeListener(markNeedsBuild);
    _scrollPosition = scrollPosition;
    _scrollPosition?.addListener(markNeedsBuild);
  }

  void stop() {
    _scrollPosition?.removeListener(markNeedsBuild);
    _scrollPosition = null;

    if (_isActive) {
      WidgetsBinding.instance.removeObserver(this);
      _isActive = false;
    }
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isActive) markNeedsBuild();
    });
  }
}

_AnchoredOverlayPlacement _resolveAnchoredOverlayPlacement({
  required BuildContext overlayContext,
  required RenderBox? fieldBox,
  required double desiredSurfaceHeight,
  required double maximumSurfaceHeight,
}) {
  if (fieldBox == null || !fieldBox.attached) {
    return _AnchoredOverlayPlacement(
      opensAbove: false,
      maxSurfaceHeight: maximumSurfaceHeight,
    );
  }

  final media = MediaQuery.of(overlayContext);
  final fieldTop = fieldBox.localToGlobal(Offset.zero).dy;
  final fieldBottom = fieldTop + fieldBox.size.height;
  var visibleTop = media.viewPadding.top;
  var visibleBottom =
      media.size.height -
      math.max(media.viewInsets.bottom, media.viewPadding.bottom);

  final viewport = RenderAbstractViewport.maybeOf(fieldBox);
  final viewportBox = viewport is RenderBox ? viewport as RenderBox : null;
  if (viewportBox != null && viewportBox.attached) {
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportBox.size.height;
    visibleTop = math.max(visibleTop, viewportTop);
    visibleBottom = math.min(visibleBottom, viewportBottom);
  }

  final availableAbove = math.max(
    0.0,
    fieldTop - visibleTop - _anchoredOverlayGap,
  );
  final availableBelow = math.max(
    0.0,
    visibleBottom - fieldBottom - _anchoredOverlayGap,
  );
  final desiredHeight = math.min(desiredSurfaceHeight, maximumSurfaceHeight);
  final opensAbove =
      availableBelow < desiredHeight && availableAbove > availableBelow;
  final availableHeight = opensAbove ? availableAbove : availableBelow;

  return _AnchoredOverlayPlacement(
    opensAbove: opensAbove,
    maxSurfaceHeight: math.min(maximumSurfaceHeight, availableHeight),
  );
}

class AuthTextField extends StatefulWidget {
  final bool autofocus;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Widget Function(Color color)? leadingBuilder;
  final bool showClearButton;
  final bool isPassword;
  final bool showEyeIcon;
  final TextInputAction? inputAction;
  final bool isEnabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Uses Flutter's native show-on-screen flow for the decorated field and
  /// leaves the legacy keyboard-aware focus coordinator disabled.
  final bool useKeyboardRevealTarget;
  final EdgeInsets? keyboardRevealVisibilityPadding;
  final KeyboardRevealController? keyboardRevealController;

  final List<TextInputFormatter>? formatters;
  final Color focusColor;
  final Color cursorColor;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;

  final List<String>? suggestions;
  final ValueChanged<String>? onSuggestionSelected;
  final bool unfocusOnSuggestionSelected;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.leadingBuilder,
    this.showClearButton = true,
    this.isPassword = false,
    this.showEyeIcon = true,
    this.inputAction,
    this.isEnabled = true,
    this.errorText,
    this.onChanged,
    this.formatters,
    required this.focusColor,
    this.cursorColor = const Color(0xFFB2EBF2),
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
    this.focusNode,
    this.autofillHints = const <String>[],
    this.autofocus = false,
    this.suggestions,
    this.onSuggestionSelected,
    this.unfocusOnSuggestionSelected = true,
    this.useKeyboardRevealTarget = false,
    this.keyboardRevealVisibilityPadding,
    this.keyboardRevealController,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> with SingleTickerProviderStateMixin {
  static const double _suggestionsMaximumHeight = 200;

  bool _isObscured = false;
  late FocusNode _focusNode;
  bool _hasText = false;

  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _filteredSuggestions = [];
  bool _isOverlayOpen = false;
  late final _overlayGeometryTracker = _AnchoredOverlayGeometryTracker(
    markNeedsBuild: _markOverlayNeedsBuild,
  );

  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.isPassword;
    _focusNode = widget.focusNode ?? FocusNode();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );

    _focusNode.addListener(_onFocusChanged);

    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_textListener);
  }

  @override
  void didUpdateWidget(covariant AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isEnabled && !widget.isEnabled) {
      _focusNode.unfocus();
      _removeOverlayImmediately();
      return;
    }

    if (widget.suggestions != oldWidget.suggestions &&
        _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _filterAndHandleOverlay();
        }
      });
    }
  }

  void _removeOverlayImmediately() {
    _isOverlayOpen = false;
    _overlayGeometryTracker.stop();

    _animController.stop();
    // Reset on the next open: overlay listeners may still be mounted during build.

    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onFocusChanged() {
    if (!mounted) return;

    if (!widget.useKeyboardRevealTarget) {
      KeyboardAwareScrollView.handleFocusChange(context, _focusNode.hasFocus);
    }
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focusNode.hasFocus) {
        _filterAndHandleOverlay();
      } else {
        _closeOverlay();
      }
    });
  }

  void _textListener() {
    if (!mounted) return;

    final hasTextNow = widget.controller.text.isNotEmpty;
    if (_hasText != hasTextNow) {
      setState(() {
        _hasText = hasTextNow;
      });
    }

    if (_focusNode.hasFocus) {
      _filterAndHandleOverlay();
    }
  }

  Widget _buildLeadingIcon(Color color) {
    if (widget.leadingBuilder != null) {
      return widget.leadingBuilder!(color);
    }

    return Icon(
      widget.icon,
      color: color,
    );
  }

  void _filterAndHandleOverlay() {
    if (!widget.isEnabled) return;

    if (widget.suggestions == null || widget.suggestions!.isEmpty) {
      _closeOverlay();
      return;
    }

    final query = widget.controller.text.trim().toLowerCase();

    if (query.isEmpty) {
      _closeOverlay();
      return;
    }

    _filteredSuggestions = widget.suggestions!
        .where((item) => item.toLowerCase().contains(query))
        .toList();

    _filteredSuggestions.sort((a, b) => a.compareTo(b));

    if (_filteredSuggestions.isNotEmpty) {
      _openOverlay();
    } else {
      _closeOverlay();
    }
  }

  void _openOverlay() {
    if (!widget.isEnabled) return;
    if (_isOverlayOpen) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    final isNewOverlay = _overlayEntry == null;
    if (isNewOverlay) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.markNeedsBuild();
    }
    _isOverlayOpen = true;
    _animController.forward(from: isNewOverlay ? 0 : null);
    _overlayGeometryTracker.start(context);
  }

  Future<void> _closeOverlay() async {
    if (!_isOverlayOpen) return;
    _isOverlayOpen = false;
    _overlayGeometryTracker.stop();

    try {
      await _animController.reverse().orCancel;
    } on TickerCanceled {
      return;
    }

    if (!_isOverlayOpen && mounted) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final fieldBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final desiredHeight = math.min(
          _suggestionsMaximumHeight,
          _filteredSuggestions.length * 48.0 +
              math.max(0, _filteredSuggestions.length - 1) *
                  AppDimens.dividerThickness,
        );
        final placement = _resolveAnchoredOverlayPlacement(
          overlayContext: overlayContext,
          fieldBox: fieldBox,
          desiredSurfaceHeight: desiredHeight,
          maximumSurfaceHeight: _suggestionsMaximumHeight,
        );
        final fieldWidth = fieldBox?.size.width ?? 0;

        return Positioned(
          width: fieldWidth + AppDimens.gapLg * 2,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: placement.opensAbove
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: placement.opensAbove
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(
              -AppDimens.gapLg,
              placement.opensAbove ? AppDimens.gapMd : -AppDimens.gapMd,
            ),
            child: TapRegion(
              groupId: this,
              child: _SuggestionsOverlayContent(
                animation: _expandAnimation,
                items: _filteredSuggestions,
                opensAbove: placement.opensAbove,
                maxHeight: placement.maxSurfaceHeight,
                onSelected: (item) {
                  if (!widget.isEnabled || !_isOverlayOpen) return;

                  widget.controller.text = item;
                  widget.controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: item.length),
                  );

                  widget.onSuggestionSelected?.call(item);
                  if (widget.unfocusOnSuggestionSelected) {
                    _focusNode.unfocus();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _markOverlayNeedsBuild() {
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textListener);
    _focusNode.removeListener(_onFocusChanged);

    _removeOverlayImmediately();
    _animController.dispose();

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  Widget? _buildSuffixIcon() {
    if (widget.isPassword && widget.isEnabled && widget.showEyeIcon) {
      return GestureDetector(
        onTap: () => setState(() => _isObscured = !_isObscured),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 22,
          ),
        ),
      );
    } else if (
    widget.showClearButton &&
        !widget.isPassword &&
        widget.isEnabled &&
        _hasText
    ) {
      return GestureDetector(
        onTap: () {
          widget.controller.clear();
          widget.onChanged?.call('');
          if (!_focusNode.hasFocus) {
            FocusScope.of(context).requestFocus(_focusNode);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            Icons.close_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
      );
    }
    return null;
  }

  Widget _wrapKeyboardRevealTarget(Widget field) {
    if (!widget.useKeyboardRevealTarget) return field;

    return KeyboardRevealTarget(
      focusNode: _focusNode,
      controller: widget.keyboardRevealController,
      revealOnFocus: widget.keyboardRevealVisibilityPadding != null,
      visibilityPadding:
          widget.keyboardRevealVisibilityPadding ??
          const EdgeInsets.all(AppDimens.gapLg),
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null;
    final bool isFocused = _focusNode.hasFocus;

    Color getBorderColor() {
      if (hasError) return AppColors.danger.withValues(alpha: 0.8);
      if (isFocused && widget.isEnabled) {
        return widget.focusColor.withValues(alpha: 0.35);
      }
      if (!widget.isEnabled) return AppColors.borderMuted;
      return Colors.transparent;
    }

    Color getIconColor() {
      if (hasError) return AppColors.danger;
      if (isFocused) return widget.focusColor.withValues(alpha: 0.8);
      if (!widget.isEnabled) return AppColors.textDisabled;
      return AppColors.textMuted;
    }

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          key: _fieldKey,
          link: _layerLink,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.isEnabled && !_focusNode.hasFocus) {
                FocusScope.of(context).requestFocus(_focusNode);
              }
            },
            child: AnimatedContainer(
              duration: AppDurations.fieldState,
              height: AppDimens.controlHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
              decoration: BoxDecoration(
                color: widget.isEnabled ? AppColors.surface : AppColors.surfaceDisabled,
                borderRadius: AppRadius.formControlBr,
                border: Border.all(
                  color: getBorderColor(),
                  width: AppDimens.focusBorderWidth,
                ),
              ),
              child: Row(
                children: [
                  AnimatedFieldIcon(
                    color: getIconColor(),
                    builder: _buildLeadingIcon,
                  ),
                  const SizedBox(width: AppDimens.gapLg),
                  Expanded(
                    child: AnimatedFieldTextColor(
                      color: widget.isEnabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      builder: (textColor) => TextField(
                        groupId: this,
                        autofocus: widget.autofocus,
                        keyboardType: widget.keyboardType,
                        focusNode: _focusNode,
                        controller: widget.controller,
                        obscureText: _isObscured,
                        textInputAction: widget.inputAction,
                        enabled: widget.isEnabled,
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: widget.onChanged,
                        inputFormatters: widget.formatters,
                        textCapitalization: widget.capitalization,
                        autofillHints: widget.autofillHints,
                        cursorColor: widget.cursorColor,
                        cursorHeight: AppDimens.inputCursorHeight,
                        cursorWidth: AppDimens.inputCursorWidth,
                        cursorRadius: const Radius.circular(AppRadius.full),
                        style: AppText.inputText.copyWith(color: textColor),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: AppText.inputHint,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          suffixIcon: _buildSuffixIcon(),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isEnabled)
                    const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.lock_outline,
                          color: AppColors.textDisabled,
                          size: 20,
                        )
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedFieldError(
          errorText: widget.errorText,
          padding: const EdgeInsets.only(top: 6, left: AppDimens.gapSm),
        ),
      ],

    );

    return _wrapKeyboardRevealTarget(field);
  }
}

class _SuggestionsOverlayContent extends StatefulWidget {
  final Animation<double> animation;
  final List<String> items;
  final bool opensAbove;
  final double maxHeight;
  final ValueChanged<String> onSelected;

  const _SuggestionsOverlayContent({
    required this.animation,
    required this.items,
    required this.opensAbove,
    required this.maxHeight,
    required this.onSelected,
  });

  @override
  State<_SuggestionsOverlayContent> createState() => _SuggestionsOverlayContentState();
}

class _SuggestionsOverlayContentState extends State<_SuggestionsOverlayContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: widget.animation,
      alignment: widget.opensAbove
          ? AlignmentDirectional.bottomStart
          : AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: widget.animation,
        child: Padding(
          padding: EdgeInsets.only(
            top: widget.opensAbove ? AppDimens.gapXl : AppDimens.gapLg,
            left: AppDimens.gapLg,
            right: AppDimens.gapLg,
            bottom: widget.opensAbove ? AppDimens.gapLg : AppDimens.gapXl,
          ),
          child: Container(
            key: const ValueKey('auth-suggestions-overlay-surface'),
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            decoration: BoxDecoration(
              borderRadius: AppRadius.formControlBr,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: Offset(0, widget.opensAbove ? -12 : 12),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.formControlBr,
              child: Material(
                color: AppColors.floatingSurface,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.borderSoft,
                      width: AppDimens.borderWidth,
                    ),
                    borderRadius: AppRadius.formControlBr,
                  ),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: AppScrollbar(
                      controller: _scrollController,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.items.length,
                        separatorBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
                          child: Divider(
                            height: AppDimens.dividerThickness,
                            thickness: AppDimens.dividerThickness,
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          return AnimatedTouchItem(
                            onTap: () => widget.onSelected(item),
                            normalColor: Colors.transparent,
                            pressedColor: Colors.transparent,
                            pressedOpacity: 0.5,
                            pressedScale: 0.98,
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item,
                                style: AppText.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color color;
  final bool isLoading;
  final double? width;
  final double height;
  final bool dismissKeyboardOnTap;

  const AuthButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.color,
    this.isLoading = false,
    this.width,
    this.height = AppDimens.buttonHeight,
    this.dismissKeyboardOnTap = true,
  });

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isPressed = false;

  bool get _canInteract => !widget.isLoading && widget.onTap != null;

  void _handlePointerDown(PointerDownEvent event) {
    if (!_canInteract) return;

    _isPressed = true;
    _controller.forward();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isPressed) return;

    _isPressed = false;
    _controller.reverse();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_isPressed) return;

    _isPressed = false;
    _controller.reverse();
  }

  void _handleTap() {
    if (!_canInteract) return;

    if (widget.dismissKeyboardOnTap) {
      FocusScope.of(context).unfocus();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final stateDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.buttonState;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return TweenAnimationBuilder<Decoration>(
              duration: stateDuration,
              curve: Curves.easeInOut,
              tween: DecorationTween(
                end: BoxDecoration(
                  color: !_canInteract
                      ? widget.color.withValues(alpha: 0.5)
                      : widget.color,
                  borderRadius: AppRadius.actionButtonBr,
                  boxShadow: [
                    // Fade the shadow color without changing its geometry.
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: _canInteract ? 0.3 : 0,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              builder: (context, decoration, _) {
                final buttonDecoration = decoration as BoxDecoration;
                final safeColor = buttonDecoration.color ?? widget.color;

                final base = safeColor;

                final pressed = safeColor.withValues(alpha: 0.75);
                final currentColor = Color.lerp(base, pressed, _controller.value)!;

                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: buttonDecoration.copyWith(color: currentColor),
                    child: Center(
                      child: AnimatedValueSwitcher(
                        child: widget.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                  strokeCap: StrokeCap.round,
                                ),
                              )
                            : Text(
                                widget.text,
                                key: ValueKey(widget.text),
                                style: AppText.button,
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RoleSwitcher extends StatelessWidget {
  final bool isPassenger;
  final ValueChanged<bool> onModeChanged;
  final String passengerLabel;
  final String driverLabel;
  final bool isEnabled;

  static const Color _passengerColor = AppColors.passenger;
  static const Color _driverColor = AppColors.driver;

  const RoleSwitcher({
    super.key,
    required this.isPassenger,
    required this.onModeChanged,
    required this.passengerLabel,
    required this.driverLabel,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedControlLock(
      isEnabled: isEnabled,
      child: Container(
        height: AppDimens.rowHeight,
        padding: const EdgeInsets.all(AppDimens.gapXs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.formControlBr,
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              alignment: isPassenger
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isPassenger ? _passengerColor : _driverColor,
                    borderRadius: AppRadius.compactControlBr,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _buildSwitchOption(
                  label: passengerLabel,
                  icon: Icons.person_pin_circle_rounded,
                  isSelected: isPassenger,
                  onTap: () => onModeChanged(true),
                ),
                _buildSwitchOption(
                  label: driverLabel,
                  icon: Icons.drive_eta_rounded,
                  isSelected: !isPassenger,
                  onTap: () => onModeChanged(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final targetColor = isSelected ? Colors.white : AppColors.textMuted;
    const animDuration = Duration(milliseconds: 250);

    return Expanded(
      child: AnimatedTouchItem(
        onTap: onTap,
        normalColor: Colors.transparent,
        pressedColor: Colors.transparent,
        pressedScale: 0.94,
        borderRadius: AppRadius.compactControlBr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              duration: animDuration,
              curve: Curves.easeInOutCubic,
              tween: ColorTween(end: targetColor),
              builder: (context, color, child) {
                return Icon(
                  icon,
                  color: color,
                  size: 24,
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: animDuration,
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                color: targetColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final String assetIcon;

  const SocialButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.assetIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedControlLock(
      isEnabled: onTap != null,
      child: AnimatedTouchItem(
        onTap: onTap,
        normalColor: AppColors.surface,
        pressedColor: AppColors.surfacePressed,
        pressedScale: 0.97,
        borderRadius: AppRadius.actionButtonBr,
        child: SizedBox(
          height: AppDimens.buttonHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(assetIcon, width: 22, height: 22),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Text(
                text,
                style: AppText.compactButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CancelButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final double? width;
  final double height;

  const CancelButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width,
    this.height = AppDimens.buttonHeight,
  });

  @override
  State<CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<CancelButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onTap?.call();
    });
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedControlLock(
      isEnabled: widget.onTap != null,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  alignment: Alignment.center,
                  child: Text(
                    widget.text,
                    style: AppText.compactButton.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthAnimatedText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color textColor;

  const AuthAnimatedText({
    super.key,
    required this.text,
    required this.onTap,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTextButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          style: AppText.link.copyWith(
            color: textColor,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

class FadeTextButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const FadeTextButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<FadeTextButton> createState() => _FadeTextButtonState();
}

class _FadeTextButtonState extends State<FadeTextButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onTap?.call();
    });
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedControlLock(
      isEnabled: widget.onTap != null,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}

class AuthCodeField extends StatefulWidget {
  final bool autofocus;
  final TextEditingController controller;
  final bool isEnabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Color focusColor;
  final Color cursorColor;
  final int length;

  const AuthCodeField({
    super.key,
    required this.controller,
    this.isEnabled = true,
    this.errorText,
    this.onChanged,
    required this.focusColor,
    this.cursorColor = const Color(0xFFB2EBF2),
    this.length = 6,
    this.autofocus = false,
  });

  @override
  State<AuthCodeField> createState() => _AuthCodeFieldState();
}

class _AuthCodeFieldState extends State<AuthCodeField> {
  late FocusNode _focusNode;
  String _text = "";

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
    _text = widget.controller.text;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_text != widget.controller.text) {
      setState(() {
        _text = widget.controller.text;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(AuthCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isEnabled && widget.isEnabled && widget.errorText != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNode);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    List<Widget> rowChildren = [];
    for (int i = 0; i < widget.length; i++) {
      final bool isFocusedBlock = widget.isEnabled &&
          _focusNode.hasFocus &&
          (i == _text.length || (_text.length == widget.length && i == widget.length - 1));

      final bool hasDigit = i < _text.length;
      final String digit = hasDigit ? _text[i] : "";

      Color borderColor = Colors.transparent;
      Color backgroundColor = widget.isEnabled ? AppColors.surface : AppColors.surfaceDisabled;

      if (hasError) {
        borderColor = AppColors.danger.withValues(alpha: 0.8);
        backgroundColor = AppColors.danger.withValues(alpha: 0.05);
      } else if (isFocusedBlock) {
        borderColor = widget.focusColor.withValues(alpha: 0.4);
      } else if (!widget.isEnabled) {
        borderColor = AppColors.borderMuted;
      }

      rowChildren.add(
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: AppDimens.controlHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadius.compactControlBr,
              border: Border.all(
                color: borderColor,
                width: AppDimens.focusBorderWidth,
              ),
            ),
            alignment: Alignment.center,
            child: hasDigit
                ? AnimatedFieldTextColor(
                    color: widget.isEnabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    builder: (textColor) => Text(
                      digit,
                      style: AppText.authTitle.copyWith(color: textColor),
                    ),
                  )
                : null,
          ),
        ),
      );

      if (i < widget.length - 1) {
        rowChildren.add(const SizedBox(width: AppDimens.gapSm));
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.isEnabled) {
          FocusScope.of(context).requestFocus(_focusNode);
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                autofocus: widget.autofocus,
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                enabled: widget.isEnabled,
                onChanged: widget.onChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: "",
                ),
              ),
            ),
          ),

          _ShimmerOverlay(
            isAnimating: !widget.isEnabled,
            child: Row(children: rowChildren),
          ),
        ],
      ),
    );
  }
}

class UaPlateTextIcon extends StatelessWidget {
  final Color color;

  const UaPlateTextIcon({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Transform.scale(
            scaleX: 0.78,
            alignment: Alignment.center,
            child: Text(
              'UA',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerOverlay extends StatefulWidget {
  final Widget child;
  final bool isAnimating;

  const _ShimmerOverlay({
    required this.child,
    required this.isAnimating,
  });

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_ShimmerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {

            if (!widget.isAnimating) {
              return const LinearGradient(
                colors: [Colors.transparent, Colors.transparent],
              ).createShader(bounds);
            }

            return LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-2.0 + (_controller.value * 4.0), 0.0),
              end: Alignment(-1.0 + (_controller.value * 4.0), 0.0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class AuthDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String hint;
  final IconData icon;
  final bool isEnabled;
  final String? errorText;
  final ValueChanged<T?>? onChanged;
  final String Function(T) itemLabelBuilder;
  final Color focusColor;

  /// Uses Flutter's native show-on-screen flow for the decorated field and
  /// leaves the legacy keyboard-aware focus coordinator disabled.
  final bool useKeyboardRevealTarget;
  final EdgeInsets? keyboardRevealVisibilityPadding;
  final KeyboardRevealController? keyboardRevealController;

  final List<TextInputFormatter>? formatters;
  final Color cursorColor;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final bool unfocusOnSelection;
  final FocusNode? focusNode;

  const AuthDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.itemLabelBuilder,
    required this.focusColor,
    this.isEnabled = true,
    this.errorText,
    this.onChanged,
    this.formatters,
    this.cursorColor = const Color(0xFFB2EBF2),
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
    this.unfocusOnSelection = true,
    this.useKeyboardRevealTarget = false,
    this.keyboardRevealVisibilityPadding,
    this.keyboardRevealController,
    this.focusNode,
  });

  @override
  State<AuthDropdownField<T>> createState() => _AuthDropdownFieldState<T>();
}

class _AuthDropdownFieldState<T> extends State<AuthDropdownField<T>> with SingleTickerProviderStateMixin {
  static const double _dropdownMaximumHeight = 280;
  static const double _dropdownGroupHeaderHeight = 32;

  final TextEditingController _controller = TextEditingController();
  late FocusNode _focusNode;
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  bool _isOpen = false;
  late final _overlayGeometryTracker = _AnchoredOverlayGeometryTracker(
    markNeedsBuild: _markOverlayNeedsBuild,
  );

  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );

    _updateFilteredItems("");

    if (widget.value != null) {
      _controller.text = widget.itemLabelBuilder(widget.value as T);
    }

    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;

    if (!widget.useKeyboardRevealTarget) {
      KeyboardAwareScrollView.handleFocusChange(context, _focusNode.hasFocus);
    }
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focusNode.hasFocus) {
        _openOverlay();
      } else {
        _closeOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(AuthDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isEnabled && oldWidget.isEnabled) {
      _focusNode.unfocus();
      _closeOverlay();
    }

    if (widget.value != oldWidget.value && widget.value != null) {
      _controller.text = widget.itemLabelBuilder(widget.value as T);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFilteredItems(_controller.text);
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _overlayGeometryTracker.stop();

    _overlayEntry?.remove();
    _overlayEntry = null;

    _animController.dispose();
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _updateFilteredItems(String query) {
    var filtered = widget.items.where((item) => widget
        .itemLabelBuilder(item)
        .toLowerCase()
        .contains(query.toLowerCase())).toList();

    filtered.sort((a, b) => widget.itemLabelBuilder(a).compareTo(widget.itemLabelBuilder(b)));

    setState(() {
      _filteredItems = filtered;
    });

    if (_isOpen) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _onSearchChanged(String query) {
    if (!widget.isEnabled) return;

    _updateFilteredItems(query);
  }

  void _openOverlay() {
    if (!widget.isEnabled) return;
    if (_isOpen) return;

    _controller.clear();
    _updateFilteredItems("");

    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }

    _animController.forward();
    _overlayGeometryTracker.start(context);

    setState(() {
      _isOpen = true;
    });
  }

  Future<void> _closeOverlay() async {
    if (!_isOpen) return;

    setState(() {
      _isOpen = false;
    });
    _overlayGeometryTracker.stop();

    await _animController.reverse();

    if (!_isOpen && mounted) {
      _overlayEntry?.remove();
      _overlayEntry = null;

      if (widget.value != null) {
        _controller.text = widget.itemLabelBuilder(widget.value as T);
      } else {
        _controller.clear();
      }
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final fieldBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final placement = _resolveAnchoredOverlayPlacement(
          overlayContext: overlayContext,
          fieldBox: fieldBox,
          desiredSurfaceHeight: _dropdownDesiredHeight(),
          maximumSurfaceHeight: _dropdownMaximumHeight,
        );
        final fieldWidth = fieldBox?.size.width ?? 0;

        return Positioned(
          width: fieldWidth + AppDimens.gapXl * 2,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: placement.opensAbove
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: placement.opensAbove
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(
              -AppDimens.gapXl,
              placement.opensAbove ? AppDimens.gapMd : -AppDimens.gapMd,
            ),
            child: TapRegion(
              groupId: this,
              child: _DropdownOverlayContent<T>(
                animation: _expandAnimation,
                items: _filteredItems,
                itemLabelBuilder: widget.itemLabelBuilder,
                opensAbove: placement.opensAbove,
                maxHeight: placement.maxSurfaceHeight,
                onPositionSelected: (T item) {
                  if (!widget.isEnabled || !_isOpen) return;

                  _controller.text = widget.itemLabelBuilder(item);
                  widget.onChanged?.call(item);
                  if (widget.unfocusOnSelection) {
                    _focusNode.unfocus();
                  } else {
                    _closeOverlay();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double _dropdownDesiredHeight() {
    if (_filteredItems.isEmpty) return 54;

    var groupCount = 0;
    var dividerCount = 0;
    var previousLetter = '';

    for (var index = 0; index < _filteredItems.length; index++) {
      final item = _filteredItems[index];
      final label = widget.itemLabelBuilder(item);
      final letter = label.isEmpty ? '' : label[0].toUpperCase();
      if (letter != previousLetter) {
        groupCount++;
      } else if (index > 0) {
        dividerCount++;
      }
      previousLetter = letter;
    }

    return math.min(
      _dropdownMaximumHeight,
      _filteredItems.length * 48.0 +
          groupCount * _dropdownGroupHeaderHeight +
          dividerCount * AppDimens.dividerThickness,
    );
  }

  void _markOverlayNeedsBuild() {
    _overlayEntry?.markNeedsBuild();
  }

  Widget _wrapKeyboardRevealTarget(Widget field) {
    if (!widget.useKeyboardRevealTarget) return field;

    return KeyboardRevealTarget(
      focusNode: _focusNode,
      controller: widget.keyboardRevealController,
      revealOnFocus: widget.keyboardRevealVisibilityPadding != null,
      visibilityPadding:
          widget.keyboardRevealVisibilityPadding ??
          const EdgeInsets.all(AppDimens.gapLg),
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null;
    final bool isFocused = _focusNode.hasFocus || _isOpen;

    Color getBorderColor() {
      if (hasError) return AppColors.danger.withValues(alpha: 0.8);
      if (isFocused && widget.isEnabled) {
        return widget.focusColor.withValues(alpha: 0.35);
      }
      if (!widget.isEnabled) return AppColors.borderMuted;
      return Colors.transparent;
    }

    Color getIconColor() {
      if (hasError) return AppColors.danger;
      if (isFocused) return widget.focusColor.withValues(alpha: 0.8);
      if (!widget.isEnabled) return AppColors.textDisabled;
      return AppColors.textMuted;
    }

    Color getArrowColor() {
      if (!widget.isEnabled) return AppColors.textDisabled;
      if (isFocused) return widget.focusColor.withValues(alpha: 0.8);
      return AppColors.textMuted;
    }

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          key: _fieldKey,
          link: _layerLink,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.isEnabled && !_focusNode.hasFocus) {
                FocusScope.of(context).requestFocus(_focusNode);
              }
            },
            child: AnimatedContainer(
              duration: AppDurations.fieldState,
              height: AppDimens.controlHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
              decoration: BoxDecoration(
                color: widget.isEnabled ? AppColors.surface : AppColors.surfaceDisabled,
                borderRadius: AppRadius.formControlBr,
                border: Border.all(
                  color: getBorderColor(),
                  width: AppDimens.focusBorderWidth,
                ),
              ),
              child: Row(
                children: [
                  AnimatedFieldIcon(
                    color: getIconColor(),
                    builder: (color) => Icon(widget.icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TweenAnimationBuilder<Color?>(
                      duration: const Duration(milliseconds: 300),
                      tween: ColorTween(
                        end: widget.value != null
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                      ),
                      builder: (context, hintColor, child) {
                        return AnimatedFieldTextColor(
                          color: widget.isEnabled
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          builder: (textColor) => TextField(
                            groupId: this,
                            focusNode: _focusNode,
                            controller: _controller,
                            enabled: widget.isEnabled,
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: _onSearchChanged,
                            inputFormatters: widget.formatters,
                            textCapitalization: widget.capitalization,
                            cursorColor: widget.cursorColor,
                            keyboardType: widget.keyboardType,
                            cursorHeight: AppDimens.inputCursorHeight,
                            cursorWidth: AppDimens.inputCursorWidth,
                            cursorRadius: const Radius.circular(AppRadius.full),
                            style: AppText.inputText.copyWith(color: textColor),
                            decoration: InputDecoration(
                              hintText: widget.value == null
                                  ? widget.hint
                                  : widget.itemLabelBuilder(widget.value as T),
                              hintStyle: AppText.inputHint.copyWith(
                                color: hintColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!widget.isEnabled)
                    const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.lock_outline,
                          color: AppColors.textDisabled,
                          size: 20,
                        )
                    )
                  else
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: AnimatedFieldIcon(
                        color: getArrowColor(),
                        builder: (color) => Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: color,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedFieldError(
          errorText: widget.errorText,
          padding: const EdgeInsets.only(top: 6, left: AppDimens.gapSm),
        ),
      ],

    );

    return _wrapKeyboardRevealTarget(field);
  }
}

class _DropdownOverlayContent<T> extends StatefulWidget {
  final Animation<double> animation;
  final List<T> items;
  final String Function(T) itemLabelBuilder;
  final bool opensAbove;
  final double maxHeight;
  final ValueChanged<T> onPositionSelected;

  const _DropdownOverlayContent({
    super.key,
    required this.animation,
    required this.items,
    required this.itemLabelBuilder,
    required this.opensAbove,
    required this.maxHeight,
    required this.onPositionSelected,
  });

  @override
  State<_DropdownOverlayContent<T>> createState() =>
      _DropdownOverlayContentState<T>();
}

class _DropdownOverlayContentState<T> extends State<_DropdownOverlayContent<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: widget.animation,
      alignment: widget.opensAbove
          ? AlignmentDirectional.bottomStart
          : AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: widget.animation,
        child: Padding(
          padding: EdgeInsets.only(
            top: widget.opensAbove ? 40 : AppDimens.gapLg,
            left: AppDimens.gapXl,
            right: AppDimens.gapXl,
            bottom: widget.opensAbove ? AppDimens.gapLg : 40,
          ),
          child: Container(
            key: const ValueKey('auth-dropdown-overlay-surface'),
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            decoration: BoxDecoration(
              borderRadius: AppRadius.formControlBr,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: Offset(0, widget.opensAbove ? -12 : 12),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.formControlBr,
              child: Material(
                color: AppColors.floatingSurface,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.borderSoft,
                      width: AppDimens.borderWidth,
                    ),
                    borderRadius: AppRadius.formControlBr,
                  ),
                  child: widget.items.isEmpty
                      ? SizedBox(
                    height: 54,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.nothingFound,
                        style: AppText.bodySecondary.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                      : MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: AppScrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final currentLabel = widget.itemLabelBuilder(item);
                          final currentLetter = currentLabel.isNotEmpty
                              ? currentLabel[0].toUpperCase()
                              : "";

                          final previousLabel = index > 0
                              ? widget.itemLabelBuilder(widget.items[index - 1])
                              : "";
                          final previousLetter = previousLabel.isNotEmpty
                              ? previousLabel[0].toUpperCase()
                              : "";

                          final isNewLetterGroup = currentLetter != previousLetter;

                          bool nextIsNewLetterGroup = false;
                          if (index < widget.items.length - 1) {
                            final nextLabel = widget.itemLabelBuilder(widget.items[index + 1]);
                            final nextLetter = nextLabel.isNotEmpty
                                ? nextLabel[0].toUpperCase()
                                : "";
                            nextIsNewLetterGroup = currentLetter != nextLetter;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isNewLetterGroup)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                  child: Text(
                                    currentLetter,
                                    style: AppText.caption.copyWith(
                                      color: AppColors.driverAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              AnimatedTouchItem(
                                onTap: () => widget.onPositionSelected(item),
                                normalColor: Colors.transparent,
                                pressedColor: Colors.transparent,
                                pressedOpacity: 0.5,
                                pressedScale: 0.98,
                                borderRadius: BorderRadius.zero,
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    currentLabel,
                                    style: AppText.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (index < widget.items.length - 1 &&
                                  !nextIsNewLetterGroup)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
