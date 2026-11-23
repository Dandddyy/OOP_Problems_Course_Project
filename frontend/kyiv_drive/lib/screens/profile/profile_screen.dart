import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_model.dart';
import '../../services/user_session.dart';
import '../../utils/pluralization_formatters.dart';
import '../../widgets/address_widgets.dart';
import '../../widgets/animated_touch_templates.dart';
import '../../widgets/animated_value_switcher.dart';
import '../../widgets/animated_value_text.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/profile_menu_widgets.dart';
import '../../widgets/dialogs/app_dialogs.dart';

import '../../core/network/api_client.dart';
import '../../services/auth_api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/car_loading_overlay.dart';

import '../../models/user_rating_model.dart';
import '../../services/user_api_service.dart';
import '../../widgets/top_bar_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthApiService _authApiService = AuthApiService(ApiClient().dio);
  final UserApiService _userApiService = UserApiService(ApiClient().dio);
  final ScrollController _scrollController = ScrollController();

  UserRatingModel? _ratingData;
  bool _isRatingLoading = true;

  String? _localName;
  String? _localAvatarUrl;

  bool _isModeSwitching = false;
  bool _isLoggingOut = false;

  bool get _isBusy => _isModeSwitching || _isLoggingOut;

  late bool _localIsPassenger;

  @override
  void initState() {
    super.initState();

    _localName = UserSession().name;
    _localAvatarUrl = UserSession().avatarUrl;
    _localIsPassenger = UserSession().currentMode == AppMode.passenger;

    _fetchUserRating();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRating() async {
    try {
      final results = await Future.wait([
        _userApiService.getUserRating(),
        Future<void>.delayed(const Duration(milliseconds: 400)),
      ]);

      if (!mounted) return;

      final profile = results[0] as UserRatingModel;
      UserSession().updateProfileSummary(
        name: profile.name,
        avatarUrl: profile.avatarUrl,
      );
      setState(() {
        _localName = profile.name;
        _localAvatarUrl = profile.avatarUrl;
        _ratingData = profile;
        _isRatingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isRatingLoading = false;
      });

      NotificationService.showError(error);
    }
  }

  Future<void> _handleModeSwitch(bool wantToBePassenger) async {
    if (_isBusy) return;

    if (_localIsPassenger == wantToBePassenger) {
      return;
    }

    setState(() {
      _isModeSwitching = true;
    });

    try {
      final results = await Future.wait([
        _authApiService.switchMode(
          SwitchModeRequest(
            targetMode: wantToBePassenger
                ? AuthUserMode.passenger
                : AuthUserMode.driver,
          ),
        ),
        Future<void>.delayed(const Duration(milliseconds: 900)),
      ]);

      final accessToken = results[0] as AccessTokenResponse;
      await UserSession().updateAccessToken(accessToken);

      if (!mounted) return;

      setState(() {
        _localName = UserSession().name;
        _localAvatarUrl = UserSession().avatarUrl;
        _localIsPassenger = UserSession().currentMode == AppMode.passenger;
      });
    } catch (error) {
      if (mounted) {
        NotificationService.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isModeSwitching = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    if (_isBusy) return;

    final loc = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.show(
      context,
      title: loc.logoutTitle,
      content: loc.logoutDescription,
      primaryButtonText: loc.logout,
      secondaryButtonText: loc.cancel,
      icon: Icons.logout_rounded,
      isDestructive: true,
      barrierDismissible: true,
    );

    if (confirmed != true || !mounted || _isBusy) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await UserSession().logout(deleteRemoteSession: true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      NotificationService.showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final avatarUrl = _localAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final userName = _localName ?? loc.unknownUser;
    final rating = _ratingData?.rating.toStringAsFixed(2) ?? '0.00';
    final reviews = PluralizationService.getReviews(
      context,
      _ratingData?.ratingCount ?? 0,
    );

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CarLoadingOverlay(
          isLoading: _isBusy,
          child: AppTopBarOverlayLayout(
            title: loc.profile,
            leadingIcon: Icons.arrow_back_rounded,
            onLeadingTap: () {
              if (_isBusy) return;
              context.pop();
            },
            bodyBuilder: (context, topInset) {
              return AppScrollbar(
                controller: _scrollController,
                mainAxisMargin: 0,
                padding: EdgeInsets.only(
                  top: AppTopBarOverlayLayout.contentInsetOf(context),
                  bottom: AppScrollbar.screenBottomInsetOf(
                    context,
                    clearance: AppDimens.gapLg,
                  ),
                  right: AppScrollbar.screenRightInsetOf(context),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(top: topInset),
                  child: AppBottomSafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.pagePadding,
                          ),
                          child: AnimatedTouchItem(
                            onTap: () {
                              print('Клік по профілю');
                            },
                            normalColor: Colors.transparent,
                            pressedColor: AppColors.surface,
                            borderRadius: AppRadius.fullBr,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: AppDimens.gapSm,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: const BoxDecoration(
                                      color: AppColors.floatingSurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: hasAvatar
                                        ? ClipOval(
                                            child: Image.network(
                                              avatarUrl,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                  ),
                                  const SizedBox(width: AppDimens.gapLg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedValueText(
                                          userName,
                                          style: AppText.screenTitle,
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 20,
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                color: Colors.amber,
                                                size: 18,
                                              ),
                                              const SizedBox(
                                                width: AppDimens.gapXs,
                                              ),
                                              Expanded(
                                                child: AnimatedValueSwitcher.withSkeleton(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                  showSkeleton:
                                                      _isRatingLoading,
                                                  skeleton: const Row(
                                                    key: ValueKey(
                                                      'rating_skeleton',
                                                    ),
                                                    children: [
                                                      ShimmerBlock(
                                                        width: 34,
                                                        height: 14,
                                                        borderRadius: AppShimmer
                                                            .textBorderRadius,
                                                      ),
                                                      SizedBox(
                                                        width: AppDimens.gapSm,
                                                      ),
                                                      ShimmerBlock(
                                                        width: 76,
                                                        height: 14,
                                                        borderRadius: AppShimmer
                                                            .textBorderRadius,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    key: ValueKey((
                                                      rating,
                                                      reviews,
                                                    )),
                                                    children: [
                                                      Text(
                                                        rating,
                                                        style: AppText
                                                            .bodySecondary
                                                            .copyWith(
                                                              color: AppColors
                                                                  .textPrimary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        width: AppDimens.gapSm,
                                                      ),
                                                      Flexible(
                                                        child: Text(
                                                          reviews,
                                                          style: AppText
                                                              .bodySecondary
                                                              .copyWith(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.4,
                                                                    ),
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppDimens.gapXl),
                        _buildDivider(loc.role),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.pagePadding,
                            vertical: AppDimens.gapLg,
                          ),
                          child: RoleSwitcher(
                            isPassenger: _localIsPassenger,
                            passengerLabel: loc.passengerRole,
                            driverLabel: loc.driverRole,
                            isEnabled: !_isBusy,
                            onModeChanged: _handleModeSwitch,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.authPagePadding,
                          ),
                          child: Text(
                            loc.chooseRoleDescription,
                            textAlign: TextAlign.center,
                            style: AppText.bodySecondary.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppDimens.gapXl),
                        _buildDivider(loc.menu),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return SizeTransition(
                                  sizeFactor: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                          child: !_localIsPassenger
                              ? IgnorePointer(
                                  key: const ValueKey('cars_menu_option'),
                                  ignoring: _localIsPassenger,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ProfileOptionButton(
                                        icon: Icons.directions_car_rounded,
                                        title: loc.cars,
                                        onTap: () {
                                          if (_localIsPassenger) return;
                                          print("Відкрито Автомобілі");
                                        },
                                      ),
                                      const ProfileMenuDivider(),
                                    ],
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('no_cars_option'),
                                  width: double.infinity,
                                ),
                        ),

                        ProfileOptionButton(
                          icon: Icons.settings_rounded,
                          title: loc.settingsButton,
                          onTap: () {
                            print("Відкрито Налаштування");
                          },
                        ),
                        const ProfileMenuDivider(),
                        ProfileOptionButton(
                          icon: Icons.privacy_tip_rounded,
                          title: loc.privacy,
                          onTap: () {
                            print("Відкрито Конфіденційність");
                          },
                        ),
                        const ProfileMenuDivider(),
                        ProfileOptionButton(
                          icon: Icons.help_outline_rounded,
                          title: loc.help,
                          onTap: () {
                            print("Відкрито Допомогу");
                          },
                        ),
                        const ProfileMenuDivider(),
                        ProfileOptionButton(
                          icon: Icons.info_outline_rounded,
                          title: loc.aboutService,
                          onTap: () {
                            print("Відкрито Про сервіс");
                          },
                        ),
                        const ProfileMenuDivider(),
                        ProfileOptionButton(
                          icon: Icons.logout_rounded,
                          title: loc.logoutFromProfile,
                          color: AppColors.danger,
                          onTap: () {
                            if (_isBusy) return;
                            _handleLogout();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        const SizedBox(width: AppDimens.pagePadding),
        Expanded(
          child: Container(
            height: AppDimens.dividerThickness,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
          child: Text(
            text,
            style: AppText.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: AppDimens.dividerThickness,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: AppDimens.pagePadding),
      ],
    );
  }
}
