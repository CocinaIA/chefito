import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de colores
  static const Color background = Color(0xFFFFFFFF); // Blanco
  static const Color primary = Color(0xFFF97316); // Naranja cálido
  static const Color foreground = Color(0xFF09090B); // Gris oscuro/Negro

  // Tonos secundarios derivados
  static const Color primaryLight = Color(0xFFFED7AA); // Naranja más claro
  static const Color primaryDark = Color(0xFFEA580C); // Naranja más oscuro
  static const Color textSecondary = Color(0xFF6B7280); // Gris medio

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: foreground),
      ),
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: background,
        tertiary: primaryLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: foreground,
      ),
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primary,
          iconSize: 24,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryLight,
        disabledColor: Colors.grey.shade200,
        selectedColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(
          color: foreground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: foreground,
        iconColor: primary,
        collapsedIconColor: primary,
        collapsedTextColor: foreground,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: const TextStyle(
        color: foreground,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: const TextStyle(
        color: foreground,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: const TextStyle(
        color: foreground,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: const TextStyle(
        color: foreground,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: const TextStyle(
        color: foreground,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: const TextStyle(
        color: foreground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(
        color: foreground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: const TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: const TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: const TextStyle(
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
