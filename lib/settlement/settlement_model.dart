import 'dart:convert';
import 'dart:typed_data';

int? settlementCents(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
}

String settlementMoney(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';

class SettlementAttachment {
  const SettlementAttachment(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  Map<String, dynamic> toJson() => {'name': name, 'bytes': base64Encode(bytes)};
  factory SettlementAttachment.fromJson(Map<String, dynamic> json) =>
      SettlementAttachment(
          json['name'] as String, base64Decode(json['bytes'] as String));
}

class MoveOutSettlement {
  const MoveOutSettlement({
    required this.tenantName,
    required this.propertyName,
    required this.unitName,
    required this.moveOutDate,
    required this.deposit,
    required this.electricity,
    required this.water,
    required this.internet,
    required this.parking,
    required this.other,
    required this.otherDescription,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.monthlyRent = 0,
    this.proratedStayDays = 0,
    this.isFinalInvoice = false,
    this.meter,
    this.payslip,
    this.electricityUsageKwh,
  });
  final String tenantName,
      propertyName,
      unitName,
      otherDescription,
      bankName,
      bankAccountNumber;
  final DateTime moveOutDate;
  final int deposit,
      electricity,
      water,
      internet,
      parking,
      other,
      monthlyRent,
      proratedStayDays;
  final bool isFinalInvoice;
  final SettlementAttachment? meter, payslip;
  final double? electricityUsageKwh;
  bool get isRefunded => payslip != null;
  int get proratedStay => (monthlyRent * proratedStayDays / 30).round();
  int get deductions =>
      proratedStay + electricity + water + internet + parking + other;
  int get balance => deposit - deductions;
  String get otherLabel => otherDescription.trim().isEmpty
      ? 'Other charges'
      : 'Other charges - ${otherDescription.trim()}';
  List<(String, int)> get charges => [
        ('Prorated stay ($proratedStayDays day${proratedStayDays == 1 ? '' : 's'})',
            proratedStay),
        ('Electricity', electricity),
        ('Water bill', water),
        ('Internet', internet),
        ('Parking', parking),
        (otherLabel, other),
      ];
  String get dateLabel => '${moveOutDate.day.toString().padLeft(2, '0')}/'
      '${moveOutDate.month.toString().padLeft(2, '0')}/${moveOutDate.year}';
  Map<String, dynamic> toJson() => {
        'tenantName': tenantName,
        'propertyName': propertyName,
        'unitName': unitName,
        'moveOutDate':
            '${moveOutDate.year}-${moveOutDate.month.toString().padLeft(2, '0')}-${moveOutDate.day.toString().padLeft(2, '0')}',
        'deposit': deposit,
        'electricity': electricity,
        'water': water,
        'internet': internet,
        'parking': parking,
        'other': other,
        'otherDescription': otherDescription,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'monthlyRent': monthlyRent,
        'proratedStayDays': proratedStayDays,
        'isFinalInvoice': isFinalInvoice,
        'meter': meter?.toJson(),
        'payslip': payslip?.toJson(),
        'electricityUsageKwh': electricityUsageKwh,
      };
  factory MoveOutSettlement.fromJson(Map<String, dynamic> j) =>
      MoveOutSettlement(
        tenantName: j['tenantName'] as String,
        propertyName: j['propertyName'] as String,
        unitName: j['unitName'] as String,
        moveOutDate: DateTime.parse(j['moveOutDate'] as String),
        deposit: j['deposit'] as int,
        electricity: j['electricity'] as int,
        water: j['water'] as int,
        internet: j['internet'] as int,
        parking: j['parking'] as int,
        other: j['other'] as int,
        otherDescription: j['otherDescription'] as String? ?? '',
        bankName: j['bankName'] as String? ?? '',
        bankAccountNumber: j['bankAccountNumber'] as String? ?? '',
        monthlyRent: (j['monthlyRent'] as num?)?.toInt() ?? 0,
        proratedStayDays: (j['proratedStayDays'] as num?)?.toInt() ?? 0,
        isFinalInvoice: j['isFinalInvoice'] as bool? ?? false,
        electricityUsageKwh: (j['electricityUsageKwh'] as num?)?.toDouble(),
        meter: j['meter'] == null
            ? null
            : SettlementAttachment.fromJson(
                Map<String, dynamic>.from(j['meter'])),
        payslip: j['payslip'] == null
            ? null
            : SettlementAttachment.fromJson(
                Map<String, dynamic>.from(j['payslip'])),
      );

  MoveOutSettlement asFinalInvoice() => MoveOutSettlement(
        tenantName: tenantName,
        propertyName: propertyName,
        unitName: unitName,
        moveOutDate: moveOutDate,
        deposit: deposit,
        electricity: electricity,
        water: water,
        internet: internet,
        parking: parking,
        other: other,
        otherDescription: otherDescription,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        monthlyRent: monthlyRent,
        proratedStayDays: proratedStayDays,
        isFinalInvoice: true,
        meter: meter,
        payslip: payslip,
        electricityUsageKwh: electricityUsageKwh,
      );
}
