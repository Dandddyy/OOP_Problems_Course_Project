import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../core/constants/trip_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/trip_price_input_formatter.dart';
import '../../utils/trip_publication_validation.dart';
import '../address_widgets.dart';
import '../animated_field_error.dart';
import '../animated_field_icon.dart';
import '../animated_field_text_color.dart';
import '../animated_touch_templates.dart';
import '../animated_value_switcher.dart';
import '../keyboard_aware_scroll_view.dart';
import '../keyboard_reveal_target.dart';
import '../shimmer_placeholder.dart';

enum RidePriceType { fixed, perKilometer }

class RidePriceField extends StatefulWidget {
  final TextEditingController controller;
  final RidePriceType priceType;
  final ValueChanged<RidePriceType> onPriceTypeChanged;
  final ValueChanged<String>? onChanged;
  final Color focusColor;
  final Color cursorColor;
  final bool isEnabled;
  final bool showSkeleton;
  final String? errorText;

  /// Lets Flutter reveal the entire decorated field instead of reporting
  /// focus to the legacy keyboard-aware scroll coordinator.
  final bool useKeyboardRevealTarget;
  final EdgeInsets? keyboardRevealVisibilityPadding;

  /// Keeps restoration clear of closed-screen chrome without increasing the
  /// spacing above an open keyboard.
  final EdgeInsets? keyboardRestoreVisibilityPadding;

  const RidePriceField({
    super.key,
    required this.controller,
    required this.priceType,
    required this.onPriceTypeChanged,
    required this.focusColor,
    this.cursorColor = AppColors.passengerText,
    this.onChanged,
    this.isEnabled = true,
    this.showSkeleton = false,
    this.errorText,
    this.useKeyboardRevealTarget = false,
    this.keyboardRevealVisibilityPadding,
    this.keyboardRestoreVisibilityPadding,
  });

  @override
  State<RidePriceField> createState() => _RidePriceFieldState();
}

class _RidePriceFieldState extends State<RidePriceField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;
  RidePriceType? _menuPriceType;
  bool? _lastMenuOpensAbove;
  bool? _closingMenuOpensAbove;

  late final AnimationController _menuAnimationController;
  late final Animation<double> _menuAnimation;

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOutQuart,
    );
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RidePriceField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isEnabled && oldWidget.isEnabled) {
      _removeMenuImmediately();
      _focusNode.unfocus();
    }

    if (widget.priceType != oldWidget.priceType &&
        _overlayEntry != null &&
        _menuPriceType != widget.priceType) {
      _menuPriceType = widget.priceType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayEntry != null) {
          _overlayEntry?.markNeedsBuild();
        }
      });
    }
  }

  void _handleFocusChanged() {
    if (!mounted) return;

    final hasFocus = _focusNode.hasFocus;
    if (!widget.useKeyboardRevealTarget) {
      KeyboardAwareScrollView.handleFocusChange(context, hasFocus);
    }

    if (!hasFocus && _isMenuOpen) {
      _closeMenu();
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _removeMenuImmediately();
    _menuAnimationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _labelFor(BuildContext context, RidePriceType type) {
    final localizations = AppLocalizations.of(context)!;

    return switch (type) {
      RidePriceType.fixed => localizations.fixedPrice,
      RidePriceType.perKilometer => localizations.pricePerKilometer,
    };
  }

  Widget _wrapKeyboardRevealTarget(Widget field) {
    if (!widget.useKeyboardRevealTarget) return field;

    return KeyboardRevealTarget(
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
  }

  @override
  Widget build(BuildContext context) {
    final upperBoundCents = widget.priceType == RidePriceType.fixed
        ? TripPolicy.fixedPriceUpperBoundCents
        : TripPolicy.perKilometerPriceUpperBoundCents;
    final cents = parsePriceCents(widget.controller.text);
    final hasError =
        widget.errorText != null || (cents != null && cents >= upperBoundCents);
    final isFocused = _focusNode.hasFocus || _isMenuOpen;

    Color borderColor() {
      if (hasError) return AppColors.danger.withValues(alpha: 0.8);
      if (isFocused && widget.isEnabled) {
        return widget.focusColor.withValues(alpha: 0.35);
      }
      if (!widget.isEnabled) return AppColors.borderMuted;
      return Colors.transparent;
    }

    Color leadingColor() {
      if (hasError) return AppColors.danger;
      if (isFocused) return widget.focusColor.withValues(alpha: 0.8);
      if (!widget.isEnabled) return AppColors.iconDisabled;
      return AppColors.iconMuted;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wrapKeyboardRevealTarget(
          CompositedTransformTarget(
            key: _fieldKey,
            link: _layerLink,
            child: TextFieldTapRegion(
              groupId: this,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.isEnabled && !widget.showSkeleton
                    ? () => FocusScope.of(context).requestFocus(_focusNode)
                    : null,
                child: AnimatedContainer(
                  duration: AppDurations.fieldState,
                  height: AppDimens.controlHeight,
                  decoration: BoxDecoration(
                    color: widget.isEnabled
                        ? AppColors.surface
                        : AppColors.surfaceDisabled,
                    borderRadius: AppRadius.formControlBr,
                    border: Border.all(
                      color: borderColor(),
                      width: AppDimens.focusBorderWidth,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: AppDimens.gapLg),
                        child: widget.showSkeleton
                            ? const ShimmerBlock(
                                width: 24,
                                height: 24,
                                borderRadius: 6,
                              )
                            : AnimatedFieldIcon(
                                color: leadingColor(),
                                builder: (color) => Icon(
                                  Icons.payments_outlined,
                                  color: color,
                                  size: 24,
                                ),
                              ),
                      ),
                      const SizedBox(width: AppDimens.gapLg),
                      Expanded(
                        child: widget.showSkeleton
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  right: AppDimens.gapMd,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: ShimmerPlaceholder(
                                    child: Text(
                                      AppLocalizations.of(context)!.price,
                                      style: AppText.inputHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                            : AnimatedFieldTextColor(
                                color: widget.isEnabled
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                builder: (textColor) => TextField(
                                  key: const ValueKey('ride-price-input'),
                                  groupId: this,
                                  controller: widget.controller,
                                  focusNode: _focusNode,
                                  enabled: widget.isEnabled,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  onChanged: widget.onChanged,
                                  inputFormatters: [
                                    TripPriceInputFormatter(
                                      upperBoundCents: upperBoundCents,
                                    ),
                                  ],
                                  cursorColor: widget.cursorColor,
                                  cursorHeight: AppDimens.inputCursorHeight,
                                  cursorWidth: AppDimens.inputCursorWidth,
                                  cursorRadius: const Radius.circular(
                                    AppRadius.full,
                                  ),
                                  style: AppText.inputText.copyWith(
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.price,
                                    hintStyle: AppText.inputHint,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.only(
                                      right: AppDimens.gapMd,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                      ),
                      Container(
                        width: AppDimens.dividerThickness,
                        height: 28,
                        color: AppColors.borderMuted,
                      ),
                      _buildPriceTypeSelector(context),
                    ],
                  ),
                ),
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
  }

  Widget _buildPriceTypeSelector(BuildContext context) {
    final priceType = widget.priceType;
    final typeLabel = _labelFor(context, priceType);

    Color arrowColor() {
      if (!widget.isEnabled) return AppColors.iconDisabled;
      if (_isMenuOpen) {
        return widget.focusColor.withValues(alpha: 0.8);
      }
      return AppColors.iconMuted;
    }

    return TextFieldTapRegion(
      groupId: this,
      child: Semantics(
        key: const ValueKey('ride-price-type-button'),
        button: true,
        enabled: widget.isEnabled && !widget.showSkeleton,
        label: typeLabel,
        child: AnimatedTouchItem(
          onTap: widget.isEnabled && !widget.showSkeleton ? _toggleMenu : null,
          normalColor: Colors.transparent,
          pressedColor: Colors.transparent,
          pressedScale: 0.95,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(AppRadius.control),
          ),
          child: SizedBox(
            width: 88,
            height: AppDimens.controlHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 30,
                  height: 38,
                  child: widget.showSkeleton
                      ? Center(
                          child: ShimmerPlaceholder(
                            child: _PriceUnitIcon(
                              priceType: priceType,
                              color: AppColors.iconSecondary,
                            ),
                          ),
                        )
                      : AnimatedValueSwitcher(
                          child: AnimatedFieldIcon(
                            key: ValueKey('ride-price-${priceType.name}-icon'),
                            color: widget.isEnabled
                                ? AppColors.iconSecondary
                                : AppColors.iconDisabled,
                            builder: (color) => _PriceUnitIcon(
                              priceType: priceType,
                              color: color,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: AppDimens.gapXs),
                SizedBox.square(
                  dimension: 24,
                  child: widget.showSkeleton
                      ? const Center(
                          child: ShimmerBlock(
                            width: 14,
                            height: 8,
                            borderRadius: 4,
                          ),
                        )
                      : TweenAnimationBuilder<Color?>(
                          key: const ValueKey('ride-price-type-arrow-color'),
                          duration: AppDurations.fieldState,
                          curve: Curves.easeInOutCubic,
                          tween: ColorTween(
                            begin: arrowColor(),
                            end: arrowColor(),
                          ),
                          builder: (context, color, _) {
                            if (!widget.isEnabled) {
                              return Icon(
                                Icons.lock_outline,
                                color: color,
                                size: 20,
                              );
                            }
                            return AnimatedRotation(
                              turns: _isMenuOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: color,
                                size: 24,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (!widget.isEnabled || _isMenuOpen) return;

    _menuPriceType = widget.priceType;
    _closingMenuOpensAbove = null;

    final isNewOverlay = _overlayEntry == null;
    if (isNewOverlay) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.markNeedsBuild();
    }

    setState(() => _isMenuOpen = true);
    _menuAnimationController.forward(from: isNewOverlay ? 0 : null);
  }

  Future<void> _closeMenu() async {
    if (!_isMenuOpen) return;

    _closingMenuOpensAbove = _lastMenuOpensAbove;
    if (mounted) {
      setState(() => _isMenuOpen = false);
    } else {
      _isMenuOpen = false;
    }

    try {
      await _menuAnimationController.reverse().orCancel;
    } on TickerCanceled {
      return;
    }

    if (!_isMenuOpen && mounted) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _menuPriceType = null;
      _lastMenuOpensAbove = null;
      _closingMenuOpensAbove = null;
    }
  }

  void _removeMenuImmediately() {
    _isMenuOpen = false;
    _menuAnimationController.stop();
    // Reset on the next open: overlay listeners may still be mounted during build.
    _overlayEntry?.remove();
    _overlayEntry = null;
    _menuPriceType = null;
    _lastMenuOpensAbove = null;
    _closingMenuOpensAbove = null;
  }

  void _selectPriceType(RidePriceType type) {
    if (!widget.isEnabled || !_isMenuOpen) return;

    final selectedType = _menuPriceType ?? widget.priceType;

    if (type != selectedType) {
      _menuPriceType = type;
      _overlayEntry?.markNeedsBuild();
      widget.onPriceTypeChanged(type);
    }
    _closeMenu();
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final fieldBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final media = MediaQuery.of(overlayContext);
        var opensAbove = _closingMenuOpensAbove ?? false;

        if (_closingMenuOpensAbove == null &&
            fieldBox != null &&
            fieldBox.attached) {
          final fieldTop = fieldBox.localToGlobal(Offset.zero).dy;
          final fieldBottom = fieldTop + fieldBox.size.height;
          var visibleTop = media.padding.top;
          var visibleBottom =
              media.size.height -
              (media.viewInsets.bottom > media.padding.bottom
                  ? media.viewInsets.bottom
                  : media.padding.bottom);

          final viewport = RenderAbstractViewport.maybeOf(fieldBox);
          final viewportBox = viewport is RenderBox
              ? viewport as RenderBox
              : null;
          if (viewportBox != null && viewportBox.attached) {
            final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
            final viewportBottom = viewportTop + viewportBox.size.height;
            visibleTop = math.max(visibleTop, viewportTop);
            visibleBottom = math.min(visibleBottom, viewportBottom);
          }

          final spaceAbove = fieldTop - visibleTop;
          final spaceBelow = visibleBottom - fieldBottom;
          const requiredMenuSpace = 117.0;
          final fitsBelow = spaceBelow >= requiredMenuSpace;
          final fitsAbove = spaceAbove >= requiredMenuSpace;

          opensAbove = !fitsBelow && (fitsAbove || spaceAbove > spaceBelow);
        }
        _lastMenuOpensAbove = opensAbove;

        final fieldWidth = fieldBox?.size.width ?? 264;

        return Positioned(
          width: fieldWidth + AppDimens.gapXl * 2,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: opensAbove
                ? Alignment.topRight
                : Alignment.bottomRight,
            followerAnchor: opensAbove
                ? Alignment.bottomRight
                : Alignment.topRight,
            offset: Offset(24, opensAbove ? 12 : -12),
            child: TextFieldTapRegion(
              groupId: this,
              onTapOutside: (_) => _closeMenu(),
              child: _buildMenuOverlay(
                overlayContext,
                opensAbove: opensAbove,
                selectedType: _menuPriceType ?? widget.priceType,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOverlay(
    BuildContext context, {
    required bool opensAbove,
    required RidePriceType selectedType,
  }) {
    return SizeTransition(
      sizeFactor: _menuAnimation,
      alignment: opensAbove
          ? AlignmentDirectional.bottomStart
          : AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: _menuAnimation,
        child: Padding(
          padding: EdgeInsets.only(
            top: opensAbove ? 40 : AppDimens.gapLg,
            left: AppDimens.gapXl,
            right: AppDimens.gapXl,
            bottom: opensAbove ? AppDimens.gapLg : 40,
          ),
          child: Container(
            key: const ValueKey('ride-price-type-menu-surface'),
            decoration: BoxDecoration(
              borderRadius: AppRadius.formControlBr,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: Offset(0, opensAbove ? -12 : 12),
                ),
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
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuItem(
                            context,
                            RidePriceType.fixed,
                            selectedType,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.gapLg,
                            ),
                            child: Divider(
                              key: const ValueKey('ride-price-type-divider'),
                              height: AppDimens.dividerThickness,
                              thickness: AppDimens.dividerThickness,
                              color: AppColors.borderSubtle,
                            ),
                          ),
                          _buildMenuItem(
                            context,
                            RidePriceType.perKilometer,
                            selectedType,
                          ),
                        ],
                      ),
                      AnimatedPositioned(
                        key: const ValueKey(
                          'ride-price-type-selected-check-position',
                        ),
                        top: selectedType == RidePriceType.fixed ? 14 : 63,
                        right: AppDimens.gapLg,
                        duration: AppDurations.fastest,
                        curve: Curves.easeOutCubic,
                        child: IgnorePointer(
                          child: Icon(
                            Icons.check_rounded,
                            key: const ValueKey(
                              'ride-price-type-selected-check',
                            ),
                            color: widget.focusColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    RidePriceType type,
    RidePriceType selectedType,
  ) {
    final isSelected = type == selectedType;

    return Semantics(
      selected: isSelected,
      button: true,
      child: AnimatedTouchItem(
        key: ValueKey('ride-price-type-${type.name}'),
        onTap: () => _selectPriceType(type),
        normalColor: Colors.transparent,
        pressedColor: Colors.transparent,
        pressedOpacity: 0.5,
        pressedScale: 0.98,
        borderRadius: BorderRadius.zero,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Center(
                    child: _PriceUnitIcon(
                      priceType: type,
                      color: AppColors.iconSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Text(
                    _labelFor(context, type),
                    style: AppText.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceUnitIcon extends StatelessWidget {
  final RidePriceType priceType;
  final Color color;

  const _PriceUnitIcon({required this.priceType, required this.color});

  @override
  Widget build(BuildContext context) {
    if (priceType == RidePriceType.fixed) {
      return Text(
        '₴',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: color,
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return SizedBox(
      width: 30,
      height: 38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '₴',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: color,
              fontSize: 15,
              height: 0.9,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: 28,
            height: AppDimens.dividerThickness,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: color,
          ),
          Text(
            '1 ${AppLocalizations.of(context)!.kilometersShort}',
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
