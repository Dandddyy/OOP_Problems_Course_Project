import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../core/navigation/auth_home_entry.dart';
import '../../core/navigation/route_arguments.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_model.dart';
import '../../services/auth_api_service.dart';
import '../../services/user_session.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_brand_header.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/auth_keyboard_scroll_layout.dart';
import '../../widgets/dialogs/password_recovery_dialog.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/car_loading_overlay.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/keyboard_reveal_target.dart';
import '../../services/notification_service.dart';
import '../../utils/input_validation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGlobalLoading = false;

  bool _isBtnLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final KeyboardRevealController _emailRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _passwordRevealController =
      KeyboardRevealController();

  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final AuthApiService _authApiService = AuthApiService(ApiClient().dio);

  String? _emailError;
  String? _passwordError;

  final Color _primaryColor = AppColors.passenger;

  FocusNode? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailError = email.isEmpty ? "" : null;
    final passwordError = password.isEmpty ? "" : null;

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });

    return emailError != null
        ? _emailFocusNode
        : passwordError != null
        ? _passwordFocusNode
        : null;
  }

  void _focusInvalidField(FocusNode focusNode) {
    final revealController = identical(focusNode, _emailFocusNode)
        ? _emailRevealController
        : _passwordRevealController;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      revealController.reveal();
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGlobalLoading || _isBtnLoading) return;

    setState(() {
      _isGlobalLoading = true;
    });

    try {
      final result = await AuthHomeEntry.signInWithGoogle(
        context,
        () => _googleAuthService.handleSignIn(authApiService: _authApiService),
      );

      if (!mounted) return;

      if (result is GoogleRegistrationRequired) {
        context.push(
          '/google-register',
          extra: GoogleRegistrationRouteArgs(
            googleEmail: result.email,
            googleName: result.name,
            googlePhotoUrl: result.photoUrl,
            idToken: result.idToken,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(error);
      }
    } finally {
      if (mounted && UserSession().status != AuthStatus.authenticated) {
        setState(() {
          _isGlobalLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/google_icon.png'), context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailRevealController.dispose();
    _passwordRevealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInterfaceLocked = _isBtnLoading || _isGlobalLoading;

    return PopScope(
      canPop: !isInterfaceLocked,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        body: CarLoadingOverlay(
          isLoading: _isGlobalLoading,
          child: AuthKeyboardScrollLayout(
            builder: (context, _) {
              return AppTopSafeArea(
                      child: AppBottomSafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.authPagePadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppBrandHeader(color: _primaryColor),

                              const SizedBox(height: AppDimens.gap2xl),

                              Text(
                                AppLocalizations.of(context)!.welcomeTitle,
                                style: AppText.authTitle.copyWith(fontSize: 22),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppDimens.gapSm),
                              Text(
                                AppLocalizations.of(context)!.needToAuth,
                                style: AppText.bodySecondary,
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: AppDimens.gap2xl),

                              AuthTextField(
                                controller: _emailController,
                                hint: "E-mail",
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                inputAction: TextInputAction.next,
                                isEnabled: !isInterfaceLocked,
                                focusColor: _primaryColor,
                                errorText: _emailError,
                                focusNode: _emailFocusNode,
                                useKeyboardRevealTarget: true,
                                keyboardRevealController:
                                    _emailRevealController,
                                onChanged: (_) {
                                  if (_emailError != null) {
                                    setState(() => _emailError = null);
                                  }
                                },
                                capitalization: TextCapitalization.none,

                                formatters: [
                                  FilteringTextInputFormatter.allow(
                                    InputValidation.emailCharacter,
                                  ),
                                  LengthLimitingTextInputFormatter(255),
                                ],
                              ),
                              const SizedBox(height: AppDimens.gapLg),
                              AuthTextField(
                                controller: _passwordController,
                                hint: AppLocalizations.of(context)!.password,
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                autofillHints: const [AutofillHints.password],
                                inputAction: TextInputAction.done,
                                isEnabled: !isInterfaceLocked,
                                focusColor: _primaryColor,
                                errorText: _passwordError,
                                focusNode: _passwordFocusNode,
                                useKeyboardRevealTarget: true,
                                keyboardRevealController:
                                    _passwordRevealController,
                                onChanged: (_) {
                                  if (_passwordError != null) {
                                    setState(() => _passwordError = null);
                                  }
                                },
                                formatters: [
                                  LengthLimitingTextInputFormatter(100),
                                  FilteringTextInputFormatter.deny(
                                    InputValidation.disallowedPasswordCharacters,
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppDimens.gapSm),

                              Align(
                                alignment: Alignment.centerRight,
                                child: FadeTextButton(
                                  onTap: isInterfaceLocked ? null : () {
                                    PasswordRecoveryDialog.show(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                    child: Text(
                                      AppLocalizations.of(context)!.forgotPassword,
                                      style: AppText.secondaryLink,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: AppDimens.gapXl),

                              AuthButton(
                                text: AppLocalizations.of(context)!.loginButton,
                                color: _primaryColor,
                                isLoading: _isBtnLoading,
                                dismissKeyboardOnTap: false,
                                onTap: isInterfaceLocked ? null : () async {
                                  if (_isBtnLoading || _isGlobalLoading) return;
                                  final invalidFocusNode = _validate();
                                  if (invalidFocusNode != null) {
                                    _focusInvalidField(invalidFocusNode);
                                    return;
                                  }

                                  FocusScope.of(context).unfocus();

                                  setState(() => _isBtnLoading = true);

                                  try {
                                    await AuthHomeEntry.submit(
                                      context,
                                      () => _authApiService.login(
                                        LoginRequest(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (mounted) {
                                      NotificationService.showError(e);
                                    }
                                  } finally {
                                    if (mounted &&
                                        UserSession().status !=
                                            AuthStatus.authenticated) {
                                      setState(() => _isBtnLoading = false);
                                    }
                                  }
                                },
                              ),

                              const SizedBox(height: AppDimens.gapLg),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.noAccountYet,
                                    style: AppText.secondaryLink,
                                  ),

                                  FadeTextButton(
                                    onTap: isInterfaceLocked ? null : () {
                                      context.push('/register');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        AppLocalizations.of(context)!.register,
                                        style: AppText.link.copyWith(
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppDimens.gapLg),

                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: AppDimens.dividerThickness,
                                      color: AppColors.borderMuted,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.gapLg),
                                    child: Text(
                                      AppLocalizations.of(context)!.or,
                                      style: AppText.caption,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: AppDimens.dividerThickness,
                                      color: AppColors.borderMuted,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: AppDimens.gapXl),

                              SocialButton(
                                text: AppLocalizations.of(context)!.viaGoogle,
                                assetIcon: 'assets/images/google_icon.png',
                                onTap: isInterfaceLocked
                                    ? null
                                    : _handleGoogleSignIn,
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
}
