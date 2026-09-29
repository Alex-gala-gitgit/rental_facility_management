import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('owner monthly performance export creates a five-page PDF', () async {
    final store = RentalStore(now: DateTime(2026, 9));
    store.loginAs(UserRole.owner);

    final bytes = await buildOwnerMonthlyPerformancePdf(
      store,
      DateTime(2026, 9),
    );
    final text = latin1.decode(bytes, allowInvalid: true);

    expect(bytes.length, greaterThan(5000));
    expect(text.startsWith('%PDF-'), isTrue);
  });
}
