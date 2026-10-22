import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rental_facility_management/calendar/holiday_feed.dart';
import 'move_out_request_test.dart' show MemoryPersistence;

Map<String, dynamic> payload(int year) => {
      'status': 'verified',
      'year': year,
      'source': 'https://www.kabinet.gov.my/storage/HKA_$year.pdf',
      'holidays': List.generate(
          40,
          (i) => {
                'year': year,
                'month': i ~/ 28 + 1,
                'day': i % 28 + 1,
                'name': 'Hari Malaysia',
                'states': 'KL'
              })
    };

void main() {
  test('future years refresh, cache offline, and throttle daily', () async {
    final storage = MemoryPersistence();
    var calls = 0;
    final clock = () => DateTime(2026, 10, 3);
    final feed = HolidayFeed(
        persistence: storage,
        clock: clock,
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(payload(2027)), 200);
        }));
    await feed.refresh(2027);
    await feed.refresh(2027);
    expect(calls, 1);
    expect(feed.hasYear(2027), isTrue);
    expect(feed.forStates(2027, ['Kuala Lumpur']).length, 40);
    expect(feed.forStates(2027, ['Sarawak']), isEmpty);
    final offline = HolidayFeed(
        persistence: storage,
        clock: () => DateTime(2026, 10, 5),
        client: MockClient((_) async => http.Response('', 503)));
    await offline.refresh(2027);
    expect(offline.forStates(2027, ['Kuala Lumpur']).length, 40);
    expect(offline.unavailable.contains(2027), isTrue);
  });
  test('malformed or untrusted future feed never replaces dates', () async {
    for (final body in [
      {...payload(2027), 'source': 'https://evil.test/schedule.pdf'},
      {...payload(2027), 'holidays': []},
      {...payload(2027), 'year': 2028}
    ]) {
      final feed = HolidayFeed(
          persistence: MemoryPersistence(),
          client:
              MockClient((_) async => http.Response(jsonEncode(body), 200)));
      await feed.refresh(2027);
      expect(feed.hasYear(2027), isFalse);
    }
  });
}
