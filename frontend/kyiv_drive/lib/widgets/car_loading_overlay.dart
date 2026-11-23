import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../l10n/app_localizations.dart';
import '../core/constants/app_ui_tokens.dart';

class CarLoadingOverlay extends StatefulWidget {
  final bool isLoading;
  final Widget child;

  const CarLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  State<CarLoadingOverlay> createState() => _CarLoadingOverlayState();
}

class _CarLoadingOverlayState extends State<CarLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appearanceController;

  late final Animation<double> _blurAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _appearanceController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
      value: widget.isLoading ? 1 : 0,
    );

    _blurAnimation = Tween<double>(
      begin: 0,
      end: 5,
    ).animate(
      CurvedAnimation(
        parent: _appearanceController,
        curve: Curves.easeOut,
      ),
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _appearanceController,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _appearanceController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CarLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _appearanceController.forward();
      } else {
        _appearanceController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        AnimatedBuilder(
          animation: _appearanceController,
          builder: (context, child) {
            if (_appearanceController.isDismissed) {
              return const SizedBox.shrink();
            }

            return IgnorePointer(
              ignoring: !widget.isLoading,
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _blurAnimation.value,
                      sigmaY: _blurAnimation.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha:
                        0.4 * _opacityAnimation.value,
                      ),
                    ),
                  ),

                  Center(
                    child: FadeTransition(
                      opacity: _opacityAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 20,
                            top: 8,
                            bottom: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.9),
                            borderRadius: AppRadius.surfaceBr,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 90,
                                child: ColorFiltered(
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  child: Lottie.asset(
                                    'assets/animations/CarB.json',
                                    repeat: true,
                                  ),
                                ),
                              ),

                              Material(
                                color: Colors.transparent,
                                child: Text(
                                  AppLocalizations.of(context)!.letsGoLoading,
                                  style: AppText.bodySecondary.copyWith(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
