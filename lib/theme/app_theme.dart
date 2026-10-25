import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Neon & Vibrant Accents (Gen-Z & iOS Aesthetic)
  static const Color electricPink = Color(0xFFFF2D55);
  static const Color cyberViolet = Color(0xFF7B61FF);
  static const Color neonYellow = Color(0xFFFFD600);
  static const Color sunsetOrange = Color(0xFFFF5E3A);
  static const Color electricCyan = Color(0xFF00F0FF);
  static const Color acidLime = Color(0xFF00E676);

  // Backward-compatible aliases
  static const Color duckYellow = neonYellow;
  static const Color duckYellowDark = Color(0xFFE5B800);
  static const Color duckBeak = sunsetOrange;
  static const Color doodlePurple = cyberViolet;
  static const Color doodlePink = electricPink;
  static const Color doodleCyan = electricCyan;
  static const Color doodleGreen = acidLime;

  // Dark Mode Surface Architecture
  static const Color darkBackground = Color(0xFF090A0E);
  static const Color darkCard = Color(0xFF14151F);
  static const Color darkSurface = Color(0xFF1A1C29);
  static const Color darkBorder = Color(0xFF272A3D);

  // Light Mode Surface Architecture
  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFEEF0F8);
  static const Color lightBorder = Color(0xFFE2E4EE);

  // Rich Drawing Palette for Creative Doodling
  static const List<Color> doodleColors = [
    Color(0xFFFFD600), // Neon Yellow
    Color(0xFFFF2D55), // Hot Pink
    Color(0xFFFF5E3A), // Sunset Coral
    Color(0xFF00F0FF), // Electric Cyan
    Color(0xFF00E676), // Acid Lime
    Color(0xFF7B61FF), // Cyber Violet
    Color(0xFFB026FF), // Magenta
    Color(0xFF007AFF), // iOS Blue
    Color(0xFFFFFFFF), // Chalk White
    Color(0xFF16171E), // Ink Obsidian
  ];

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: electricPink,
      secondary: cyberViolet,
      surface: lightCard,
      onPrimary: Colors.white,
      onSurface: Color(0xFF0E1017),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF0E1017)),
      titleTextStyle: TextStyle(
        color: Color(0xFF0E1017),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: const Color(0xFF0E1017),
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: const Color(0xFF0E1017),
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: const Color(0xFF0E1017),
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: const Color(0xFF4A4E61),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: electricPink,
      secondary: cyberViolet,
      surface: darkCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: Colors.white,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: const Color(0xFFA6ABBD),
      ),
    ),
  );
}
