import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../core/navigation/auth_home_entry.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_model.dart';
import '../../services/notification_service.dart';
import '../../services/user_session.dart';
import '../../widgets/app_bottom_bars.dart';
import '../../widgets/app_top_safe_area.dart';
import '../../widgets/auth_keyboard_scroll_layout.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/keyboard_reveal_target.dart';
import '../../services/auth_api_service.dart';
import '../../utils/input_validation.dart';

class GoogleRegistrationScreen extends StatefulWidget {
  final String googleEmail;
  final String googleName;
  final String? googlePhotoUrl;
  final String idToken;

  const GoogleRegistrationScreen({
    super.key,
    required this.googleEmail,
    required this.googleName,
    this.googlePhotoUrl,
    required this.idToken,
  });

  @override
  State<GoogleRegistrationScreen> createState() =>
      _GoogleRegistrationScreenState();
}

class _GoogleRegistrationScreenState extends State<GoogleRegistrationScreen> {
  final AuthApiService _authApiService = AuthApiService(ApiClient().dio);

  bool _isBtnLoading = false;
  bool isPassenger = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final KeyboardRevealController _nameRevealController =
      KeyboardRevealController();

  String? _nameError;

  bool _validate() {
    final loc = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();

    String? nameError;
    if (name.isEmpty) {
      nameError = "";
    } else if (name.length < 2) {
      nameError = loc.nameTooShort;
    } else if (!InputValidation.personName.hasMatch(name)) {
      nameError = loc.nameInvalidFormat;
    }

    setState(() => _nameError = nameError);
    return nameError == null;
  }

  void _focusNameField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocusNode.requestFocus();
      _nameRevealController.reveal();
    });
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.googleEmail;
    _nameController.text = InputValidation.filterPersonNameInput(
      widget.googleName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocusNode.dispose();
    _nameRevealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color passengerColor = AppColors.passenger;
    final Color driverColor = AppColors.driver;
    final Color passengerCursorColor = AppColors.passengerText;
    final Color driverCursorColor = AppColors.driverText;

    final Color currentColor = isPassenger ? passengerColor : driverColor;
    final Color currentCursorColor = isPassenger
        ? passengerCursorColor
        : driverCursorColor;

    return PopScope(
      canPop: !_isBtnLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        body: AuthKeyboardScrollLayout(
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
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderMuted,
                                  width: 2,
                                ),
                                image: widget.googlePhotoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          widget.googlePhotoUrl!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: AppColors.surfaceStrong,
                              ),
                              child: widget.googlePhotoUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/google_icon.png',
                                  width: 16,
                                  height: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimens.gapXl),

                      Center(
                        child: Text(
                          AppLocalizations.of(context)!.completionRegister,
                          textAlign: TextAlign.center,
                          style: AppText.authTitle,
                        ),
                      ),

                      const SizedBox(height: AppDimens.gap2xl),

                      RoleSwitcher(
                        isPassenger: isPassenger,
                        isEnabled: !_isBtnLoading,
                        passengerLabel: AppLocalizations.of(
                          context,
                        )!.passengerRole,
                        driverLabel: AppLocalizations.of(context)!.driverRole,
                        onModeChanged: (val) {
                          if (_isBtnLoading) return;
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
                        inputAction: TextInputAction.done,
                        isEnabled: !_isBtnLoading,
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
                        focusColor: currentColor,
                        isEnabled: false,
                      ),

                      const SizedBox(height: AppDimens.gap2xl),

                      AuthButton(
                        text: AppLocalizations.of(context)!.register,
                        color: currentColor,
                        isLoading: _isBtnLoading,
                        dismissKeyboardOnTap: false,
                        onTap: () async {
                          if (_isBtnLoading) return;
                          if (!_validate()) {
                            _focusNameField();
                            return;
                          }

                          FocusScope.of(context).unfocus();

                          setState(() => _isBtnLoading = true);

                          try {
                            await AuthHomeEntry.submit(
                              context,
                              () => _authApiService.googleRegister(
                                GoogleRegisterRequest(
                                  idToken: widget.idToken,
                                  name: _nameController.text,
                                  currentMode: isPassenger
                                      ? AuthUserMode.passenger
                                      : AuthUserMode.driver,
                                  avatarUrl: widget.googlePhotoUrl,
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

                      const SizedBox(height: AppDimens.gapXl),

                      Center(
                        child: CancelButton(
                          text: AppLocalizations.of(context)!.cancel,
                          height: 40,
                          width: 100,
                          onTap: _isBtnLoading
                              ? null
                              : () {
                                  context.pop();
                                },
                        ),
                      ),
                    ],
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
