import 'package:flutter/material.dart';

enum GuidedTourAudience { owner, tenant }

enum GuidedTourResult { completed, skipped }

const ownerGuidedTourKey = 'owner_v1';
const tenantGuidedTourKey = 'tenant_v1';

String guidedTourKey(GuidedTourAudience audience) => switch (audience) {
      GuidedTourAudience.owner => ownerGuidedTourKey,
      GuidedTourAudience.tenant => tenantGuidedTourKey,
    };

class GuidedTourRequestNotification extends Notification {
  const GuidedTourRequestNotification(this.audience);

  final GuidedTourAudience audience;
}

class ContextualGuidedTourStep {
  const ContextualGuidedTourStep({
    required this.tabIndex,
    required this.targetId,
    required this.icon,
    required this.title,
    required this.description,
    this.fallbackTargetId,
  });

  final int tabIndex;
  final String targetId;
  final String? fallbackTargetId;
  final IconData icon;
  final String title;
  final String description;
}

const ownerContextualTourSteps = <ContextualGuidedTourStep>[
  ContextualGuidedTourStep(
    tabIndex: 2,
    targetId: 'owner_billing',
    fallbackTargetId: 'owner_home_nav',
    icon: Icons.receipt_long_outlined,
    title: 'Start billing from Home',
    description:
        'Tap Complete billing on the Home dashboard to prepare the monthly bills. The guide highlights the real control without changing any records.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 0,
    targetId: 'owner_add_tenant',
    fallbackTargetId: 'owner_properties_nav',
    icon: Icons.person_add_alt_1_rounded,
    title: 'Add a property and tenant',
    description:
        'Open Properties, create the property first, then use New Tenant to assign the unit, rental dates and package.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 4,
    targetId: 'owner_billing_configuration',
    fallbackTargetId: 'owner_profile_nav',
    icon: Icons.electric_bolt_outlined,
    title: 'Configure the electricity tariff',
    description:
        'Billing configuration lets you set the tariff separately for each property before generating utility charges.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 1,
    targetId: 'owner_payments_nav',
    icon: Icons.picture_as_pdf_outlined,
    title: 'Review and generate the PDF bill',
    description:
        'Use Payments to review the bill details and PDF before the invoice is submitted to the tenant.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 1,
    targetId: 'owner_payments_nav',
    icon: Icons.fact_check_outlined,
    title: 'Verify submitted payments',
    description:
        'Compare the tenant’s payment slip, amount and reference. Approve only after verification, or reject it with a reason.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 4,
    targetId: 'owner_replay_tour',
    fallbackTargetId: 'owner_profile_nav',
    icon: Icons.replay_rounded,
    title: 'Replay this guide any time',
    description:
        'Open Profile and tap Help & guided tour whenever you want to see these highlights again.',
  ),
];

const tenantContextualTourSteps = <ContextualGuidedTourStep>[
  ContextualGuidedTourStep(
    tabIndex: 0,
    targetId: 'tenant_pay_now',
    fallbackTargetId: 'tenant_home_nav',
    icon: Icons.payments_outlined,
    title: 'Check the amount due',
    description:
        'Your Home dashboard shows the current amount due. Tap Pay now to begin reviewing the real invoice.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 2,
    targetId: 'tenant_pay_nav',
    icon: Icons.picture_as_pdf_outlined,
    title: 'Review the invoice PDF',
    description:
        'Open Pay, choose the invoice and review its rent, utilities, beneficiary, due date and PDF before transferring payment.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 2,
    targetId: 'tenant_pay_nav',
    icon: Icons.upload_file_outlined,
    title: 'Upload payment proof',
    description:
        'After payment, attach the correct JPG, PNG or PDF receipt and enter the payment reference for owner verification.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 2,
    targetId: 'tenant_pay_nav',
    icon: Icons.pending_actions_outlined,
    title: 'Track the payment status',
    description:
        'Pending means the owner is reviewing it. Approved closes the invoice; rejected includes the correction reason.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 3,
    targetId: 'tenant_new_request',
    fallbackTargetId: 'tenant_requests_nav',
    icon: Icons.handyman_outlined,
    title: 'Raise a maintenance request',
    description:
        'Use Requests and tap the highlighted add button to report an issue and follow its progress.',
  ),
  ContextualGuidedTourStep(
    tabIndex: 4,
    targetId: 'tenant_replay_tour',
    fallbackTargetId: 'tenant_profile_nav',
    icon: Icons.replay_rounded,
    title: 'Replay this guide any time',
    description:
        'Open Profile and tap Help & guided tour whenever you need these instructions again.',
  ),
];

class ContextualGuidedTourOverlay extends StatefulWidget {
  const ContextualGuidedTourOverlay({
    required this.audience,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.targetKey,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    super.key,
  });

  final GuidedTourAudience audience;
  final ContextualGuidedTourStep step;
  final int stepIndex;
  final int totalSteps;
  final GlobalKey? targetKey;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  State<ContextualGuidedTourOverlay> createState() =>
      _ContextualGuidedTourOverlayState();
}

class _ContextualGuidedTourOverlayState
    extends State<ContextualGuidedTourOverlay> {
  Rect? targetRect;

  @override
  void initState() {
    super.initState();
    _measureTarget();
  }

  @override
  void didUpdateWidget(covariant ContextualGuidedTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex ||
        oldWidget.targetKey != widget.targetKey) {
      targetRect = null;
      _measureTarget();
    }
  }

  void _measureTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = widget.targetKey?.currentContext;
      final overlayBox = context.findRenderObject();
      final targetBox = targetContext?.findRenderObject();
      if (overlayBox is! RenderBox || targetBox is! RenderBox) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted && targetRect == null) _measureTarget();
        });
        return;
      }
      final globalTarget = targetBox.localToGlobal(Offset.zero);
      final globalOverlay = overlayBox.localToGlobal(Offset.zero);
      final rect = (globalTarget - globalOverlay) & targetBox.size;
      if (mounted) setState(() => targetRect = rect.inflate(7));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final safeTarget =
              targetRect ?? Rect.fromLTWH(18, 18, size.width.clamp(0, 180), 58);
          final showCardAbove = safeTarget.center.dy > size.height * .52;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  key: const Key('guided_tour_spotlight'),
                  painter: _CoachMarkPainter(target: safeTarget),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: showCardAbove ? 18 : null,
                bottom: showCardAbove ? null : 20,
                child: SafeArea(
                  child: _TourExplanationCard(
                    audience: widget.audience,
                    step: widget.step,
                    stepIndex: widget.stepIndex,
                    totalSteps: widget.totalSteps,
                    onNext: widget.onNext,
                    onBack: widget.onBack,
                    onSkip: widget.onSkip,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TourExplanationCard extends StatelessWidget {
  const _TourExplanationCard({
    required this.audience,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final GuidedTourAudience audience;
  final ContextualGuidedTourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          key: const Key('guided_tour_explanation_card'),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF172A48),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF315B91)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(step.icon, color: const Color(0xFF57A4FF), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${audience == GuidedTourAudience.owner ? 'Owner' : 'Tenant'} guide · ${stepIndex + 1} of $totalSteps',
                      style: const TextStyle(
                        color: Color(0xFF57A4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('guided_tour_skip_button'),
                    onPressed: onSkip,
                    child: const Text(
                      'Skip tour',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                step.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                step.description,
                style: const TextStyle(
                  color: Color(0xFFD8E7FA),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var index = 0; index < totalSteps; index++) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == stepIndex ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: index == stepIndex
                            ? const Color(0xFF3E8FF7)
                            : const Color(0xFF526782),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    if (index != totalSteps - 1) const SizedBox(width: 5),
                  ],
                  const Spacer(),
                  if (onBack != null)
                    TextButton(
                      key: const Key('guided_tour_back_button'),
                      onPressed: onBack,
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(width: 6),
                  FilledButton(
                    key: const Key('guided_tour_next_button'),
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2D7BE5),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isLast ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachMarkPainter extends CustomPainter {
  const _CoachMarkPainter({required this.target});

  final Rect target;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final radius = target.height > 90 ? 24.0 : target.height / 2;
    final spotlight = Path()
      ..addRRect(RRect.fromRectAndRadius(target, Radius.circular(radius)));
    final dimmed = Path.combine(PathOperation.difference, screen, spotlight);
    canvas.drawPath(dimmed, Paint()..color = const Color(0xD90A1B33));

    canvas.drawRRect(
      RRect.fromRectAndRadius(target, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF4AA3FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(target.inflate(4), Radius.circular(radius + 4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = const Color(0x554AA3FF),
    );
  }

  @override
  bool shouldRepaint(covariant _CoachMarkPainter oldDelegate) =>
      oldDelegate.target != target;
}
