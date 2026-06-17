import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';

void main() {
  testWidgets('shows role login actions', (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());

    expect(find.text('Rental Facility Manager'), findsOneWidget);
    expect(find.text('Login as Owner'), findsOneWidget);
    expect(find.text('Login as Property Agent'), findsOneWidget);
    expect(find.text('Login as Tenant'), findsOneWidget);
  });
}
