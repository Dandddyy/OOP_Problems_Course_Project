import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'animated_value_text.dart';

class AnimatedFieldError extends StatelessWidget {
  final String? errorText;
  final EdgeInsetsGeometry padding;

  const AnimatedFieldError({
    super.key,
    this.errorText,
    this.padding = const EdgeInsets.only(
      top: AppDimens.gapXs,
      left: AppDimens.gapSm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final message = errorText;
    final hasMessage = message != null && message.isNotEmpty;
    return ExcludeSemantics(
      excluding: !hasMessage,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        reverseDuration: reduceMotion ? Duration.zero : AppDurations.fieldState,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          alignment: AlignmentDirectional.topStart,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: hasMessage
            ? Padding(
                padding: padding,
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedValueText(message, style: AppText.fieldError),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
