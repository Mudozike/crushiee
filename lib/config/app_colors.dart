import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFFE91E63);    // Deep Pink
  static const Color secondary = Color(0xFF7E57C2);  // Purple
  static const Color accent = Color(0xFFFF4081);     // Bright Pink

  // Brand Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Background Colors
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color darkBackground = Color(0xFF121212);
  
  static const Color lightSurface = Colors.white;
  static const Color darkSurface = Color(0xFF1E1E1E);

  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF242424);

  // Text Colors
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF757575);
  
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // Status Dots (Facebook Style)
  static const Color online = Color(0xFF4CAF50);       // Green dot
  static const Color activeToday = Color(0xFFFFC107);   // Yellow dot
  static const Color offline = Color(0xFF9E9E9E);       // Grey dot

  // Feature Badges
  static const Color verifiedBlue = Color(0xFF1DA1F2);
  static const Color premiumGold = Color(0xFFFFD700);
  static const Color boostOrange = Color(0xFFFF9800);

  // UI Borders & Dividers
  static const Color lightBorder = Color(0xFFEEEEEE);
  static const Color darkBorder = Color(0xFF2C2C2C);
}
