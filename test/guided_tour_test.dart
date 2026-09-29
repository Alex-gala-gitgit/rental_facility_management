import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';
import 'package:rental_facility_management/onboarding/guided_tour.dart';

void main() {
  testWidgets('coach mark stays on the live page and highlights its target',
      (tester) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Scaffold(
              appBar: AppBar(title: const Text('Real owner page')),
              body: Center(
                child: FilledButton(
                  key: targetKey,
                  onPressed: () {},
                  child: const Text('Complete billing'),
                ),
              ),
            ),
            Positioned.fill(
              child: ContextualGuidedTourOverlay(
                audience: GuidedTourAudience.owner,
                step: ownerContextualTourSteps.first,
                stepIndex: 0,
                totalSteps: ownerContextualTourSteps.length,
                targetKey: targetKey,
                onNext: () {},
                onBack: null,
                onSkip: () {},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Real owner page'), findsOneWidget);
    expect(find.text('Complete billing'), findsOneWidget);
    expect(find.byKey(const Key('guided_tour_spotlight')), findsOneWidget);
    expect(
        find.byKey(const Key('guided_tour_explanation_card')), findsOneWidget);
    expect(find.text('Start billing from Home'), findsOneWidget);
  });

  testWidgets('tariff property selector and editor share one dialog',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 8, 1));
    store.loginAs(UserRole.owner);
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTariffFacilityPicker(context),
                child: const Text('Configure tariff'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Configure tariff'));
    await tester.pumpAndSettle();

    expect(find.text('Select property tariff'), findsNothing);
    expect(find.text('Billing configuration'), findsOneWidget);
    expect(
      find.byKey(const Key('billing_configuration_property_selector')),
      findsOneWidget,
    );
    expect(find.text('Tariff slabs'), findsOneWidget);
    expect(find.text('Save tariff'), findsOneWidget);
  });

  test('owner contextual tour covers the real billing workflow', () {
    expect(ownerContextualTourSteps.first.tabIndex, 2);
    expect(ownerContextualTourSteps.first.targetId, 'owner_billing');
    expect(
      ownerContextualTourSteps.map((step) => step.title),
      containsAll(<String>[
        'Start billing from Home',
        'Configure the electricity tariff',
        'Review and generate the PDF bill',
        'Verify submitted payments',
      ]),
    );
  });

  test('tenant contextual tour covers payment and maintenance', () {
    expect(tenantContextualTourSteps.first.targetId, 'tenant_pay_now');
    expect(
      tenantContextualTourSteps.map((step) => step.title),
      containsAll(<String>[
        'Review the invoice PDF',
        'Upload payment proof',
        'Track the payment status',
        'Raise a maintenance request',
      ]),
    );
  });

  test('guided tour progress keys remain role-specific and versioned', () {
    expect(guidedTourKey(GuidedTourAudience.owner), ownerGuidedTourKey);
    expect(guidedTourKey(GuidedTourAudience.tenant), tenantGuidedTourKey);
    expect(ownerGuidedTourKey, isNot(tenantGuidedTourKey));
    expect(ownerGuidedTourKey, endsWith('_v1'));
    expect(tenantGuidedTourKey, endsWith('_v1'));
  });
}
