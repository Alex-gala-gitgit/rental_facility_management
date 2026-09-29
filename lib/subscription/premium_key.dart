import 'package:flutter/material.dart';

class PremiumKeyIcon extends StatelessWidget {
  const PremiumKeyIcon({
    this.size = 44,
    this.showBurgundyTile = true,
    super.key,
  });

  final double size;
  final bool showBurgundyTile;

  @override
  Widget build(BuildContext context) {
    final key = Transform.rotate(
      angle: -.68,
      child: Icon(
        Icons.key_rounded,
        size: size * .62,
        color: const Color(0xFFFFD35A),
        shadows: const [
          Shadow(
            color: Color(0x66000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
    if (!showBurgundyTile) return key;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB3265D), Color(0xFF4A102A)],
        ),
        borderRadius: BorderRadius.circular(size * .27),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 3),
            blurRadius: 7,
          ),
        ],
      ),
      child: key,
    );
  }
}
