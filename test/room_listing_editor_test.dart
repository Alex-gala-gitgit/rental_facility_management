import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/explore/room_explore.dart';

void main() {
  testWidgets('publish unit starts from the selected owner property',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: RoomListingEditorScreen(
          facilities: [
            RoomListingFacilityOption(
              id: 'facility-1',
              name: 'MH Platinum 2',
              addressLine: '12 Jalan Usahawan 6',
              postcode: '53300',
              city: 'Setapak',
              state: 'Kuala Lumpur',
            ),
          ],
          publisherName: 'Alex',
          contactPhone: '+60123456789',
          initialFacilityId: 'facility-1',
        ),
      ),
    );

    expect(find.text('Publish Unit'), findsOneWidget);
    expect(find.text('Linked to Tenant Explore'), findsOneWidget);
    expect(find.text('MH Platinum 2 · '), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Preview & Publish'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Preview & Publish'), findsOneWidget);
    expect(find.text('Visible to signed-in tenants'), findsOneWidget);
  });
}
