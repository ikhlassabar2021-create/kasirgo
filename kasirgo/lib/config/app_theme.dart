import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // Design System v3 - "GoPay Merchant Clean UI"
  // ---------------------------------------------------------------------------
  static const Color primaryColor = Color(0xFF00AED6); // GoPay Cyan Blue
  static const Color secondaryColor = Color(0xFF0081A0); // Biru aksen CTA (v3, biru-only)
  static const Color accentColor = Color(0xFF0081A0); // Cyan gelap (aksen)
  static const Color backgroundColor = Color(0xFFF4F5F7); // Background utama
  static const Color surfaceColor = Color(0xFFFFFFFF); // Kartu putih
  static const Color surfaceMutedColor = Color(0xFFF0F2F4);
  static const Color errorColor = Color(0xFFE02424);
  static const Color successColor = Color(0xFF00AA13); // Gojek Green
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFF101820); // Asphalt Black
  static const Color textSecondary = Color(0xFF626E7A);
  static const Color borderColor = Color(0xFFE8ECEF); // Border tipis kartu

  // Tint semantik (latar lembut + border + teks) untuk banner status
  static const Color infoSoftColor = Color(0xFFEFF6FF);
  static const Color infoSoftBorderColor = Color(0xFFBFDBFE);
  static const Color successSoftColor = Color(0xFFF0FDF4);
  static const Color successSoftBorderColor = Color(0xFFBBF7D0);
  static const Color successChipColor = Color(0xFFDCFCE7);
  static const Color successTextColor = Color(0xFF15803D);
  static const Color warningSoftColor = Color(0xFFFEF3C7);
  static const Color warningSoftBorderColor = Color(0xFFFDE68A);
  static const Color warningTextColor = Color(0xFF92400E);
  static const Color violetSoftColor = Color(0xFFF5F3FF);
  static const Color violetSoftBorderColor = Color(0xFFDDD6FE);

  // Aksen warna identitas kartu pintasan modul (dipakai bersama owner/POS)
  static const Color moduleAccentIndigo = Color(0xFF4F46E5);
  static const Color moduleAccentViolet = Color(0xFF7C3AED);
  static const Color moduleAccentTeal = Color(0xFF0D9488);
  static const Color moduleAccentPink = Color(0xFFDB2777);

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF00AA13)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00AED6), Color(0xFF0081A0)],
  );

  static const LinearGradient aiBadgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00AED6), Color(0xFF0081A0)],
  );

  static const Color whatsAppColor = Color(0xFF25D366);
  static const Color qrInkColor = Color(0xFF101820);
  static const Color scrimColor = Color(0x40000000);

  static const double radiusLarge = 16;
  static const double radiusMedium = 12;
  static const double touchTargetLarge = 56;
  static const double touchTargetMedium = 48;

  // Layout responsif terpusat
  static const double breakpointTablet = 600;
  static const double breakpointDesktop = 860;
  static const double sidebarWidth = 240;
  static const double headerHeight = 60;
  static const double contentMaxWidth = 1100;
  static const double formMaxWidth = 760;

  // Animasi terpusat
  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationMedium = Duration(milliseconds: 320);
  static const Duration durationSlow = Duration(milliseconds: 520);
  static const Curve curveDefault = Curves.easeOutCubic;

  // Shadow lembut terpusat
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointTablet;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointTablet && width < breakpointDesktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointDesktop;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 1,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 2,
      ),
    );
  }
}