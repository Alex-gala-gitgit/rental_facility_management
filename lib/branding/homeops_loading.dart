import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'homeops_brand.dart';

class HomeOpsLoadingOverlay extends StatelessWidget {
  const HomeOpsLoadingOverlay({
    required this.loading,
    required this.child,
    this.label = 'Loading',
    super.key,
  });

  final bool loading;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (loading)
            Positioned.fill(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: label,
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: const Color(0xFF0E1B33).withOpacity(0.28),
                    child: Center(
                      child: HomeOpsLoadingCard(label: label),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class HomeOpsLoadingCard extends StatelessWidget {
  const HomeOpsLoadingCard({this.label = 'Loading', super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          key: const Key('homeops_loading_card'),
          width: 188,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCE5F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260E1B33),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _HomeOpsOrbitLoader(),
              const SizedBox(height: 15),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: homeOpsNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class HomeOpsInlineLoader extends StatelessWidget {
  const HomeOpsInlineLoader({this.semanticLabel = 'Loading', super.key});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        liveRegion: true,
        child: Container(
          key: const Key('homeops_inline_loader'),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD4E5F8)),
          ),
          alignment: Alignment.center,
          child: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              strokeCap: StrokeCap.round,
              color: homeOpsBlue,
              backgroundColor: Color(0xFFC9DFF5),
            ),
          ),
        ),
      );
}

class _HomeOpsOrbitLoader extends StatefulWidget {
  const _HomeOpsOrbitLoader();

  @override
  State<_HomeOpsOrbitLoader> createState() => _HomeOpsOrbitLoaderState();
}

class _HomeOpsOrbitLoaderState extends State<_HomeOpsOrbitLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 94,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDCE5F0)),
              ),
            ),
            const HomeOpsMark(size: 48, fillArtwork: true),
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) => Transform.rotate(
                angle: controller.value * math.pi * 2,
                child: child,
              ),
              child: const Stack(
                children: [
                  Positioned(
                    top: 3,
                    left: 39,
                    child: _OrbitDot(color: homeOpsTeal, size: 13),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 20,
                    child: _OrbitDot(color: homeOpsBlue, size: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 8,
            ),
          ],
        ),
      );
}
