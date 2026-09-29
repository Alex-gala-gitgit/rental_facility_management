import 'package:flutter/material.dart';

class DiamondCrownIcon extends StatelessWidget {
  const DiamondCrownIcon(
      {this.size = 44, this.showPurpleTile = true, super.key});

  final double size;
  final bool showPurpleTile;

  @override
  Widget build(BuildContext context) {
    final crown = CustomPaint(
      size: Size.square(size * .62),
      painter: const _FilledCrownPainter(),
    );
    if (!showPurpleTile) return crown;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(size * .27),
      ),
      child: crown,
    );
  }
}

class _FilledCrownPainter extends CustomPainter {
  const _FilledCrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xFFF7C948);
    final path = Path()
      ..moveTo(size.width * .08, size.height * .30)
      ..lineTo(size.width * .31, size.height * .52)
      ..lineTo(size.width * .50, size.height * .18)
      ..lineTo(size.width * .69, size.height * .52)
      ..lineTo(size.width * .92, size.height * .30)
      ..lineTo(size.width * .82, size.height * .76)
      ..lineTo(size.width * .18, size.height * .76)
      ..close();
    canvas.drawPath(path, gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .17, size.height * .81, size.width * .66,
            size.height * .11),
        Radius.circular(size.height * .055),
      ),
      gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
