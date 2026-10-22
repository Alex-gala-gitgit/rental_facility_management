import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../persistence/app_persistence.dart';
import '../persistence/persistence_contract.dart';
import 'malaysia_holidays.dart';

class HolidayFeed extends ChangeNotifier {
  HolidayFeed(
      {http.Client? client,
      AppPersistence? persistence,
      DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _storage = persistence,
        _clock = clock ?? DateTime.now;
  static final shared = HolidayFeed();
  final http.Client _client;
  AppPersistence? _storage;
  final DateTime Function() _clock;
  Future<void>? _initializing;
  final Map<int, List<MalaysiaHoliday>> _years = {};
  final Map<int, DateTime> _checks = {};
  final Map<int, Future<void>> _pending = {};
  final Map<int, DateTime> _retryAfter = {};
  final Set<int> unavailable = {};

  bool hasYear(int year) =>
      _years.containsKey(year) ||
      malaysiaHolidaySchedule.any((h) => h.year == year);
  List<MalaysiaHoliday> forStates(int year, Iterable<String> states) {
    final codes =
        states.map(malaysiaHolidayStateCode).whereType<String>().toSet();
    final entries = _years[year] ??
        malaysiaHolidaySchedule.where((h) => h.year == year).toList();
    // Preserve separately verified gazette supplements not in the annual table.
    final supplements = _years.containsKey(year)
        ? malaysiaHolidaySchedule.where((h) =>
            h.year == year &&
            (h.english == 'Additional Hari Raya holiday' ||
                h.english == 'Wesak replacement holiday'))
        : <MalaysiaHoliday>[];
    return [...entries, ...supplements]
        .where((h) => h.states.isEmpty || codes.any(h.appliesTo))
        .toList();
  }

  Future<void> _initialize() async {
    try {
      _storage ??=
          await createAppPersistence(namespace: 'official_holidays_v1');
      final raw = await _storage!.readSnapshot();
      if (raw != null) {
        final cache = jsonDecode(raw) as Map<String, dynamic>;
        for (final item in cache.entries) {
          final year = int.parse(item.key);
          final value = item.value as Map<String, dynamic>;
          _years[year] = validateHolidayRows(value['holidays'], year);
          _checks[year] = DateTime.parse(value['checkedAt'] as String);
        }
      }
    } catch (_) {/* Invalid cache never replaces the bundled dates. */}
    notifyListeners();
  }

  Future<void> refresh(int year) =>
      _pending[year] ??= _refresh(year).whenComplete(() {
        _pending.remove(year);
      });
  Future<void> _refresh(int year) async {
    await (_initializing ??= _initialize());
    if (_retryAfter[year]?.isAfter(_clock()) == true) return;
    final last = _checks[year];
    if (last != null &&
        _clock().difference(last) >= Duration.zero &&
        _clock().difference(last) < const Duration(days: 1)) return;
    try {
      final base = Uri.base.host.isNotEmpty &&
              ['http', 'https'].contains(Uri.base.scheme)
          ? Uri.base.origin
          : 'https://homeops360.app';
      final response = await _client
          .get(Uri.parse('$base/api/malaysia-holidays?year=$year'))
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200)
        throw const FormatException('Feed unavailable');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'verified' || body['year'] != year)
        throw const FormatException('Schedule not published');
      final source = Uri.parse(body['source'] as String);
      if (source.scheme != 'https' ||
          source.host != 'www.kabinet.gov.my' ||
          !source.path.endsWith('.pdf'))
        throw const FormatException('Untrusted source');
      final entries = validateHolidayRows(body['holidays'], year);
      _years[year] = entries;
      _checks[year] = _clock();
      unavailable.remove(year);
      _retryAfter.remove(year);
      notifyListeners();
      try {
        await _storage?.writeSnapshot(jsonEncode({
          for (final entry in _years.entries)
            '${entry.key}': {
              'checkedAt': _checks[entry.key]!.toIso8601String(),
              'holidays': entry.value
                  .map((h) => {
                        'year': h.year,
                        'month': h.month,
                        'day': h.day,
                        'name': h.english,
                        'chinese': h.chinese,
                        'states': h.states
                      })
                  .toList()
            }
        }));
      } catch (_) {/* In-memory data remains usable if storage is full. */}
    } catch (_) {
      unavailable.add(year);
      // Back off failures within this app session, without marking a failed
      // refresh as successful in persistent storage.
      _retryAfter[year] = _clock().add(const Duration(hours: 1));
      notifyListeners();
    }
  }
}

List<MalaysiaHoliday> validateHolidayRows(dynamic raw, int year) {
  if (raw is! List || raw.length < 40 || raw.length > 90)
    throw const FormatException('Incomplete schedule');
  const codes = {
    'KL',
    'LB',
    'PJ',
    'JH',
    'KD',
    'KT',
    'MK',
    'NS',
    'PH',
    'PK',
    'PL',
    'PN',
    'SB',
    'SW',
    'SL',
    'TG'
  };
  return raw.map((item) {
    final row = item as Map<String, dynamic>;
    final m = row['month'] as int, d = row['day'] as int;
    final name = row['name'] as String, states = row['states'] as String;
    final date = DateTime(year, m, d);
    if (row['year'] != year ||
        date.year != year ||
        date.month != m ||
        date.day != d ||
        name.isEmpty ||
        name.length > 240 ||
        (states.isNotEmpty && states.split(',').any((s) => !codes.contains(s))))
      throw const FormatException('Invalid holiday');
    final translated = holidayDisplayNames(name);
    return MalaysiaHoliday(year, m, d, translated.$1,
        row['chinese'] as String? ?? translated.$2, states);
  }).toList();
}

(String, String) holidayDisplayNames(String name) {
  const names = {
    'Tahun Baharu Cina': ('Chinese New Year', '农历新年'),
    'Hari Raya Puasa': ('Hari Raya Aidilfitri', '开斋节'),
    'Hari Raya Qurban': ('Hari Raya Aidiladha', '哈芝节'),
    'Hari Pekerja': ('Labour Day', '劳动节'),
    'Hari Wesak': ('Wesak Day', '卫塞节'),
    'Hari Kebangsaan': ('National Day', '国庆日'),
    'Hari Malaysia': ('Malaysia Day', '马来西亚日'),
    'Hari Deepavali': ('Deepavali', '屠妖节'),
    'Hari Krismas': ('Christmas Day', '圣诞节'),
    'Hari Wilayah Persekutuan': ('Federal Territory Day', '联邦直辖区日'),
    'Hari Thaipusam': ('Thaipusam', '大宝森节'),
    'Awal Muharam (Maal Hijrah)': ('Awal Muharram', '回历元旦'),
    'Awal Ramadan': ('Awal Ramadan', '斋戒月首日'),
    'Israk dan Mikraj': ('Israk and Mikraj', '登霄节'),
    'Hari Nuzul Al-Quran': ('Nuzul Al-Quran', '可兰经降世日'),
    'Hari Arafah': ('Arafat Day', '阿拉法特日'),
    'Pesta Kaamatan (Pesta Menuai)': ('Kaamatan', '丰收节'),
    'Perayaan Hari Gawai Dayak': ('Gawai Dayak', '达雅节'),
    'Good Friday': ('Good Friday', '耶稣受难日'),
    'Christmas Eve': ('Christmas Eve', '平安夜'),
    'Hari Keputeraan Rasmi Seri Paduka Baginda Yang di-Pertuan Agong': (
      'Yang di-Pertuan Agong’s birthday',
      '国家元首诞辰'
    ),
    'Hari Keputeraan Nabi Muhammad S.A.W. (Maulidur Rasul)': (
      'Prophet Muhammad’s birthday',
      '先知穆罕默德诞辰'
    ),
  };
  if (name.startsWith('Tahun Baharu ') && !name.contains('Cina'))
    return ('New Year’s Day', '元旦');
  final second = name.endsWith('(Hari Kedua)');
  final base = second ? name.replaceAll(' (Hari Kedua)', '') : name;
  final translated = names[base];
  if (translated != null)
    return (
      translated.$1 + (second ? ' · Day 2' : ''),
      translated.$2 + (second ? '第二天' : '')
    );
  // Preserve the official name for unfamiliar future holidays, rather than
  // inventing a translation or misidentifying a new declaration.
  return (name, name);
}
