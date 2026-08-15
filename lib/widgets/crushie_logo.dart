import 'package:flutter/material.dart';

class CrushieLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const CrushieLogo({
    Key? key,
    this.size = 140, // Increased size by 15-20% for prominent branding
    this.showShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showShadow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withOpacity(0.25),
                  blurRadius: size * 0.25,
                  spreadRadius: 2,
                  offset: Offset(0, size * 0.06),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/crushie_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) {
            return Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) {
                return Icon(Icons.favorite, size: size * 0.6, color: const Color(0xFFE91E63));
              },
            );
          },
        ),
      ),
    );
  }
}
