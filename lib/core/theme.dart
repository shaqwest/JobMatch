import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _zinc950 = Color(0xFF09090B);
const _zinc800 = Color(0xFF27272A);
const _zinc500 = Color(0xFF71717A);
const _zinc200 = Color(0xFFE4E4E7);
const _zinc100 = Color(0xFFF4F4F5);
const _blue600 = Color(0xFF2563EB);
const _white = Color(0xFFFFFFFF);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _white,
    colorScheme: const ColorScheme.light(
      primary: _blue600,
      surface: _white,
      onSurface: _zinc950,
      outline: _zinc200,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: _zinc950,
      displayColor: _zinc950,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _zinc950,
      ),
      iconTheme: const IconThemeData(color: _zinc950),
    ),
    cardTheme: CardThemeData(
      color: _white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _zinc200, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _zinc100,
      side: const BorderSide(color: _zinc200),
      labelStyle: GoogleFonts.inter(fontSize: 12, color: _zinc800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _blue600,
        foregroundColor: _white,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _zinc950,
        side: const BorderSide(color: _zinc200),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _zinc200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _zinc200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _zinc800, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: GoogleFonts.inter(color: _zinc500, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: _zinc500, fontSize: 13),
    ),
    dividerColor: _zinc200,
  );
}
