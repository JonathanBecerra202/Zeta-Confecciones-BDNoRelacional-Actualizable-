import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta tomada del mockup móvil.
class Z {
  static const brand = Color(0xFF6BB3DE);
  static const brandDark = Color(0xFF368FC5);
  static const ink = Color(0xFF203B55);
  static const body = Color(0xFF536B7D);
  static const muted = Color(0xFF8CA4B5);
  static const soft = Color(0xFFEAF6FD);
  static const border = Color(0xFFD6EAF5);
  static const rose = Color(0xFFE0507A);
  static const roseSoft = Color(0xFFFFF0F4);
  static const bg = Color(0xFFF8FCFF);
  static const amber = Color(0xFFCF8A1D);
  static const amberSoft = Color(0xFFFFF6E6);
  static const green = Color(0xFF2E9B63);
  static const greenSoft = Color(0xFFEAF8F0);
  static const blueSoft = Color(0xFFE8F5FC);
  static const arrow = Color(0xFFB2C5D1);
}

TextStyle display(double size, {Color color = Z.ink}) => GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.15,
    );

TextStyle nunito(double size,
        {FontWeight weight = FontWeight.w600, Color color = Z.body, double? height}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color, height: height);

OutlineInputBorder _border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Z.brand,
      primary: Z.brandDark,
      surface: Z.bg,
    ),
    scaffoldBackgroundColor: Z.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme)
        .apply(bodyColor: Z.body, displayColor: Z.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: nunito(14, color: Z.muted),
      border: _border(Z.border),
      enabledBorder: _border(Z.border),
      focusedBorder: _border(Z.brandDark),
      errorBorder: _border(Z.rose),
      focusedErrorBorder: _border(Z.rose),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Z.ink,
      contentTextStyle: nunito(13, weight: FontWeight.w700, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
