import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  const AppColors._();

  // Background Gradient Colors
  static const Color backgroundTop = Color(0xFF1E1E2C);
  static const Color backgroundBottom = Color(0xFF2D2D44);

  // Splash Specific Colors
  static const Color splashGradientStart = Color(0xFF14142B);
  static const Color splashGradientEnd = Color(0xFF2E1C48);

  // Accent Colors (Pink/Magenta Glow)
  static const Color accentColor = Color(0xFFD500F9); // Vibrant Magenta
  static const Color accentGlow = Color(0xFFEA80FC); // Lighter for glow effects
  static const Color iconPink = Color(0xFFFF66C4);

  // Status Colors
  static const Color successColor = Color(0xFF00E676); // Bright Green for ready
  static const Color successBackground = Color(0x4D2E7D32); // ~30% Green
  static const Color connectingColor = Color(0xFFFFAB40); // Orange/Amber
  static const Color connectingBackground = Color(0x4DAD6400); // ~30% Orange
  static const Color thinkingStatusColor = Color(
    0xFFFFB74D,
  ); // Lighter orange for thinking/waiting

  // Opacity Variants (Pre-calculated strict hex values)
  static const Color accentColorLowOpacity = Color(0x4CD500F9); // ~30%
  static const Color accentColorMediumOpacity = Color(0x7FD500F9); // ~50%
  static const Color accentColorHighOpacity = Color(0x99D500F9); // ~60%

  // Specific UI Colors (avoiding withOpacity)
  static const Color shadowColor = Color(0x7FD500F9); // 50% accent for shadows
  static const Color inputBorderOpacity = Color(0x7F3B2A4F); // 50% of border
  static const Color cardBorder = Color(
    0xFF564A6F,
  ); // Lighter, visible border for cards
  static const Color cardBorderLowOpacity = Color(
    0x80564A6F,
  ); // ~50% opacity of cardBorder

  // UI Elements
  static const Color circleInner = Color(0xFF2B0E44);
  static const Color cardBackground = Color(
    0xFF241830,
  ); // Dark purple card background
  static const Color cardBackgroundMediumOpacity = Color(0x80241830);
  static const Color inputBackground = Color(0xFF1A1225); // Dark input field BG
  static const Color inputBorder = Color(0xFF3B2A4F); // Input border color
  static const Color inputIconColor = Color(0xFF8F88A0); // Input icon color

  // Home Screen Specifics
  static const Color createRoomTint = Color(0x336A1B9A); // ~20% of purple start
  static const Color joinRoomTint = Color(0x331565C0); // ~20% of blue start

  // Home & Dashboard Colors
  static const Color cardGradientStart1 = Color(0xFF4A148C); // Purple Deep
  static const Color cardGradientEnd1 = Color(0xFF7B1FA2); // Purple Light
  static const Color cardGradientStart2 = Color(0xFF1A237E); // Blue Deep
  static const Color cardGradientEnd2 = Color(0xFF283593); // Blue Light
  static const Color notificationBadge = Color(0xFFFF4081);

  // New specific opacities for GameScreen overlays (strict hex)
  static const Color successHighlight = Color(0x332E7D32); // 20% success
  static const Color errorHighlight = Color(0x33FF5252); // 20% red accent
  static const Color avatarBloom = Color(0x99D500F9); // 60% accent
  static const Color whiteLow = Color(0x1AFFFFFF); // 10% white
  static const Color whiteMedium = Color(0x3DFFFFFF); // 24% white
  static const Color greyMedium = Color(0x809E9E9E); // 50% grey

  // Components (Slider, Toggle)
  static const Color sliderTrackInactive = Color(0xFF3E3E55);
  static const Color sliderThumb = Colors.white;
  static const Color toggleActive = Color(0xFFD500F9);
  static const Color toggleInactive = Color(0xFF3E3E55);

  // Text Colors
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFFB0B0C3);
  static const Color textGreyLowOpacity = Color(0x7FB0B0C3);
  static const Color hintText = Color(0x7FB0B0C3); // 50% text grey

  // Quiz Screen Specifics
  static const Color liveMatchBadge = Color(0xFF2C1E3D);
  static const Color headerPillBackground = Color(0xFF241830);
  static const Color questionTopicBadge = Color(
    0xFF880E4F,
  ); // Darker Magenta/Pink
  static const Color optionSelectedTint = Color(0x33D500F9); // ~20% Accent
  static const Color optionUnselected = Color(0xFF241830);
  static const Color optionIndexCircle = Color(0xFF3E3E55);
  static const Color questionCardGradientStart = Color(0xFF2E1C48);
  static const Color questionCardGradientEnd = Color(0xFF14142B);

  // Progress Bar
  static const Color progressBackground = Color(0xFF3E3E55);
  static const Color progressFill = Color(0xFFD500F9);
}
