import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Shared text styles so the brand wordmark, taglines, and links look and
/// behave identically everywhere they appear, instead of each screen
/// picking its own font/size/weight.
class AppTextStyles {
  AppTextStyles._();

  /// The "Kafelo" brand wordmark — always this script font, everywhere
  /// it's used, so the brand identity stays instantly recognizable
  /// whether it's on a dark photo background or a white page.
  static TextStyle wordmark({required double fontSize, required Color color}) {
    return GoogleFonts.pacifico(
      color: color,
      fontSize: fontSize,
      height: 1.1,
    );
  }

  static TextStyle heading({required double fontSize, required Color color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle tagline({required double fontSize, required Color color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: color,
    );
  }

  /// The small "Already have an account? Sign in" / "Don't have an
  /// account? Sign Up" pattern — same weight, size, and treatment
  /// wherever it shows up.
  static TextStyle bodyMuted({required double fontSize, required Color color}) {
    return TextStyle(fontSize: fontSize, color: color);
  }

  static TextStyle linkAccent({required double fontSize}) {
    return const TextStyle(
      color: AppColors.primaryBrown,
      fontWeight: FontWeight.bold,
    ).copyWith(fontSize: fontSize);
  }
}