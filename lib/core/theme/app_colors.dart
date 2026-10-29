import 'package:flutter/material.dart';

/**
 * ResQAI Design System Color Tokens
 * Standardized Red Accent + Emerald Brand Palette (Zero Pink / Unified Theme)
 */
class AppColors {
  // ==========================================================================
  // 1. Standard Red Tonal Scale (Danger / Primary Action / SOS Accent)
  // ==========================================================================
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red300 = Color(0xFFFCA5A5);
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);  // Canonical Danger & SOS Red
  static const Color red600 = Color(0xFFDC2626);  // Bold Primary Action Red
  static const Color red700 = Color(0xFFB91C1C);
  static const Color red800 = Color(0xFF991B1B);
  static const Color red900 = Color(0xFF7F1D1D);

  static const Color primaryRed = red600;
  static const Color dangerRed = red500;
  static const Color emergencyRed = red600;

  // ==========================================================================
  // 2. Standard Emerald Green Tonal Scale (Safe / Success / Verification)
  // ==========================================================================
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669); // Canonical Emerald Primary
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color emerald900 = Color(0xFF064E3B);

  static const Color primaryGreen = emerald600;
  static const Color emeraldGreen = emerald500;
  static const Color mintGreen = emerald400;
  static const Color lightGreen = emerald50;
  static const Color deepGreen = emerald900;

  // ==========================================================================
  // 3. Dark Theme Tokens (WCAG AA Compliant Surface & Text)
  // ==========================================================================
  static const Color darkBg = Color(0xFF071A14);
  static const Color darkSurface = Color(0xFF0F2820);
  static const Color darkSurface2 = Color(0xFF16382C);
  static const Color darkSurfaceElevated = Color(0xFF16382C);
  static const Color darkSurfaceCard = Color(0xFF0F2820);
  static const Color darkBorder = Color(0xFF1F4A3B);
  static const Color darkText = Color(0xFFF0FDF4);
  static const Color darkTextPrimary = Color(0xFFF0FDF4);
  static const Color darkTextMuted = Color(0xFF94BAA8);
  static const Color darkTextSecondary = Color(0xFF94BAA8);
  static const Color darkPrimary = emerald500;
  static const Color darkSuccess = emerald400;
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkDanger = red500;
  static const Color darkMl = red500;

  // ==========================================================================
  // 4. Light Theme Tokens (Crisp Clean Canvas & High Contrast)
  // ==========================================================================
  static const Color lightBg = Color(0xFFF6FAF7);
  static const Color lightBackground = Color(0xFFF6FAF7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0FDF4);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F2419);
  static const Color lightTextPrimary = Color(0xFF0F2419);
  static const Color lightTextMuted = Color(0xFF4B6358);
  static const Color lightTextSecondary = Color(0xFF4B6358);
  static const Color lightPrimary = emerald600;
  static const Color lightSuccess = emerald500;
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightDanger = red600;
  static const Color lightMl = red600;
  static const Color lightPink = red500; // Routed to red

  // ==========================================================================
  // 5. Canonical Semantic Colors
  // ==========================================================================
  static const Color emergencyPink = red600; // Routed to red
  static const Color successGreen = emerald500;
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color mlPurple = red600; // Routed to red
  static const Color deepNavy = Color(0xFF0F2419);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF0F2419);
  static const Color mutedText = Color(0xFF4B6358);

  // Backward-compatibility aliases
  static const Color primaryBlue = emerald600;
  static const Color realBlue = Color(0xFF2563EB);
  static const Color primary = primaryGreen;
  static const Color primaryDark = emerald700;
  static const Color primaryLight = emerald400;
  static const Color accent = red600;
  static const Color criticalRed = red600;
  static const Color warningAmber = warningOrange;
  static const Color verifiedGreen = successGreen;
  static const Color infoBlue = emerald600;
  static const Color unverifiedPurple = red600;
  static const Color darkBackground = darkBg;
  static const Color navyBlue = deepGreen;

  // Pink aliases mapped strictly to Red tonal scale
  static const Color primaryPink = red500;
  static const Color brightPink = red600;
  static const Color deepPink = red700;
  static const Color softPink = red50;
  static const Color magenta = red600;
  static const Color neonPink = red500;

  // ==========================================================================
  // 6. Premium Red & Green Gradients (Zero Pink)
  // ==========================================================================
  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenRedGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Gradient aliases mapped to Red
  static const LinearGradient pinkGradient = redGradient;
  static const LinearGradient greenPinkGradient = greenRedGradient;
}
