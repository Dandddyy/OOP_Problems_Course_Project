import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF1C1C1E);
  static const mapBackground = Color(0xFF393F46);

  static const passenger = Color(0xFF0097A7); // Colors.cyan.shade700
  static const driver = Color(0xFFD84315); // Colors.deepOrange.shade800

  static const passengerAccent = Color(0xFF00ACC1); // Colors.cyan.shade600
  static const driverAccent = Color(0xFFF4511E); // Colors.deepOrange.shade600

  static const driverRouteLine = Color(0xFF9C8778);
  static const passengerRouteLine = Color(0xFF78909C); // blueGrey.shade400
  static const passengerPinHole = Color(0xFF10151C);
  static const driverPinHole = Color(0xFF1C1510);

  static const passengerText = Color(0xFFB2EBF2);
  static const driverText = Color(0xFFFFD4C5);

  static const danger = Color(0xFFEF5350);

  static final Color sheetHandle = Colors.white.withValues(alpha: 0.2);

  static final Color surface = Colors.white.withValues(alpha: 0.05);
  static final Color surfacePressed = Colors.white.withValues(alpha: 0.08);
  static final Color surfaceStrong = Colors.white.withValues(alpha: 0.10);
  static final Color surfaceDisabled = Colors.black.withValues(alpha: 0.08);

  static const floatingSurface = Color(0xFF282829);

  static final Color borderSoft = Colors.white.withValues(alpha: 0.08);
  static final Color borderSubtle = Colors.white.withValues(alpha: 0.05);
  static final Color borderMuted = Colors.white.withValues(alpha: 0.10);

  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white60;
  static const textMuted = Colors.white38;
  static const textDisabled = Colors.white24;

  static const iconPrimary = Colors.white;
  static const iconSecondary = Colors.white70;
  static const iconMuted = Colors.white38;
  static const iconDisabled = Colors.white24;

  static const shimmerBase = Color(0xFF333336);
  static const shimmerHighlight = Color(0xFF4A4A4D);
}

abstract final class AppRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const soft = 18.0;
  static const control = 20.0;
  static const large = 28.0;
  static const full = 999.0;

  static BorderRadius br(double value) => BorderRadius.circular(value);

  static BorderRadius get smallBr => br(small);
  static BorderRadius get mediumBr => br(medium);
  static BorderRadius get softBr => br(soft);
  static BorderRadius get controlBr => br(control);
  static BorderRadius get largeBr => br(large);
  static BorderRadius get fullBr => br(full);

  // Semantic aliases.
  static BorderRadius get compactControlBr => mediumBr; // tabs, weekdays, date/time
  static BorderRadius get floatingControlBr => softBr; // top buttons, avatar, map buttons
  static BorderRadius get formControlBr => controlBr; // fields, selectors, address card
  static BorderRadius get actionButtonBr => controlBr; // auth/social/primary buttons
  static BorderRadius get surfaceBr => largeBr; // sheets, dialogs, big cards
}

abstract final class AppDimens {
  static const compactHeight = 52.0; // tabs, date/time, compact actions
  static const buttonHeight = 56.0; // primary/social/cancel buttons
  static const controlHeight = 60.0; // inputs, dropdowns, form controls
  static const rowHeight = 64.0; // address rows, car rows
  static const squareButtonSize = 52.0;
  static const routePreviewMapHeight = 224.0;

  static const pagePadding = 16.0;
  static const authPagePadding = 24.0;

  static const gapXs = 4.0;
  static const gapSm = 8.0;
  static const gapMd = 12.0;
  static const gapLg = 16.0;
  static const gapXl = 24.0;
  static const gap2xl = 32.0;

  static const dividerThickness = 1.0;
  static const borderWidth = 1.0;
  static const focusBorderWidth = 1.5;

  static const sheetHandleWidth = 40.0;
  static const sheetHandleHeight = 5.0;

  static const inputCursorHeight = 20.0;
  static const inputCursorWidth = 2.0;

  static const topContentGap = gapSm;
  static const bottomContentGap = gapLg;

  static const bottomBarShadowClearance = 28.0;
}

abstract final class AppText {
  static const appTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const authTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const pageTitle = screenTitle;

  static const modalTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const bodyStrong = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.4,
  );

  static const hint = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
  );

  static const caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const button = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const compactButton = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const metricValue = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const metricValueCompact = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const metricLabel = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const addressTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const addressSubtitle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
  );

  static const listTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const listSubtitle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const sectionDivider = TextStyle(
    color: Color(0x4DFFFFFF), // white 30%
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const badge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const meta = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const link = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const secondaryLink = TextStyle(
    color: AppColors.textMuted,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const inputText = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    height: 1.2,
  );

  static const inputHint = TextStyle(
    color: AppColors.textMuted,
    fontSize: 16,
    height: 1.2,
  );

  static const fieldError = TextStyle(
    color: AppColors.danger,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}

abstract final class AppInsets {
  static const page = EdgeInsets.all(
    AppDimens.pagePadding,
  );

  static const bottomActionContent = EdgeInsets.only(
    left: AppDimens.pagePadding,
    right: AppDimens.pagePadding,
    top: AppDimens.gapLg,
  );

  static const gradientBottomActionContent = EdgeInsets.only(
    left: AppDimens.pagePadding,
    right: AppDimens.pagePadding,
  );
}

abstract final class AppDurations {
  static const fastest = Duration(milliseconds: 150);
  static const fieldState = Duration(milliseconds: 200);
  static const buttonState = Duration(milliseconds: 200);
  static const fast = Duration(milliseconds: 300);
  static const minimumScreenLoading = Duration(milliseconds: 400);
  static const screenCrossFade = Duration(milliseconds: 300);
  static const medium = Duration(milliseconds: 600);
}

abstract final class AppShimmer {
  static const textBorderRadius = AppRadius.full;
  static const textVerticalInset = 2.0;
}
