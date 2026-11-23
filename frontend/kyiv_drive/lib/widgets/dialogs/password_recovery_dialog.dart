import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../core/navigation/auth_home_entry.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_model.dart';
import '../../services/auth_api_service.dart';
import '../../services/user_session.dart';
import '../animated_value_text.dart';
import '../../utils/input_validation.dart';
import '../auth_widgets.dart';
import '../keyboard_reveal_target.dart';
import '../../services/notification_service.dart';
import 'dialog_layout.dart';

class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: false,
      barrierLabel: 'Recovery Dialog',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return const PasswordRecoveryDialog();
      },
    );
  }

  @override
  State<PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  int _currentStep = 1;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passFocusNode = FocusNode();
  final FocusNode _confirmPassFocusNode = FocusNode();
  final KeyboardRevealController _emailRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _passRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _confirmPassRevealController =
      KeyboardRevealController();

  String? _emailError;
  String? _codeError;
  String? _passError;
  String? _confirmPassError;

  final Color _primaryColor = AppColors.passenger;
  final Color _cursorColor = AppColors.passengerText;

  final AuthApiService _authApiService = AuthApiService(ApiClient().dio);
  String? _passwordResetToken;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _emailController.dispose();
    _codeController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _emailFocusNode.dispose();
    _passFocusNode.dispose();
    _confirmPassFocusNode.dispose();
    _emailRevealController.dispose();
    _passRevealController.dispose();
    _confirmPassRevealController.dispose();
    super.dispose();
  }

  void _focusInvalidField(
    FocusNode focusNode,
    KeyboardRevealController revealController,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      revealController.reveal();
    });
  }

  void _onCodeChanged() {
    if (_codeController.text.length == 6 && _currentStep == 2 && !_isLoading) {
      _submitStep2();
    }
  }

  Future<void> _submitStep1() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final localizations = AppLocalizations.of(context)!;

    if (email.isEmpty) {
      setState(() => _emailError = "");
      _focusInvalidField(_emailFocusNode, _emailRevealController);
      return;
    } else if (!InputValidation.email.hasMatch(email)) {
      setState(() => _emailError = localizations.emailInvalidFormat);
      _focusInvalidField(_emailFocusNode, _emailRevealController);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _authApiService.sendCode(SendCodeRequest(email: email)),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);
      if (mounted) {
        setState(() {
          _currentStep = 2;
        });
      }
    } on DioException catch (e) {
      final errorResponse = AuthErrorResponse.tryParse(e.response?.data);
      if (errorResponse?.type == 'field_error') {
        setState(() => _emailError = errorResponse?.message);
      } else {
        if (mounted) NotificationService.showError(e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitStep2() async {
    if (_isLoading) return;

    setState(() => _codeError = null);

    final code = _codeController.text.trim();

    if (code.length < 6) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _authApiService.verifyCode(
          VerifyCodeRequest(email: _emailController.text.trim(), code: code),
        ),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);

      final response = results[0] as PasswordResetGrant;
      _passwordResetToken = response.passwordResetToken;

      if (mounted) {
        setState(() {
          _currentStep = 3;
        });
      }
    } on DioException catch (e) {
      final errorResponse = AuthErrorResponse.tryParse(e.response?.data);
      if (errorResponse?.type == 'field_error') {
        setState(() {
          _codeError = errorResponse?.message;
          _codeController.clear();
        });
      } else {
        if (mounted) NotificationService.showError(e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitStep3() async {
    if (_isLoading) return;

    final pass = _passController.text;
    final confirm = _confirmPassController.text;
    final localizations = AppLocalizations.of(context)!;

    String? passError;
    if (pass.isEmpty) {
      passError = "";
    } else if (pass.length < 6) {
      passError = localizations.passwordTooShort;
    } else if (!InputValidation.password.hasMatch(pass)) {
      passError = localizations.passwordComplexity;
    }

    String? confirmPassError;
    if (confirm.isEmpty) {
      confirmPassError = "";
    } else if (confirm != pass) {
      confirmPassError = localizations.passwordsDoNotMatch;
    }

    setState(() {
      _passError = passError;
      _confirmPassError = confirmPassError;
    });

    if (passError != null) {
      _focusInvalidField(_passFocusNode, _passRevealController);
      return;
    }
    if (confirmPassError != null) {
      _focusInvalidField(_confirmPassFocusNode, _confirmPassRevealController);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await AuthHomeEntry.submit(
        context,
        () => _authApiService.resetPassword(
          ResetPasswordRequest(
            newPassword: pass,
            passwordResetToken: _passwordResetToken!,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final errorResponse = AuthErrorResponse.tryParse(e.response?.data);
      if (errorResponse?.type == 'field_error') {
        setState(() => _passError = errorResponse?.message);
      } else {
        NotificationService.showError(e);
      }
    } finally {
      if (mounted && UserSession().status != AuthStatus.authenticated) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "";
    String desc = "";
    String btnText = "";
    VoidCallback onAction = () {};
    List<Widget> contentWidgets = [];

    switch (_currentStep) {
      case 1:
        title = AppLocalizations.of(context)!.recoveryTitle;
        desc = AppLocalizations.of(context)!.recoveryStep1Desc;
        btnText = AppLocalizations.of(context)!.sendCode;
        onAction = _submitStep1;
        contentWidgets = [
          AuthTextField(
            key: const ValueKey('email_field'),
            controller: _emailController,
            autofocus: true,
            hint: "Email",
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            inputAction: TextInputAction.done,
            capitalization: TextCapitalization.none,
            isEnabled: !_isLoading,
            focusColor: _primaryColor,
            cursorColor: _cursorColor,
            errorText: _emailError,
            focusNode: _emailFocusNode,
            useKeyboardRevealTarget: true,
            keyboardRevealController: _emailRevealController,
            onChanged: (val) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            formatters: [
              FilteringTextInputFormatter.allow(InputValidation.emailCharacter),
              LengthLimitingTextInputFormatter(255),
            ],
          ),
        ];
        break;

      case 2:
        title = AppLocalizations.of(context)!.recoveryTitle;
        desc = AppLocalizations.of(
          context,
        )!.recoveryStep2Desc(_emailController.text);
        btnText = AppLocalizations.of(context)!.verify;
        onAction = _submitStep2;
        contentWidgets = [
          AuthCodeField(
            key: const ValueKey('code_field'),
            controller: _codeController,
            autofocus: true,
            isEnabled: !_isLoading,
            focusColor: _primaryColor,
            cursorColor: _cursorColor,
            errorText: _codeError,
            onChanged: (val) {
              if (_codeError != null) setState(() => _codeError = null);
            },
          ),
        ];
        break;

      case 3:
        title = AppLocalizations.of(context)!.recoveryTitle;
        desc = AppLocalizations.of(context)!.recoveryStep3Desc;
        btnText = AppLocalizations.of(context)!.save;
        onAction = _submitStep3;
        contentWidgets = [
          AuthTextField(
            key: const ValueKey('new_pass_field'),
            controller: _passController,
            autofocus: true,
            hint: AppLocalizations.of(context)!.newPassword,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            inputAction: TextInputAction.next,
            isEnabled: !_isLoading,
            focusColor: _primaryColor,
            cursorColor: _cursorColor,
            errorText: _passError,
            focusNode: _passFocusNode,
            useKeyboardRevealTarget: true,
            keyboardRevealController: _passRevealController,
            onChanged: (val) {
              if (_passError != null) setState(() => _passError = null);
            },
            formatters: [
              LengthLimitingTextInputFormatter(100),
              FilteringTextInputFormatter.deny(
                InputValidation.disallowedPasswordCharacters,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          AuthTextField(
            key: const ValueKey('confirm_pass_field'),
            controller: _confirmPassController,
            hint: AppLocalizations.of(context)!.confirmPassword,
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            inputAction: TextInputAction.done,
            isEnabled: !_isLoading,
            focusColor: _primaryColor,
            cursorColor: _cursorColor,
            errorText: _confirmPassError,
            focusNode: _confirmPassFocusNode,
            useKeyboardRevealTarget: true,
            keyboardRevealController: _confirmPassRevealController,
            onChanged: (val) {
              if (_confirmPassError != null) {
                setState(() => _confirmPassError = null);
              }
            },
            formatters: [
              LengthLimitingTextInputFormatter(100),
              FilteringTextInputFormatter.deny(
                InputValidation.disallowedPasswordCharacters,
              ),
            ],
          ),
        ];
        break;
    }

    return PopScope(
      canPop: !_isLoading,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Dialog(
          backgroundColor: AppColors.background,
          insetPadding: safeDialogInsetPadding(context),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.surfaceBr),
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(AppDimens.gapXl),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.surfaceBr,
              border: Border.all(
                color: AppColors.borderSoft,
                width: AppDimens.borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedValueText(
                  title,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                  style: AppText.modalTitle,
                ),

                const SizedBox(height: AppDimens.gapMd),

                AnimatedValueText(
                  desc,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                  style: AppText.bodySecondary,
                ),

                const SizedBox(height: AppDimens.gapXl),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previousChildren,
                              ?currentChild,
                            ],
                          );
                        },
                    child: Column(
                      key: ValueKey('content_$_currentStep'),
                      children: contentWidgets,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimens.gapXl),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentStep != 2
                      ? Row(
                          key: ValueKey('buttons_row_$_currentStep'),
                          children: [
                            Expanded(
                              child: CancelButton(
                                text: AppLocalizations.of(context)!.cancel,
                                onTap: _isLoading ? null : () => context.pop(),
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Expanded(
                              child: AuthButton(
                                text: btnText,
                                color: _primaryColor,
                                isLoading: _isLoading,
                                dismissKeyboardOnTap: false,
                                onTap: onAction,
                              ),
                            ),
                          ],
                        )
                      : Center(
                          key: const ValueKey('buttons_center_2'),
                          child: CancelButton(
                            text: AppLocalizations.of(context)!.cancel,
                            width: 120,
                            onTap: _isLoading ? null : () => context.pop(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
