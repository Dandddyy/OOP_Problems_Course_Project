import 'package:dio/dio.dart';
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
import '../../services/google_auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/input_validation.dart';
import '../../services/user_session.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/auth_keyboard_scroll_layout.dart';
import '../../widgets/car_loading_overlay.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/dialogs/verification_code_dialog.dart';
import '../../widgets/keyboard_reveal_target.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final AuthApiService _authApiService = AuthApiService(ApiClient().dio);

  bool _isGlobalLoading = false;

  bool _isBtnLoading = false;

  bool isPassenger = true;

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final KeyboardRevealController _nameRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _emailRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _passwordRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _confirmPasswordRevealController =
      KeyboardRevealController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  FocusNode? _validate() {
    final loc = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    String? nameError;
    if (name.isEmpty) {
      nameError = "";
    } else if (name.length < 2) {
      nameError = loc.nameTooShort;
    } else if (!InputValidation.personName.hasMatch(name)) {
      nameError = loc.nameInvalidFormat;
    }

    String? emailError;
    if (email.isEmpty) {
      emailError = "";
    } else if (!InputValidation.email.hasMatch(email)) {
      emailError = loc.emailInvalidFormat;
    }

    String? passwordError;
    if (password.isEmpty) {
      passwordError = "";
    } else if (password.length < 6) {
      passwordError = loc.passwordTooShort;
    } else if (!InputValidation.password.hasMatch(password)) {
      passwordError = loc.passwordComplexity;
    }

    String? confirmPasswordError;
    if (confirm.isEmpty) {
      confirmPasswordError = "";
    } else if (confirm != password) {
      confirmPasswordError = loc.passwordsDoNotMatch;
    }

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
    });

    return nameError != null
        ? _nameFocusNode
        : emailError != null
        ? _emailFocusNode
        : passwordError != null
        ? _passwordFocusNode
        : confirmPasswordError != null
        ? _confirmPasswordFocusNode
        : null;
  }

  void _focusInvalidField(FocusNode focusNode) {
    final revealController = identical(focusNode, _nameFocusNode)
        ? _nameRevealController
        : identical(focusNode, _emailFocusNode)
        ? _emailRevealController
        : identical(focusNode, _passwordFocusNode)
        ? _passwordRevealController
        : _confirmPasswordRevealController;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      revealController.reveal();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nameRevealController.dispose();
    _emailRevealController.dispose();
    _passwordRevealController.dispose();
    _confirmPasswordRevealController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final bool isInterfaceLocked = _isBtnLoading || _isGlobalLoading;

    final Color passengerColor = AppColors.passenger;
    final Color driverColor = AppColors.driver;
    final Color passengerCursorColor = AppColors.passengerText;
    final Color driverCursorColor = AppColors.driverText;

    final Color currentColor = isPassenger ? passengerColor : driverColor;
    final Color currentCursorColor = isPassenger
        ? passengerCursorColor
        : driverCursorColor;

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
                        Center(
                          child: Text(
                            AppLocalizations.of(context)!.registration,
                            style: AppText.authTitle,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gap2xl),

                        RoleSwitcher(
                          isPassenger: isPassenger,
                          isEnabled: !isInterfaceLocked,
                          passengerLabel: AppLocalizations.of(
                            context,
                          )!.passengerRole,
                          driverLabel: AppLocalizations.of(context)!.driverRole,
                          onModeChanged: (val) {
                            if (_isBtnLoading || _isGlobalLoading) return;
                            setState(() => isPassenger = val);
                          },
                        ),

                        const SizedBox(height: AppDimens.gapMd),

                        Text(
                          AppLocalizations.of(context)!.chooseRoleDescription,
                          style: AppText.caption,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: AppDimens.gap2xl),

                        AuthTextField(
                          controller: _nameController,
                          hint: AppLocalizations.of(context)!.yourName,
                          icon: Icons.person_outline_rounded,
                          autofillHints: const [AutofillHints.name],
                          inputAction: TextInputAction.next,
                          isEnabled: !isInterfaceLocked,
                          focusColor: currentColor,
                          cursorColor: currentCursorColor,
                          errorText: _nameError,
                          focusNode: _nameFocusNode,
                          useKeyboardRevealTarget: true,
                          keyboardRevealController: _nameRevealController,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                          capitalization: TextCapitalization.words,

                          formatters: [
                            FilteringTextInputFormatter.allow(
                              InputValidation.personNameCharacter,
                            ),
                            FilteringTextInputFormatter.deny(
                              InputValidation
                                  .leadingOrRepeatedPersonNameSeparator,
                            ),
                            LengthLimitingTextInputFormatter(100),
                          ],
                        ),
                        const SizedBox(height: AppDimens.gapLg),
                        AuthTextField(
                          controller: _emailController,
                          hint: "E-mail",
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          inputAction: TextInputAction.next,
                          isEnabled: !isInterfaceLocked,
                          focusColor: currentColor,
                          cursorColor: currentCursorColor,
                          errorText: _emailError,
                          focusNode: _emailFocusNode,
                          useKeyboardRevealTarget: true,
                          keyboardRevealController: _emailRevealController,
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
                          autofillHints: const [AutofillHints.newPassword],
                          inputAction: TextInputAction.next,
                          isEnabled: !isInterfaceLocked,
                          focusColor: currentColor,
                          cursorColor: currentCursorColor,
                          errorText: _passwordError,
                          focusNode: _passwordFocusNode,
                          useKeyboardRevealTarget: true,
                          keyboardRevealController: _passwordRevealController,
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
                        const SizedBox(height: AppDimens.gapLg),
                        AuthTextField(
                          controller: _confirmPasswordController,
                          hint: AppLocalizations.of(context)!.confirmPassword,
                          icon: Icons.lock_reset_rounded,
                          isPassword: true,
                          autofillHints: const [AutofillHints.newPassword],
                          inputAction: TextInputAction.done,
                          isEnabled: !isInterfaceLocked,
                          focusColor: currentColor,
                          cursorColor: currentCursorColor,
                          errorText: _confirmPasswordError,
                          focusNode: _confirmPasswordFocusNode,
                          useKeyboardRevealTarget: true,
                          keyboardRevealController:
                              _confirmPasswordRevealController,
                          onChanged: (_) {
                            if (_confirmPasswordError != null) {
                              setState(() => _confirmPasswordError = null);
                            }
                          },
                          formatters: [
                            LengthLimitingTextInputFormatter(100),
                            FilteringTextInputFormatter.deny(
                              InputValidation.disallowedPasswordCharacters,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppDimens.gap2xl),

                        AuthButton(
                          text: AppLocalizations.of(context)!.register,
                          color: currentColor,
                          isLoading: _isBtnLoading,
                          dismissKeyboardOnTap: false,
                          onTap: isInterfaceLocked
                              ? null
                              : () async {
                                  if (_isBtnLoading || _isGlobalLoading) return;
                                  final invalidFocusNode = _validate();
                                  if (invalidFocusNode != null) {
                                    _focusInvalidField(invalidFocusNode);
                                    return;
                                  }

                                  FocusScope.of(context).unfocus();

                                  setState(() => _isBtnLoading = true);

                                  try {
                                    await Future.wait([
                                      _authApiService.sendRegistrationCode(
                                        PreRegisterRequest(
                                          name: _nameController.text.trim(),
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text,
                                        ),
                                      ),
                                      Future.delayed(
                                        const Duration(milliseconds: 600),
                                      ),
                                    ]);

                                    if (!context.mounted) return;

                                    await VerificationCodeDialog.show(
                                      context: context,
                                      email: _emailController.text.trim(),
                                      primaryColor: currentColor,
                                      cursorColor: currentCursorColor,
                                      onVerify: (code) {
                                        return _authApiService.register(
                                          RegisterRequest(
                                            name: _nameController.text.trim(),
                                            email: _emailController.text.trim(),
                                            password: _passwordController.text,
                                            currentMode: isPassenger
                                                ? AuthUserMode.passenger
                                                : AuthUserMode.driver,
                                            code: code,
                                          ),
                                        );
                                      },
                                    );
                                  } catch (e) {
                                    if (e is DioException) {
                                      final errorResponse =
                                          AuthErrorResponse.tryParse(
                                            e.response?.data,
                                          );

                                      if (errorResponse?.type ==
                                          'field_error') {
                                        if (!mounted) return;

                                        setState(() {
                                          if (errorResponse?.field == 'email') {
                                            _emailError =
                                                errorResponse?.message;
                                          }
                                        });
                                        return;
                                      }
                                    }
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
                              AppLocalizations.of(context)!.alreadyHaveAccount,
                              style: AppText.secondaryLink,
                            ),
                            FadeTextButton(
                              onTap: isInterfaceLocked
                                  ? null
                                  : () {
                                      context.pop();
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppDimens.gapXs,
                                ),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  style: AppText.link.copyWith(
                                    color: currentColor,
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.login,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.gapLg,
                              ),
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
                          onTap: isInterfaceLocked ? null : _handleGoogleSignIn,
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
