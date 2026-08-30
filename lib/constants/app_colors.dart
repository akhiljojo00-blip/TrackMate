import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color accent = Color(0xFF00ACC1);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);

  // Midnight Sapphire & Solar Gold Tokens
  static const Color midnightBackground = Color(0xFF070D18);
  static const Color glassSurface = Color(0xD90F1B2B); // 85% opacity
  static const Color glassBorder = Color(0x331E88E5); // 20% opacity
  static const Color sapphireGlow = Color(0xFF64B5F6);
  static const Color solarGold = Color(0xFFFFD54F);
  static const Color broadcastLive = Color(0xFF00E676);
  static const Color broadcastBlurred = Color(0xFFFFA000);
  static const Color revocationCrimson = Color(0xFFFF1744);

  // Light Mode Tokens
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color cardBorder = Color(0xFFE0E0E0);
  static const Color inputFill = Color(0xFFF0F2F5);

  // Dark Mode Tokens
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF252525);
  static const Color darkCardBorder = Color(0xFF333333);
  static const Color darkTextPrimary = Color(0xFFEDEDED);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkInputFill = Color(0xFF2A2A2A);

  // Dynamic Theme Helpers
  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : surface;

  static Color cardBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCardBorder : cardBorder;

  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : background;

  static Color textPrimaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color inputFillColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkInputFill : inputFill;
}
