import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';
import 'address_widgets.dart';

/// Uses the child's layout so loading placeholders also follow text scaling,
/// localization and wrapping. The child cannot receive input while hidden.
class ShimmerPlaceholder extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double horizontalInset;
  final double verticalInset;

  const ShimmerPlaceholder({
    super.key,
    required this.child,
    this.borderRadius = AppShimmer.textBorderRadius,
    this.horizontalInset = 0,
    this.verticalInset = AppShimmer.textVerticalInset,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ExcludeFocus(
        child: IgnorePointer(
          child: Stack(
            children: [
              Opacity(opacity: 0, child: child),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalInset,
                    vertical: verticalInset,
                  ),
                  child: ShimmerBlock(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A placeholder for each line of a paragraph, with the same wrapping as Text.
class ShimmerParagraph extends StatelessWidget {
  final String text;
  final TextStyle style;

  const ShimmerParagraph(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    final effectiveStyle = defaults.style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter =
            TextPainter(
              text: TextSpan(
                text: text,
                style: MediaQuery.boldTextOf(context)
                    ? effectiveStyle.copyWith(fontWeight: FontWeight.bold)
                    : effectiveStyle,
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.localeOf(context),
              textWidthBasis: defaults.textWidthBasis,
              textHeightBehavior: defaults.textHeightBehavior,
              maxLines: defaults.maxLines,
            )..layout(
              minWidth: constraints.minWidth,
              maxWidth: constraints.maxWidth,
            );
        final size = painter.size;
        final lines = painter.computeLineMetrics();
        painter.dispose();
        return SizedBox.fromSize(
          size: size,
          child: Stack(
            children: [
              for (final line in lines)
                if (line.width > 0 &&
                    line.height > 2 * AppShimmer.textVerticalInset)
                  Positioned(
                    left: line.left,
                    top:
                        line.baseline -
                        line.ascent +
                        AppShimmer.textVerticalInset,
                    child: ShimmerBlock(
                      width: line.width,
                      height: line.height - 2 * AppShimmer.textVerticalInset,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
