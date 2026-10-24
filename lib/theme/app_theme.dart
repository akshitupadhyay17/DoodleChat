import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color duckYellow = Color(0xFFFFC72C);
  static const Color duckYellowDark = Color(0xFFE5A800);
  static const Color duckBeak = Color(0xFFFF6B35);
  static const Color doodlePurple = Color(0xFF6C5CE7);
  static const Color doodlePink = Color(0xFFFF4081);
  static const Color doodleCyan = Color(0xFF00CEC9);
  static const Color doodleGreen = Color(0xFF00B894);

  // Palette choices for drawing
  static const List<Color> doodleColors = [
    Color(0xFFFFC72C), // Yellow
    Color(0xFFFF4081), // Pink
    Color(0xFF00CEC9), // Cyan
    Color(0xFF00B894), // Lime Green
    Color(0xFF6C5CE7), // Purple
    Color(0xFFFF7675), // Coral
    Color(0xFFFFFFFF), // White
    Color(0xFF1E1E26), // Charcoal
  ];

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFAF8F2),
    colorScheme: const ColorScheme.light(
      primary: duckYellow,
      secondary: duckBeak,
      surface: Colors.white,
      onPrimary: Colors.black,
      onSurface: Color(0xFF1E1E26),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAF8F2),
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFF1E1E26)),
      titleTextStyle: TextStyle(
        color: Color(0xFF1E1E26),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: GoogleFonts.outfitTextTheme(),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF111116),
    colorScheme: const ColorScheme.dark(
      primary: duckYellow,
      secondary: duckBeak,
      surface: Color(0xFF1A1A22),
      onPrimary: Colors.black,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111116),
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: GoogleFonts.outfitTextTheme().apply(bodyColor: Colors.white, displayColor: Colors.white),
  );
}
