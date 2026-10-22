import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/calendar/malaysia_holidays.dart';

void main() {
  test('normalizes property states', () {
    expect(malaysiaHolidayStateCode('Wilayah Persekutuan Kuala Lumpur'), 'KL');
    expect(malaysiaHolidayStateCode('Pulau Pinang'), 'PN');
    expect(malaysiaHolidayStateCode('Unknown'), isNull);
  });
  test('Kuala Lumpur does not include Sarawak-only holidays', () {
    final kl = malaysiaHolidaysFor(2026, ['Kuala Lumpur']);
    expect(kl.any((h) => h.month == 10 && h.day == 10), isFalse);
    expect(kl.any((h) => h.english == 'Federal Territory Day'), isTrue);
    expect(
        kl.any((h) =>
            h.english == 'Wesak replacement holiday' &&
            h.day == 2 &&
            h.month == 6),
        isTrue);
    expect(
        kl.any((h) => h.english == 'Deepavali' && h.day == 8 && h.month == 11),
        isTrue);
  });
  test('Sarawak has its own holidays and excludes Deepavali', () {
    final sw = malaysiaHolidaysFor(2026, ['Sarawak']);
    expect(sw.any((h) => h.month == 10 && h.day == 10), isTrue);
    expect(sw.any((h) => h.english == 'Deepavali'), isFalse);
  });
  test('no future dates are guessed and unknown states get nationwide only',
      () {
    expect(malaysiaHolidaysFor(2027, ['Kuala Lumpur']), isEmpty);
    expect(
        malaysiaHolidaysFor(2026, ['Unknown']).every((h) => h.states.isEmpty),
        isTrue);
  });
}
