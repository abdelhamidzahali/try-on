import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ChromaStyle brand colors
// Light mode emphasizes Electric Blue; Dark mode switches primary to Deep Magenta.
class LightModeColors {
  // Accents
  static const lightPrimary = Color(0xFFEA4C89); // Fashion Fuchsia
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightSecondary = Color(0xFFC8A46B); // Champagne Gold
  static const lightOnSecondary = Color(0xFF111318);
  static const lightTertiary = Color(0xFF7C3AED); // Electric Violet
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Surfaces & content
  static const lightSurface = Color(0xFFFAFAF7); // Soft ivory
  static const lightOnSurface = Color(0xFF111318); // Deep ink for readability
  static const lightAppBarBackground = Color(0xFFFFFFFF);
  static const lightCardBackground = Color(0xFFF5F5F1);
  static const lightBorder = Color(0xFFE7E4DE);

  // Error
  static const lightError = Color(0xFFEF4444);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFEE2E2);
  static const lightOnErrorContainer = Color(0xFF7F1D1D);

  // Misc
  static const lightPrimaryContainer = Color(0xFFFFE3EE);
  static const lightOnPrimaryContainer = Color(0xFF5A1635);
  static const lightInversePrimary = Color(0xFFFF9DC3);
  static const lightShadow = Color(0xFF000000);
}

class DarkModeColors {
  // Accents (Deep Magenta primary in dark)
  static const darkPrimary = Color(0xFFEA4C89); // Fashion Fuchsia
  static const darkOnPrimary = Color(0xFFFFFFFF);
  static const darkSecondary = Color(0xFFDAB982); // Warmer champagne
  static const darkOnSecondary = Color(0xFF0E0F14);
  static const darkTertiary = Color(0xFF8B5CF6); // Violet glow
  static const darkOnTertiary = Color(0xFF0C0D12);

  // Surfaces & content
  static const darkSurface = Color(0xFF0B0C10); // Deep charcoal
  static const darkOnSurface = Color(0xFFEAE6E1);
  static const darkAppBarBackground = Color(0xFF0B0C10);
  static const darkCardBackground = Color(0xFF121317);
  static const darkBorder = Color(0xFF2A2B31);

  // Error
  static const darkError = Color(0xFFF87171);
  static const darkOnError = Color(0xFF1E293B);
  static const darkErrorContainer = Color(0xFF7F1D1D);
  static const darkOnErrorContainer = Color(0xFFFEE2E2);

  // Misc
  static const darkPrimaryContainer = Color(0xFF3D0F28);
  static const darkOnPrimaryContainer = Color(0xFFFFC3D9);
  static const darkInversePrimary = Color(0xFFFFA8CF);
  static const darkShadow = Color(0xFF000000);
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// Theme extension to expose Chroma-style gradients and shared radii
class ChromaTheme extends ThemeExtension<ChromaTheme> {
  final Gradient primaryGradient;
  final Gradient accentGradient;
  final Color secondaryAccent;
  final BorderRadius cardRadius;
  final BorderRadius controlRadius;

  const ChromaTheme({
    required this.primaryGradient,
    required this.accentGradient,
    required this.secondaryAccent,
    required this.cardRadius,
    required this.controlRadius,
  });

  @override
  ChromaTheme copyWith({
    Gradient? primaryGradient,
    Gradient? accentGradient,
    Color? secondaryAccent,
    BorderRadius? cardRadius,
    BorderRadius? controlRadius,
  }) {
    return ChromaTheme(
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
    );
  }

  @override
  ThemeExtension<ChromaTheme> lerp(ThemeExtension<ChromaTheme>? other, double t) {
    if (other is! ChromaTheme) return this;
    return ChromaTheme(
      primaryGradient: LinearGradient(
        colors: [
          Color.lerp((primaryGradient as LinearGradient).colors.first,
              (other.primaryGradient as LinearGradient).colors.first, t)!,
          Color.lerp((primaryGradient as LinearGradient).colors.last,
              (other.primaryGradient as LinearGradient).colors.last, t)!,
        ],
      ),
      accentGradient: LinearGradient(
        colors: [
          Color.lerp((accentGradient as LinearGradient).colors.first,
              (other.accentGradient as LinearGradient).colors.first, t)!,
          Color.lerp((accentGradient as LinearGradient).colors.last,
              (other.accentGradient as LinearGradient).colors.last, t)!,
        ],
      ),
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      cardRadius: BorderRadius.lerp(cardRadius, other.cardRadius, t)!,
      controlRadius: BorderRadius.lerp(controlRadius, other.controlRadius, t)!,
    );
  }
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    inversePrimary: LightModeColors.lightInversePrimary,
    shadow: LightModeColors.lightShadow,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
  ),
  brightness: Brightness.light,
  appBarTheme: AppBarTheme(
    backgroundColor: LightModeColors.lightAppBarBackground,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      // Enforce Helvetica Neue for app bar titles
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
  ),
  cardTheme: CardThemeData(
    color: LightModeColors.lightCardBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: LightModeColors.lightBorder, width: 1),
    ),
  ),
  iconTheme: const IconThemeData(color: LightModeColors.lightOnSurface, size: 22),
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
  }),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: LightModeColors.lightPrimary,
      foregroundColor: LightModeColors.lightOnPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.lightOnSurface,
      side: BorderSide(color: LightModeColors.lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: LightModeColors.lightTertiary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightCardBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LightModeColors.lightBorder, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 1.4),
    ),
    labelStyle: const TextStyle(color: Color(0xFF5B5A57)),
    hintStyle: const TextStyle(color: Color(0xFF8C8A86)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    backgroundColor: LightModeColors.lightSurface,
    selectedItemColor: LightModeColors.lightPrimary,
    unselectedItemColor: Color(0xFF9A958C),
    selectedIconTheme: IconThemeData(color: LightModeColors.lightPrimary),
    unselectedIconTheme: IconThemeData(color: Color(0xFF9A958C)),
    showUnselectedLabels: true,
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Color(0xFF111318),
    contentTextStyle: TextStyle(color: Colors.white),
    actionTextColor: Colors.white,
  ),
  textTheme: TextTheme(
    // Headlines keep editorial vibe
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w700,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    // Titles switch to Helvetica Neue
    titleLarge: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
    ),
    titleSmall: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
    // Labels & body use Inter for contemporary readability
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
  ),
  extensions: <ThemeExtension<dynamic>>[
    const ChromaTheme(
      primaryGradient: LinearGradient(
        colors: [Color(0xFFEA4C89), Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGradient: LinearGradient(
        colors: [Color(0xFFC8A46B), Color(0xFFFFE5C0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      secondaryAccent: Color(0xFFC8A46B),
      cardRadius: BorderRadius.all(Radius.circular(16)),
      controlRadius: BorderRadius.all(Radius.circular(14)),
    ),
  ],
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    inversePrimary: DarkModeColors.darkInversePrimary,
    shadow: DarkModeColors.darkShadow,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
  ),
  brightness: Brightness.dark,
  appBarTheme: AppBarTheme(
    backgroundColor: DarkModeColors.darkAppBarBackground,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
  ),
  cardTheme: CardThemeData(
    color: DarkModeColors.darkCardBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: DarkModeColors.darkBorder, width: 1),
    ),
  ),
  iconTheme: const IconThemeData(color: DarkModeColors.darkOnSurface, size: 22),
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
  }),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkModeColors.darkPrimary,
      foregroundColor: DarkModeColors.darkOnPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.darkOnSurface,
      side: BorderSide(color: DarkModeColors.darkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: DarkModeColors.darkTertiary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkCardBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: DarkModeColors.darkBorder, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 1.4),
    ),
    labelStyle: const TextStyle(color: Color(0xFFB6B1AA)),
    hintStyle: const TextStyle(color: Color(0xFF908C85)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    backgroundColor: DarkModeColors.darkSurface,
    selectedItemColor: DarkModeColors.darkPrimary,
    unselectedItemColor: Color(0xFF9A9AA3),
    selectedIconTheme: IconThemeData(color: DarkModeColors.darkPrimary),
    unselectedIconTheme: IconThemeData(color: Color(0xFF9A9AA3)),
    showUnselectedLabels: true,
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Color(0xFF0E0F14),
    contentTextStyle: TextStyle(color: Colors.white),
    actionTextColor: Colors.white,
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w700,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
    ),
    titleSmall: const TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
  ),
  extensions: <ThemeExtension<dynamic>>[
    const ChromaTheme(
      primaryGradient: LinearGradient(
        colors: [Color(0xFFEA4C89), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGradient: LinearGradient(
        colors: [Color(0xFFDAB982), Color(0xFFFFE8C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      secondaryAccent: Color(0xFFDAB982),
      cardRadius: BorderRadius.all(Radius.circular(16)),
      controlRadius: BorderRadius.all(Radius.circular(14)),
    ),
  ],
);
