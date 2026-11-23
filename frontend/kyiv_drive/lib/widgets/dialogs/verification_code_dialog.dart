import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../core/navigation/auth_home_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_model.dart';
import '../../services/notification_service.dart';
import '../../services/user_session.dart';
import '../auth_widgets.dart';
import 'dialog_layout.dart';

class VerificationCodeDialog extends StatefulWidget {
  final String email;
  final Color primaryColor;
  final Color cursorColor;

  final Future<AuthTokens> Function(String code) onVerify;

  const VerificationCodeDialog({
    super.key,
    required this.email,
    required this.primaryColor,
    required this.cursorColor,
    required this.onVerify,
  });

  static Future<void> show({
    required BuildContext context,
    required String email,
    required Color primaryColor,
    required Color cursorColor,
    required Future<AuthTokens> Function(String code) onVerify,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: false,
      barrierLabel: 'Verification Dialog',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
          ) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (
          context,
          animation,
          secondaryAnimation,
          ) {
        return VerificationCodeDialog(
          email: email,
          primaryColor: primaryColor,
          cursorColor: cursorColor,
          onVerify: onVerify,
        );
      },
    );
  }

  @override
  State<VerificationCodeDialog> createState() => _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<VerificationCodeDialog> {
  bool _isLoading = false;
  String? _codeError;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_codeController.text.length == 6 && !_isLoading) {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final code = _codeController.text.trim();

    if (code.length != 6) return;

    setState(() {
      _codeError = null;
      _isLoading = true;
    });

    try {
      await AuthHomeEntry.submit(context, () => widget.onVerify(code));
    } on DioException catch (error) {
      if (!mounted) return;

      final errorResponse = AuthErrorResponse.tryParse(error.response?.data);

      if (errorResponse?.type == 'field_error') {
        setState(() {
          _codeError = errorResponse?.message;
          _codeController.clear();
        });
      } else {
        NotificationService.showError(error);
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(error);
      }
    } finally {
      if (mounted && UserSession().status != AuthStatus.authenticated) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Dialog(
          backgroundColor: AppColors.background,
          insetPadding: safeDialogInsetPadding(context),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.surfaceBr,
          ),
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
                Text(
                  AppLocalizations.of(context)!.emailConfirmationTitle,
                  textAlign: TextAlign.center,
                  style: AppText.modalTitle,
                ),
                const SizedBox(height: AppDimens.gapMd),
                Text(
                  AppLocalizations.of(context)!.recoveryStep2Desc(widget.email),
                  textAlign: TextAlign.center,
                  style: AppText.bodySecondary,
                ),
                const SizedBox(height: AppDimens.gapXl),
                AuthCodeField(
                  key: const ValueKey('reg_code_field'),
                  controller: _codeController,
                  autofocus: true,
                  isEnabled: !_isLoading,
                  focusColor: widget.primaryColor,
                  cursorColor: widget.cursorColor,
                  errorText: _codeError,
                  onChanged: (val) {
                    if (_codeError != null) {
                      setState(() => _codeError = null);
                    }
                  },
                ),
                const SizedBox(height: AppDimens.gapXl),
                Center(
                  child: CancelButton(
                    text: AppLocalizations.of(context)!.cancel,
                    width: 120,
                    onTap: _isLoading ? null : () => context.pop(),
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
