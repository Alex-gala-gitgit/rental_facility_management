import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../cloud/subscription_service.dart';
import '../file_upload/payment_proof_picker.dart';
import 'subscription_models.dart';
import 'premium_key.dart';

const _subscriptionNavy = Color(0xFF12213D);
const _subscriptionBlue = Color(0xFF2475DC);
const _subscriptionMuted = Color(0xFF66758A);

typedef SubscriptionText = String Function(String value);

Future<void> showSubscriptionRequiredDialog(
  BuildContext context, {
  required SubscriptionService service,
  required MembershipTier currentTier,
  required SubscriptionStatus currentStatus,
  required VoidCallback onSubmitted,
  required SubscriptionText translate,
}) async {
  String t(String value) => translate(value);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
      title: Row(
        children: [
          const PremiumKeyIcon(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t('Premium subscription required'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentStatus == SubscriptionStatus.pendingVerification
                    ? t('Your Premium payment is awaiting administrator verification.')
                    : t('You have reached the Free plan limit. Upgrade to continue.'),
                style: const TextStyle(color: _subscriptionMuted),
              ),
              const SizedBox(height: 14),
              _PlanComparisonCard(
                title: t('Free'),
                current: true,
                translate: t,
                features: [
                  (true, t('Maximum 1 property')),
                  (true, t('Maximum 2 tenants')),
                  (false, t('No electricity tariff configuration')),
                  (false, t('No broadcasting or announcement feature')),
                  (false, t('No marketplace')),
                ],
              ),
              const SizedBox(height: 10),
              _PlanComparisonCard(
                title: t('Premium'),
                highlighted: true,
                translate: t,
                features: [
                  (true, t('Up to 5 properties')),
                  (true, t('Maximum 30 tenants')),
                  (true, t('Electricity tariff configuration')),
                  (true, t('24/7 priority support')),
                  (true, t('Announcement feature')),
                  (true, t('Marketplace enabled')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(t('Not now')),
        ),
        FilledButton(
          onPressed: currentTier == MembershipTier.diamond ||
                  currentStatus == SubscriptionStatus.pendingVerification
              ? null
              : () async {
                  Navigator.pop(dialogContext);
                  final submitted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => PremiumPlanScreen(
                        service: service,
                        translate: translate,
                      ),
                    ),
                  );
                  if (submitted == true) onSubmitted();
                },
          child: Text(
            currentStatus == SubscriptionStatus.pendingVerification
                ? t('Verification pending')
                : t('View Premium plan'),
          ),
        ),
      ],
    ),
  );
}

class PremiumPlanScreen extends StatefulWidget {
  const PremiumPlanScreen({
    required this.service,
    required this.translate,
    super.key,
  });

  final SubscriptionService service;
  final SubscriptionText translate;

  @override
  State<PremiumPlanScreen> createState() => _PremiumPlanScreenState();
}

class _PremiumPlanScreenState extends State<PremiumPlanScreen> {
  SubscriptionBillingPeriod period = SubscriptionBillingPeriod.annual;
  PickedImageData? paymentSlip;
  bool submitting = false;
  String? error;

  String get contentType {
    final name = paymentSlip?.name.toLowerCase() ?? '';
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> pickSlip() async {
    try {
      final picked = await pickPaymentProof();
      if (picked == null || !mounted) return;
      setState(() {
        paymentSlip = picked;
        error = null;
      });
    } catch (caught) {
      if (mounted) setState(() => error = '$caught');
    }
  }

  Future<void> submit() async {
    String t(String value) => widget.translate(value);
    final slip = paymentSlip;
    if (slip == null || submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.service.submitPremiumRequest(
        billingPeriod: period,
        fileName: slip.name,
        bytes: Uint8List.fromList(slip.bytes),
        contentType: contentType,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon:
              const Icon(Icons.hourglass_top_rounded, color: _subscriptionBlue),
          title: Text(t('Submitted for verification')),
          content: Text(
            t('Your payment slip was sent to HomeOps360 administration. Premium access begins after approval.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Done')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (caught) {
      if (mounted) setState(() => error = '$caught');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => widget.translate(value);
    return Scaffold(
      appBar: AppBar(title: Text(t('Premium plan'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF19345E), Color(0xFF176FD5)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PremiumKeyIcon(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('Upgrade to Premium'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PremiumFeatureGrid(translate: t),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('Choose billing period'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  _BillingPeriodTile(
                    title: t('1 month'),
                    subtitle: t('Monthly access'),
                    amount: 'RM 15.90',
                    selected: period == SubscriptionBillingPeriod.monthly,
                    onTap: () => setState(
                      () => period = SubscriptionBillingPeriod.monthly,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _BillingPeriodTile(
                    title: t('12 months'),
                    subtitle: t('Best value · Save RM 90.90'),
                    amount: 'RM 99.90',
                    selected: period == SubscriptionBillingPeriod.annual,
                    onTap: () => setState(
                      () => period = SubscriptionBillingPeriod.annual,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Payment method'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _subscriptionBlue),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          t('Payment instructions and account details will appear here after they are configured by the administrator.'),
                          style: const TextStyle(color: _subscriptionMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('Submit payment for verification'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: submitting ? null : pickSlip,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(paymentSlip?.name ?? t('Upload payment slip')),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        paymentSlip == null || submitting ? null : submit,
                    icon: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: Text(
                      submitting
                          ? t('Submitting…')
                          : t('Submit for admin verification'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('No payment gateway. Premium begins only after administrator approval.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _subscriptionMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanComparisonCard extends StatelessWidget {
  const _PlanComparisonCard({
    required this.title,
    required this.features,
    required this.translate,
    this.current = false,
    this.highlighted = false,
  });

  final String title;
  final List<(bool, String)> features;
  final SubscriptionText translate;
  final bool current;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEDF6FF) : Colors.white,
        border: Border.all(
          color: highlighted ? _subscriptionBlue : const Color(0xFFD7E0EC),
          width: highlighted ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (highlighted) ...[
                const Icon(Icons.auto_awesome_rounded,
                    color: _subscriptionBlue, size: 18),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (current)
                Chip(
                  label: Text(translate('Current plan')),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    feature.$1 ? Icons.check_rounded : Icons.close_rounded,
                    size: 17,
                    color: feature.$1
                        ? highlighted
                            ? _subscriptionBlue
                            : _subscriptionNavy
                        : _subscriptionMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      feature.$2,
                      style: TextStyle(
                        color:
                            feature.$1 ? _subscriptionNavy : _subscriptionMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumFeatureGrid extends StatelessWidget {
  const _PremiumFeatureGrid({required this.translate});

  final SubscriptionText translate;

  @override
  Widget build(BuildContext context) {
    const items = [
      'Up to 5 properties',
      'Maximum 30 tenants',
      'Electricity tariff configuration',
      '24/7 priority support',
      'Announcement feature',
      'Marketplace enabled',
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final item in items)
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 430 ? 180 : 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_rounded,
                    size: 17, color: Color(0xFF83E2C4)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    translate(item),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BillingPeriodTile extends StatelessWidget {
  const _BillingPeriodTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF4FF) : const Color(0xFFF7F9FC),
          border: Border.all(
            color: selected ? _subscriptionBlue : const Color(0xFFD7E0EC),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? _subscriptionBlue : _subscriptionMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _subscriptionMuted, fontSize: 12)),
                ],
              ),
            ),
            Text(amount,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: _subscriptionNavy)),
          ],
        ),
      ),
    );
  }
}
