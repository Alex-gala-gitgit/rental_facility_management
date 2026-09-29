enum MembershipTier { free, premium, diamond }

enum SubscriptionStatus { active, pendingVerification, expired }

enum SubscriptionBillingPeriod { monthly, annual }

MembershipTier membershipTierFromValue(Object? value) => switch ('$value') {
      'premium' => MembershipTier.premium,
      'diamond' => MembershipTier.diamond,
      _ => MembershipTier.free,
    };

SubscriptionStatus subscriptionStatusFromValue(Object? value) =>
    switch ('$value') {
      'pending_verification' => SubscriptionStatus.pendingVerification,
      'expired' => SubscriptionStatus.expired,
      _ => SubscriptionStatus.active,
    };

String membershipTierValue(MembershipTier tier) => tier.name;

String membershipTierLabel(MembershipTier tier) => switch (tier) {
      MembershipTier.free => 'Free',
      MembershipTier.premium => 'Premium',
      MembershipTier.diamond => 'Diamond',
    };

String subscriptionStatusValue(SubscriptionStatus status) => switch (status) {
      SubscriptionStatus.active => 'active',
      SubscriptionStatus.pendingVerification => 'pending_verification',
      SubscriptionStatus.expired => 'expired',
    };

String subscriptionStatusLabel(SubscriptionStatus status) => switch (status) {
      SubscriptionStatus.active => 'Active',
      SubscriptionStatus.pendingVerification => 'Pending verification',
      SubscriptionStatus.expired => 'Expired',
    };

String subscriptionBillingPeriodValue(SubscriptionBillingPeriod period) =>
    period.name;

double subscriptionPrice(SubscriptionBillingPeriod period) => switch (period) {
      SubscriptionBillingPeriod.monthly => 15.90,
      SubscriptionBillingPeriod.annual => 99.90,
    };

String subscriptionBillingPeriodLabel(SubscriptionBillingPeriod period) =>
    switch (period) {
      SubscriptionBillingPeriod.monthly => '1 month',
      SubscriptionBillingPeriod.annual => '12 months',
    };

class SubscriptionRequestRecord {
  const SubscriptionRequestRecord({
    required this.id,
    required this.billingPeriod,
    required this.amount,
    required this.status,
    required this.paymentSlipName,
    required this.submittedAt,
    this.adminNotes = '',
  });

  factory SubscriptionRequestRecord.fromMap(Map<String, dynamic> row) =>
      SubscriptionRequestRecord(
        id: '${row['id']}',
        billingPeriod: '${row['billing_period']}' == 'annual'
            ? SubscriptionBillingPeriod.annual
            : SubscriptionBillingPeriod.monthly,
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        status: '${row['status']}',
        paymentSlipName: '${row['payment_slip_name'] ?? ''}',
        submittedAt: DateTime.tryParse('${row['submitted_at']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        adminNotes: '${row['admin_notes'] ?? ''}',
      );

  final String id;
  final SubscriptionBillingPeriod billingPeriod;
  final double amount;
  final String status;
  final String paymentSlipName;
  final DateTime submittedAt;
  final String adminNotes;
}
