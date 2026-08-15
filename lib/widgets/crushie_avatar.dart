import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CrushieAvatar extends StatelessWidget {
  final int index;
  final double radius;
  final bool isSelected;

  const CrushieAvatar({
    Key? key,
    required this.index,
    this.radius = 32,
    this.isSelected = false,
  }) : super(key: key);

  static const List<Map<String, dynamic>> avatarPresets = [
    {
      'name': 'Sweet Heart',
      'colors': [Color(0xFFE91E63), Color(0xFFFF4081)],
      'accent': Colors.pinkAccent,
      'expression': 'smile',
    },
    {
      'name': 'Electric Crush',
      'colors': [Color(0xFF7E57C2), Color(0xFF9C27B0)],
      'accent': Colors.deepPurpleAccent,
      'expression': 'cool',
    },
    {
      'name': 'Ocean Vibe',
      'colors': [Color(0xFF1DA1F2), Color(0xFF00BCD4)],
      'accent': Colors.lightBlueAccent,
      'expression': 'wink',
    },
    {
      'name': 'Sunset Star',
      'colors': [Color(0xFFFF9800), Color(0xFFFF5722)],
      'accent': Colors.amberAccent,
      'expression': 'star',
    },
    {
      'name': 'Neon Glow',
      'colors': [Color(0xFF00E5FF), Color(0xFF00E676)],
      'accent': Colors.cyanAccent,
      'expression': 'joy',
    },
    {
      'name': 'Cupid Love',
      'colors': [Color(0xFFFF4081), Color(0xFFE91E63)],
      'accent': Colors.pink,
      'expression': 'blush',
    },
    {
      'name': 'Vibe King',
      'colors': [Color(0xFF5E35B1), Color(0xFF3F51B5)],
      'accent': Colors.indigoAccent,
      'expression': 'crown',
    },
    {
      'name': 'Emerald Charm',
      'colors': [Color(0xFF00E676), Color(0xFF1DE9B6)],
      'accent': Colors.tealAccent,
      'expression': 'headphones',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final preset = avatarPresets[index % avatarPresets.length];
    final List<Color> colors = List<Color>.from(preset['colors']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.all(isSelected ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: AppColors.primary, width: 3.5) : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _CrushieMascotPainter(
              expression: preset['expression'] as String,
              accentColor: preset['accent'] as Color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrushieMascotPainter extends CustomPainter {
  final String expression;
  final Color accentColor;

  _CrushieMascotPainter({
    required this.expression,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // 1. Draw Heart Antenna on top of head
    final antennaPath = Path();
    final antennaTop = Offset(center.dx, center.dy - r * 0.58);
    antennaPath.moveTo(center.dx, center.dy - r * 0.35);
    antennaPath.lineTo(antennaTop.dx, antennaTop.dy);
    
    final stemPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = r * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(antennaPath, stemPaint);

    // Heart badge at top of antenna
    final heartSize = r * 0.22;
    final heartPath = Path();
    final hx = antennaTop.dx;
    final hy = antennaTop.dy - heartSize * 0.3;
    heartPath.moveTo(hx, hy + heartSize * 0.35);
    heartPath.cubicTo(
      hx - heartSize * 0.6, hy - heartSize * 0.4,
      hx - heartSize * 0.9, hy + heartSize * 0.5,
      hx, hy + heartSize,
    );
    heartPath.cubicTo(
      hx + heartSize * 0.9, hy + heartSize * 0.5,
      hx + heartSize * 0.6, hy - heartSize * 0.4,
      hx, hy + heartSize * 0.35,
    );
    canvas.drawPath(heartPath, Paint()..color = Colors.white);

    // 2. Cute Mascot Eyes
    final eyePaint = Paint()..color = Colors.white;

    if (expression == 'cool') {
      // Sunglasses
      final glassPaint = Paint()..color = const Color(0xFF1E1E1E);
      final rRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx - r * 0.25, center.dy - r * 0.05), width: r * 0.38, height: r * 0.24),
        Radius.circular(r * 0.08),
      );
      final rRect2 = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx + r * 0.25, center.dy - r * 0.05), width: r * 0.38, height: r * 0.24),
        Radius.circular(r * 0.08),
      );
      canvas.drawRRect(rRect, glassPaint);
      canvas.drawRRect(rRect2, glassPaint);
      canvas.drawLine(
        Offset(center.dx - r * 0.1, center.dy - r * 0.05),
        Offset(center.dx + r * 0.1, center.dy - r * 0.05),
        glassPaint..strokeWidth = r * 0.06,
      );
    } else if (expression == 'wink') {
      // Left eye open, right eye wink
      canvas.drawCircle(Offset(center.dx - r * 0.25, center.dy - r * 0.05), r * 0.12, eyePaint);
      final winkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round;
      final winkPath = Path();
      winkPath.moveTo(center.dx + r * 0.14, center.dy - r * 0.05);
      winkPath.quadraticBezierTo(center.dx + r * 0.25, center.dy - r * 0.12, center.dx + r * 0.36, center.dy - r * 0.05);
      canvas.drawPath(winkPath, winkPaint);
    } else {
      // Standard Big Sparkle Eyes
      canvas.drawCircle(Offset(center.dx - r * 0.24, center.dy - r * 0.05), r * 0.13, eyePaint);
      canvas.drawCircle(Offset(center.dx + r * 0.24, center.dy - r * 0.05), r * 0.13, eyePaint);
      
      // Pupil sparkles
      final pupilPaint = Paint()..color = const Color(0xFF1E1E1E);
      canvas.drawCircle(Offset(center.dx - r * 0.22, center.dy - r * 0.04), r * 0.07, pupilPaint);
      canvas.drawCircle(Offset(center.dx + r * 0.26, center.dy - r * 0.04), r * 0.07, pupilPaint);
    }

    // 3. Cute Cheek Blush
    final blushPaint = Paint()..color = Colors.white.withOpacity(0.35);
    canvas.drawCircle(Offset(center.dx - r * 0.38, center.dy + r * 0.12), r * 0.09, blushPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.38, center.dy + r * 0.12), r * 0.09, blushPaint);

    // 4. Smile Mouth
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;

    final smilePath = Path();
    smilePath.moveTo(center.dx - r * 0.18, center.dy + r * 0.18);
    smilePath.quadraticBezierTo(center.dx, center.dy + r * 0.36, center.dx + r * 0.18, center.dy + r * 0.18);
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
