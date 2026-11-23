import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_ui_tokens.dart';
import 'app_top_safe_area.dart';

class AppTopNotification extends StatefulWidget {
  final String message;
  final bool isError;
  final Color? brandColor;
  final VoidCallback onDismiss;

  const AppTopNotification({
    super.key,
    required this.message,
    required this.isError,
    required this.onDismiss,
    this.brandColor,
  });

  @override
  State<AppTopNotification> createState() =>
      _AppTopNotificationState();
}

class _AppTopNotificationState
    extends State<AppTopNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    if (widget.isError) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    _autoDismissTimer = Timer(
      const Duration(milliseconds: 3500),
      dismiss,
    );
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    if (_isDismissing) return;

    _isDismissing = true;
    _autoDismissTimer?.cancel();

    try {
      if (mounted) {
        await _controller.reverse();
      }
    } finally {
      if (mounted) {
        widget.onDismiss();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isError
        ? AppColors.danger
        : widget.brandColor ??
        AppColors.passengerAccent;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: AppTopSafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
                onVerticalDragEnd: (_) => dismiss(),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.controlBr,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.controlBr,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 12,
                        sigmaY: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.gapLg,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isError
                              ? activeColor.withValues(alpha: 0.12)
                              : AppColors.background
                              .withValues(alpha: 0.75),
                          borderRadius:
                          AppRadius.controlBr,
                          border: Border.all(
                            color: widget.isError
                                ? activeColor
                                .withValues(alpha: 0.3)
                                : AppColors.borderSoft,
                            width: AppDimens.borderWidth,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(
                                AppDimens.gapSm,
                              ),
                              decoration: BoxDecoration(
                                color: activeColor
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isError
                                    ? Icons
                                    .warning_amber_rounded
                                    : Icons
                                    .check_circle_outline_rounded,
                                color: activeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: AppText.bodySecondary
                                    .copyWith(
                                  color:
                                  AppColors.textPrimary,
                                  fontWeight:
                                  FontWeight.w600,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow:
                                TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }
}