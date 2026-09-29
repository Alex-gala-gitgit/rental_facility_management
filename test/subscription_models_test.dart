import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/cloud/supabase_workspace_service.dart';
import 'package:rental_facility_management/subscription/subscription_models.dart';

void main() {
  test('subscription plan prices include only monthly and annual', () {
    expect(SubscriptionBillingPeriod.values,
        [SubscriptionBillingPeriod.monthly, SubscriptionBillingPeriod.annual]);
    expect(subscriptionPrice(SubscriptionBillingPeriod.monthly), 15.90);
    expect(subscriptionPrice(SubscriptionBillingPeriod.annual), 99.90);
  });

  test('membership and subscription values remain separate', () {
    expect(membershipTierFromValue('diamond'), MembershipTier.diamond);
    expect(subscriptionStatusFromValue('pending_verification'),
        SubscriptionStatus.pendingVerification);
    expect(subscriptionStatusLabel(SubscriptionStatus.expired), 'Expired');
  });

  test('safe owner access defaults match the Free plan', () {
    const config = OwnerAccessConfig();
    expect(config.propertyLimit, 1);
    expect(config.tenantLimit, 2);
    expect(config.exploreListingLimit, 0);
    expect(config.electricityTariffEnabled, isFalse);
    expect(config.announcementsEnabled, isFalse);
    expect(config.marketplaceEnabled, isFalse);
  });
}
