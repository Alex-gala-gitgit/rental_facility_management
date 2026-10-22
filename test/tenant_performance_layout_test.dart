import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';

void main() {
  testWidgets('mobile tenant groups retain moved-out profiles and hide address', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RentalStore(now: DateTime(2026, 10, 4));
    store.currentUser = store.users.firstWhere((user) => user.role == UserRole.owner);
    final facility = store.facilities.first;
    final tenancy = store.tenancies.firstWhere((item) => item.facilityId == facility.id);
    tenancy.lastActiveDate = DateTime(2026, 9, 30);
    await tester.pumpWidget(RentalStoreScope(store: store, child: MaterialApp(
      home: FacilityMasterDetailScreen(facility: facility, year: 2026))));
    await tester.pumpAndSettle();
    expect(find.text(facility.address), findsNothing);
    expect(find.textContaining('Active tenants ('), findsOneWidget);
    expect(find.textContaining('Moved-out tenants ('), findsOneWidget);
    final card = find.byKey(ValueKey('tenant_filter_${tenancy.tenantId}'));
    expect(card, findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(find.descendant(of: card, matching: find.byType(CircleAvatar)));
    expect(avatar.backgroundColor, const Color(0xFFE5E7EB));
    expect(tester.getSize(card).height, 76);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('View profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
