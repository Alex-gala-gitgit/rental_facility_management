import 'dart:math' as math;

import 'package:flutter/material.dart';

const homeOpsTeal = Color(0xFF10C8B0);
const homeOpsBlue = Color(0xFF2E6BFF);
const homeOpsNavy = Color(0xFF0E1B33);
const homeOpsMuted = Color(0xFF54617A);

const homeOps360IconSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
  <path d="M30 46 L52 28 L74 46 L74 92 L30 92 Z" fill="#10C8B0"/>
  <path d="M46 40 L68 22 L90 40 L90 92 L46 92 Z" fill="#2E6BFF"/>
  <path d="M58 68 L78 50 L98 68 L98 92 L58 92 Z" fill="#0E1B33"/>
  <rect x="72" y="76" width="12" height="16" rx="1.5" fill="#FFFFFF"/>
</svg>
''';

class HomeOpsMark extends StatelessWidget {
  const HomeOpsMark({this.size = 48, this.fillArtwork = false, super.key});

  final double size;
  final bool fillArtwork;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _HomeOpsMarkPainter(fillArtwork)),
      );
}

class HomeOpsLockup extends StatelessWidget {
  const HomeOpsLockup({
    this.markSize = 42,
    this.fontSize = 24,
    this.onDark = false,
    this.tagline,
    this.compact = false,
    super.key,
  });

  final double markSize;
  final double fontSize;
  final bool onDark;
  final String? tagline;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final wordmark = Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'HomeOps'),
          TextSpan(
            text: '360',
            style: TextStyle(color: onDark ? homeOpsTeal : homeOpsBlue),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: TextStyle(
        color: onDark ? Colors.white : homeOpsNavy,
        fontFamily: 'Outfit',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
    );
    final mark = onDark
        ? Container(
            width: markSize,
            height: markSize,
            padding: EdgeInsets.all(markSize * 0.08),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(markSize * 0.28),
            ),
            child: HomeOpsMark(size: markSize * 0.84),
          )
        : HomeOpsMark(size: markSize);

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        mark,
        SizedBox(width: markSize * 0.22),
        Flexible(
          child: tagline == null
              ? wordmark
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    wordmark,
                    Text(
                      tagline!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onDark
                            ? Colors.white.withOpacity(0.76)
                            : homeOpsMuted,
                        fontSize: fontSize * 0.42,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HomeOpsMarkPainter extends CustomPainter {
  const _HomeOpsMarkPainter(this.fillArtwork);

  final bool fillArtwork;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (fillArtwork) {
      const artwork = Rect.fromLTRB(26, 18, 102, 96);
      final scale =
          math.min(size.width / artwork.width, size.height / artwork.height);
      canvas.translate(
        (size.width - artwork.width * scale) / 2 - artwork.left * scale,
        (size.height - artwork.height * scale) / 2 - artwork.top * scale,
      );
      canvas.scale(scale, scale);
    } else {
      canvas.scale(size.width / 120, size.height / 120);
    }
    canvas.drawPath(
      Path()
        ..moveTo(30, 46)
        ..lineTo(52, 28)
        ..lineTo(74, 46)
        ..lineTo(74, 92)
        ..lineTo(30, 92)
        ..close(),
      Paint()..color = homeOpsTeal,
    );
    canvas.drawPath(
      Path()
        ..moveTo(46, 40)
        ..lineTo(68, 22)
        ..lineTo(90, 40)
        ..lineTo(90, 92)
        ..lineTo(46, 92)
        ..close(),
      Paint()..color = homeOpsBlue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(58, 68)
        ..lineTo(78, 50)
        ..lineTo(98, 68)
        ..lineTo(98, 92)
        ..lineTo(58, 92)
        ..close(),
      Paint()..color = homeOpsNavy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72, 76, 12, 16),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomeOpsMarkPainter oldDelegate) =>
      oldDelegate.fillArtwork != fillArtwork;
}
