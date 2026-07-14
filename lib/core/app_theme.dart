import 'package:flutter/material.dart';

/// Tema global — AURA VITAE / PymeSync Skincare CRM.
///
/// Paleta "Warm Neutral Clean Beauty":
///   Merlot  #5E3F44  → primario, botones, nav activo
///   Cocoa   #3E3333  → foreground, texto, títulos
///   Mauve   #A47E82  → secundario, íconos, labels
///   Peony   #E6CECE  → chips, hover, badges suaves
///   Almond  #F0E7E2  → fondo general, inputs, thumbnails
///   White   #FFFFFF  → cards, sidebar, paneles
class AppTheme {
  AppTheme._();

  // ── Paleta principal ──────────────────────────────────────────────
  static const Color merlot  = Color(0xFF5E3F44); // --primary
  static const Color cocoa   = Color(0xFF3E3333); // --foreground
  static const Color mauve   = Color(0xFFA47E82); // --accent
  static const Color peony   = Color(0xFFE6CECE); // --secondary
  static const Color almond  = Color(0xFFF0E7E2); // --background
  static const Color card    = Color(0xFFFFFFFF); // --card

  // ── Semánticos ────────────────────────────────────────────────────
  static const Color success = Color(0xFF4A7A4A);
  static const Color warning = Color(0xFFA47E82); // Mauve como warning suave
  static const Color danger  = Color(0xFFC0504F);

  // ── Tier badges ───────────────────────────────────────────────────
  static const Color tierGoldBg     = Color(0xFFF5E6C8);
  static const Color tierGoldText   = Color(0xFF8B6914);
  static const Color tierSilverBg   = Color(0xFFE8E5E0);
  static const Color tierSilverText = Color(0xFF6B6460);

  // ── Aliases de compatibilidad (usado en widgets existentes) ───────
  static const Color brandNavy = merlot;
  static const Color brandBlue = mauve;

  // ── Border / ring ─────────────────────────────────────────────────
  static const Color borderColor  = Color(0x173E3333); // rgba(62,51,51,0.09)
  static const Color ringColor    = Color(0x4D5E3F44); // rgba(94,63,68,0.30)

  static ThemeData light() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      // Primarios
      primary: merlot,
      onPrimary: Colors.white,
      primaryContainer: peony,
      onPrimaryContainer: cocoa,
      // Secundarios
      secondary: mauve,
      onSecondary: Colors.white,
      secondaryContainer: peony,
      onSecondaryContainer: cocoa,
      // Terciarios
      tertiary: const Color(0xFF7A5560),
      onTertiary: Colors.white,
      tertiaryContainer: almond,
      onTertiaryContainer: cocoa,
      // Error
      error: danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFDE8E8),
      onErrorContainer: danger,
      // Surface
      surface: card,
      onSurface: cocoa,
      surfaceContainerHighest: almond,
      onSurfaceVariant: mauve,
      // Outline
      outline: borderColor,
      outlineVariant: borderColor,
      // Inversas
      inverseSurface: cocoa,
      onInverseSurface: Colors.white,
      inversePrimary: peony,
      // Shadow / scrim
      shadow: Color(0x0F3E3333),
      scrim: Color(0x663E3333),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: almond,

      // ── Tipografía — Montserrat (brand) + Inter (body) ─────────
      // Flutter web carga las fuentes declaradas en pubspec.yaml;
      // usamos los nombres exactos de Google Fonts.
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        // displayLarge / headlineLarge → títulos de página (Montserrat 800)
        displayLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: 0.02,
          color: cocoa,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 26,
          color: cocoa,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: 0.10,
          color: cocoa,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: cocoa,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: cocoa,
        ),
        // titleLarge → AppBar title
        titleLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.08,
          color: cocoa,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: cocoa,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.06,
          color: cocoa,
        ),
        // bodyLarge → párrafos principales (Inter)
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: cocoa,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: cocoa,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 11,
          color: mauve,
        ),
        // labelLarge → botones (Montserrat uppercase)
        labelLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.12,
          color: Colors.white,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 0.10,
          color: mauve,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 10,
          color: mauve,
        ),
      ),

      // ── AppBar ─────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: cocoa,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: borderColor,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.08,
          color: cocoa,
        ),
        iconTheme: IconThemeData(color: mauve),
        actionsIconTheme: IconThemeData(color: mauve),
      ),

      // ── Cards ──────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        shadowColor: Color(0x0F3E3333),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Inputs ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: almond,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: mauve,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: mauve,
          fontSize: 13,
        ),
        prefixIconColor: mauve,
        suffixIconColor: mauve,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: merlot, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ── FilledButton (primario) ────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: merlot,
          foregroundColor: Colors.white,
          disabledBackgroundColor: peony,
          disabledForegroundColor: mauve,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.12,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? Colors.white.withValues(alpha: 0.13)
                : null,
          ),
        ),
      ),

      // ── OutlinedButton (secundario) ────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: merlot,
          side: const BorderSide(color: merlot, width: 1.5),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.10,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? const Color(0x59E6CECE) // rgba(230,206,206,0.35)
                : null,
          ),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: merlot,
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.06,
          ),
        ),
      ),

      // ── NavigationBar (mobile) ─────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shadowColor: borderColor,
        elevation: 1,
        indicatorColor: peony,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? merlot : mauve,
            size: 22,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 9,
            letterSpacing: 0.08,
            color: states.contains(WidgetState.selected) ? merlot : mauve,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── NavigationRail (tablet / desktop) ──────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        elevation: 0,
        indicatorColor: peony,
        selectedIconTheme: const IconThemeData(color: merlot, size: 22),
        unselectedIconTheme: const IconThemeData(color: mauve, size: 22),
        selectedLabelTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.08,
          color: merlot,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 0.06,
          color: mauve,
        ),
      ),

      // ── Divider ────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: borderColor),

      // ── SnackBar ───────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: cocoa,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 13,
        ),
      ),

      // ── Chips ──────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: peony,
        labelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.08,
          color: merlot,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── Dialog ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 0.06,
          color: cocoa,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: mauve,
        ),
      ),

      // ── Progress indicator ─────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: merlot,
        linearTrackColor: peony,
      ),

      // ── Switch ─────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? merlot : mauve,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? peony : borderColor,
        ),
      ),

      // ── FloatingActionButton ───────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: merlot,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}

/// Formatea cantidades como moneda ($1,234.50) sin depender de intl.
String formatCurrency(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
  }
  return '${negative ? '-' : ''}\$$buffer.${parts[1]}';
}

/// Formatea fechas como dd/mm/aaaa hh:mm.
String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
