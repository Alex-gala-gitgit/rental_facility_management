/// Gazette schedule: https://www.kabinet.gov.my/storage/2025/08/HKA-2026.pdf
/// Additional Raya: P.U. (B) 111/112 of 2026 and Sabah's 18 March gazette.
/// Wesak replacement: BKPP announcement at https://www.kabinet.gov.my/
/// Dates are not extrapolated into unverified years. Local/employer replacement
/// days other than the specifically verified Wesak date are not inferred.
class MalaysiaHoliday {
  const MalaysiaHoliday(
      this.year, this.month, this.day, this.english, this.chinese, this.states);
  final int year, month, day;
  final String english, chinese, states;
  DateTime get date => DateTime(year, month, day);
  bool appliesTo(String? stateCode) =>
      states.isEmpty ||
      (stateCode != null && states.split(',').contains(stateCode));
}

String? malaysiaHolidayStateCode(String state) {
  final normalized = state
      .toLowerCase()
      .replaceAll('wilayah persekutuan', '')
      .replaceAll('w.p.', '')
      .trim();
  const codes = {
    'kuala lumpur': 'KL',
    'labuan': 'LB',
    'putrajaya': 'PJ',
    'johor': 'JH',
    'kedah': 'KD',
    'kelantan': 'KT',
    'melaka': 'MK',
    'malacca': 'MK',
    'negeri sembilan': 'NS',
    'pahang': 'PH',
    'perak': 'PK',
    'perlis': 'PL',
    'pulau pinang': 'PN',
    'penang': 'PN',
    'sabah': 'SB',
    'sarawak': 'SW',
    'selangor': 'SL',
    'terengganu': 'TG'
  };
  return codes[normalized];
}

List<MalaysiaHoliday> malaysiaHolidaysFor(int year, Iterable<String> states) {
  final codes =
      states.map(malaysiaHolidayStateCode).whereType<String>().toSet();
  return malaysiaHolidaySchedule
      .where((h) =>
          h.year == year &&
          (h.states.isEmpty || codes.any((code) => h.appliesTo(code))))
      .toList();
}

const malaysiaHolidaySchedule = <MalaysiaHoliday>[
  MalaysiaHoliday(
      2026, 1, 1, "New Year’s Day", "元旦", 'KL,LB,PJ,MK,NS,PH,PK,PN,SB,SW,SL'),
  MalaysiaHoliday(
      2026, 1, 14, "Negeri Sembilan ruler’s birthday", "森美兰统治者诞辰", 'NS'),
  MalaysiaHoliday(2026, 1, 17, "Israk and Mikraj", "登霄节", 'KD,NS,PL,TG'),
  MalaysiaHoliday(2026, 2, 1, "Thaipusam", "大宝森节", 'KL,PJ,JH,NS,PK,PN,SL'),
  MalaysiaHoliday(2026, 2, 1, "Federal Territory Day", "联邦直辖区日", 'KL,LB,PJ'),
  MalaysiaHoliday(2026, 2, 17, "Chinese New Year", "农历新年", ''),
  MalaysiaHoliday(2026, 2, 18, "Chinese New Year · Day 2", "农历新年第二天", ''),
  MalaysiaHoliday(2026, 2, 19, "Awal Ramadan", "斋戒月首日", 'JH,KD'),
  MalaysiaHoliday(
      2026, 2, 20, "Melaka Independence Declaration Day", "马六甲独立宣言日", 'MK'),
  MalaysiaHoliday(
      2026, 3, 4, "Terengganu coronation anniversary", "登嘉楼苏丹登基纪念日", 'TG'),
  MalaysiaHoliday(
      2026, 3, 7, "Nuzul Al-Quran", "可兰经降世日", 'KL,LB,PJ,KT,PH,PK,PL,PN,SL,TG'),
  MalaysiaHoliday(2026, 3, 20, "Additional Hari Raya holiday", "开斋节额外假日",
      'KL,LB,PJ,JH,KD,KT,MK,NS,PH,PK,PL,PN,SB,SL,TG'),
  MalaysiaHoliday(2026, 3, 21, "Hari Raya Aidilfitri", "开斋节", ''),
  MalaysiaHoliday(2026, 3, 22, "Hari Raya Aidilfitri · Day 2", "开斋节第二天", ''),
  MalaysiaHoliday(2026, 3, 23, "Johor Sultan’s birthday", "柔佛苏丹诞辰", 'JH'),
  MalaysiaHoliday(2026, 3, 23, "Hari Raya Aidilfitri · Day 3", "开斋节第三天", 'MK'),
  MalaysiaHoliday(2026, 3, 30, "Sabah Governor’s birthday", "沙巴州元首诞辰", 'SB'),
  MalaysiaHoliday(2026, 4, 3, "Good Friday", "耶稣受难日", 'SB,SW'),
  MalaysiaHoliday(2026, 4, 26, "Terengganu Sultan’s birthday", "登嘉楼苏丹诞辰", 'TG'),
  MalaysiaHoliday(2026, 5, 1, "Labour Day", "劳动节", ''),
  MalaysiaHoliday(2026, 5, 17, "Perlis ruler’s birthday", "玻璃市拉惹诞辰", 'PL'),
  MalaysiaHoliday(
      2026, 5, 22, "Pahang Sultan Ahmad Shah memorial day", "彭亨苏丹纪念日", 'PH'),
  MalaysiaHoliday(2026, 5, 26, "Arafat Day", "阿拉法特日", 'KT,TG'),
  MalaysiaHoliday(2026, 5, 27, "Hari Raya Aidiladha", "哈芝节", ''),
  MalaysiaHoliday(
      2026, 5, 28, "Hari Raya Aidiladha · Day 2", "哈芝节第二天", 'KD,KT,PL,TG'),
  MalaysiaHoliday(2026, 5, 30, "Kaamatan", "丰收节", 'LB,SB'),
  MalaysiaHoliday(2026, 5, 31, "Kaamatan · Day 2", "丰收节第二天", 'LB,SB'),
  MalaysiaHoliday(2026, 5, 31, "Wesak Day", "卫塞节", ''),
  MalaysiaHoliday(2026, 6, 1, "Yang di-Pertuan Agong’s birthday", "国家元首诞辰", ''),
  MalaysiaHoliday(2026, 6, 1, "Gawai Dayak", "达雅节", 'SW'),
  MalaysiaHoliday(2026, 6, 2, "Gawai Dayak · Day 2", "达雅节第二天", 'SW'),
  MalaysiaHoliday(2026, 6, 2, "Wesak replacement holiday", "卫塞节补假",
      'KL,LB,PJ,JH,MK,NS,PH,PK,PL,PN,SB,SW,SL'),
  MalaysiaHoliday(2026, 6, 17, "Awal Muharram", "回历元旦", ''),
  MalaysiaHoliday(2026, 6, 21, "Kedah Sultan’s birthday", "吉打苏丹诞辰", 'KD'),
  MalaysiaHoliday(
      2026, 7, 7, "George Town World Heritage Day", "乔治市世界遗产日", 'PN'),
  MalaysiaHoliday(2026, 7, 11, "Penang Governor’s birthday", "槟城州元首诞辰", 'PN'),
  MalaysiaHoliday(
      2026, 7, 21, "Johor Sultan Iskandar memorial day", "柔佛苏丹纪念日", 'JH'),
  MalaysiaHoliday(2026, 7, 22, "Sarawak Independence Day", "砂拉越独立日", 'SW'),
  MalaysiaHoliday(2026, 7, 31, "Pahang Sultan’s birthday", "彭亨苏丹诞辰", 'PH'),
  MalaysiaHoliday(2026, 8, 24, "Melaka Governor’s birthday", "马六甲州元首诞辰", 'MK'),
  MalaysiaHoliday(2026, 8, 25, "Prophet Muhammad’s birthday", "先知穆罕默德诞辰", ''),
  MalaysiaHoliday(2026, 8, 31, "National Day", "国庆日", ''),
  MalaysiaHoliday(2026, 9, 16, "Malaysia Day", "马来西亚日", ''),
  MalaysiaHoliday(2026, 9, 29, "Kelantan Sultan’s birthday", "吉兰丹苏丹诞辰", 'KT'),
  MalaysiaHoliday(
      2026, 9, 30, "Kelantan Sultan’s birthday · Day 2", "吉兰丹苏丹诞辰第二天", 'KT'),
  MalaysiaHoliday(
      2026, 10, 10, "Sarawak Governor’s birthday", "砂拉越州元首诞辰", 'SW'),
  MalaysiaHoliday(2026, 11, 6, "Perak Sultan’s birthday", "霹雳苏丹诞辰", 'PK'),
  MalaysiaHoliday(2026, 11, 8, "Deepavali", "屠妖节",
      'KL,LB,PJ,JH,KD,KT,MK,NS,PH,PK,PL,PN,SB,SL,TG'),
  MalaysiaHoliday(2026, 12, 11, "Selangor Sultan’s birthday", "雪兰莪苏丹诞辰", 'SL'),
  MalaysiaHoliday(2026, 12, 24, "Christmas Eve", "平安夜", 'SB'),
  MalaysiaHoliday(2026, 12, 25, "Christmas Day", "圣诞节", ''),
];
