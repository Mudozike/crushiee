import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const GoogleSignInButton({
    Key? key,
    required this.onPressed,
    this.text = 'Continue with Google',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          side: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFDADCE0),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Official Google 4-Color G Logo Widget
            CustomPaint(
              size: const Size(20, 20),
              painter: _GoogleLogoPainter(),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double radius = w / 2;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Red sector
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -2.35,
        1.57,
        false,
      )
      ..close();
    canvas.drawPath(redPath, paint);

    // Yellow sector
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -0.78,
        1.57,
        false,
      )
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green sector
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        0.78,
        1.57,
        false,
      )
      ..close();
    canvas.drawPath(greenPath, paint);

    // Blue sector
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        2.35,
        1.57,
        false,
      )
      ..close();
    canvas.drawPath(bluePath, paint);

    // Inner cutout
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), radius * 0.55, paint);

    // Blue horizontal bar
    paint.color = const Color(0xFF4285F4);
    final barRect =
        Rect.fromLTRB(cx, cy - radius * 0.22, cx + radius, cy + radius * 0.22);
    canvas.drawRect(barRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
