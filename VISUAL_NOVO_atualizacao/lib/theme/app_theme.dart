import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Paleta de cores oficial — Redesign Visual Compras Inteligentes
  static const Color primaryDarkGreen = Color(0xFF245C46);
  static const Color accentGreen = Color(0xFF387653);
  static const Color lightGreen = Color(0xFFE7F0E6);
  static const Color creamBackground = Color(0xFFFAF7F0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color lightWood = Color(0xFFD8B895);
  static const Color softOrange = Color(0xFFE99A52);
  static const Color primaryText = Color(0xFF292D2A);
  static const Color secondaryText = Color(0xFF747A75);
  static const Color subtleBorder = Color(0xFFE5E0D7);
  static const Color alertRed = Color(0xFFC94C4C);

  static const String bannerAsset = 'assets/images/supermarket_banner.jpg';

  static BoxDecoration cardDecoration({
    Color color = cardWhite,
    Color borderColor = subtleBorder,
    double radius = 16,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: withShadow
          ? const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ]
          : null,
    );
  }

  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryDarkGreen,
      brightness: Brightness.light,
      primary: primaryDarkGreen,
      onPrimary: cardWhite,
      secondary: accentGreen,
      onSecondary: cardWhite,
      primaryContainer: lightGreen,
      onPrimaryContainer: primaryDarkGreen,
      surface: cardWhite,
      onSurface: primaryText,
      error: alertRed,
      onError: cardWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: creamBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: creamBackground,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: primaryDarkGreen),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDarkGreen,
          foregroundColor: cardWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: cardWhite,
          foregroundColor: primaryDarkGreen,
          side: const BorderSide(color: primaryDarkGreen, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDarkGreen,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryDarkGreen, width: 1.6),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: secondaryText, width: 1.5),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: cardWhite,
        surfaceTintColor: Colors.transparent,
        indicatorColor: lightGreen,
        elevation: 4,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDarkGreen,
        foregroundColor: cardWhite,
      ),
      dividerTheme: const DividerThemeData(
        color: subtleBorder,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDarkGreen,
        contentTextStyle: const TextStyle(color: cardWhite, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
