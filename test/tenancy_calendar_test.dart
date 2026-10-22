import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';
import 'package:rental_facility_management/calendar/tenancy_calendar.dart';

void main() {
  test('October 2026 starts on Thursday in a Sunday-first grid', () {
    expect(tenancyCalendarOffset(DateTime(2026, 10)), 4);
    expect(tenancyCalendarOffset(DateTime(2026, 11)), 0);
    expect((tenancyCalendarOffset(DateTime(2026, 8)) + 31 + 6) ~/ 7, 6);
  });

  testWidgets('calendar fits a small phone and can navigate months',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RentalStore(seedDemoData: false);
    store.appLanguage = AppLanguage.english;
    await tester.pumpWidget(RentalStoreScope(
        store: store,
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(child: TenancyCalendar())))));
    expect(find.text('Tenancy calendar'), findsOneWidget);
    expect(find.text('No events for these dates.'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
