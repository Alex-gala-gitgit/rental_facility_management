import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/requests/move_out_thank_you.dart';

void main() {
  testWidgets('personalised thank-you message and pending status appear',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: MoveOutThankYouPage(tenantName: 'Yuan Jun')));
    expect(find.text('Hi Yuan Jun,'), findsOneWidget);
    expect(find.textContaining('Thank you for choosing to stay with us'),
        findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Done'), 300);
    expect(find.textContaining('awaiting owner confirmation'), findsOneWidget);
    expect(find.text('Warm regards,\nAlex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
