import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../persistence/persistence_contract.dart';

enum SplitBillLanguage { english, chinese }

double _money(num value) => (value * 100).round() / 100;

Map<String, double> _equalShares(double amount, List<String> participantIds) {
  if (participantIds.isEmpty) return const <String, double>{};
  final cents = (amount * 100).round();
  final baseCents = cents ~/ participantIds.length;
  final remainder = cents % participantIds.length;
  return <String, double>{
    for (var index = 0; index < participantIds.length; index++)
      participantIds[index]: (baseCents + (index < remainder ? 1 : 0)) / 100,
  };
}

String _newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(999999)}';

class SplitParticipant {
  const SplitParticipant({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory SplitParticipant.fromJson(Map<String, dynamic> json) =>
      SplitParticipant(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class SplitBillEntry {
  SplitBillEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.payerId,
    Map<String, double>? payerContributions,
    required this.addedById,
    required this.participantIds,
    Map<String, double>? participantShares,
    required this.createdAt,
    required this.payerConfirmed,
  })  : payerContributions = Map<String, double>.unmodifiable(
          payerContributions ?? <String, double>{payerId: amount},
        ),
        participantShares = Map<String, double>.unmodifiable(
          participantShares ?? _equalShares(amount, participantIds),
        );

  final String id;
  final String description;
  final double amount;
  final String payerId;
  final Map<String, double> payerContributions;
  final String addedById;
  final List<String> participantIds;
  final Map<String, double> participantShares;
  final DateTime createdAt;
  final bool payerConfirmed;

  SplitBillEntry copyWith({bool? payerConfirmed}) => SplitBillEntry(
        id: id,
        description: description,
        amount: amount,
        payerId: payerId,
        payerContributions: payerContributions,
        addedById: addedById,
        participantIds: participantIds,
        participantShares: participantShares,
        createdAt: createdAt,
        payerConfirmed: payerConfirmed ?? this.payerConfirmed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'payerId': payerId,
        'payerContributions': payerContributions,
        'addedById': addedById,
        'participantIds': participantIds,
        'participantShares': participantShares,
        'createdAt': createdAt.toIso8601String(),
        'payerConfirmed': payerConfirmed,
      };

  factory SplitBillEntry.fromJson(Map<String, dynamic> json) {
    final payerId = json['payerId'] as String;
    final amount = (json['amount'] as num).toDouble();
    final rawContributions = json['payerContributions'];
    final participantIds = List<String>.from(json['participantIds'] as List);
    final rawShares = json['participantShares'];
    return SplitBillEntry(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: amount,
      payerId: payerId,
      payerContributions: rawContributions is Map
          ? rawContributions.map((key, value) =>
              MapEntry(key.toString(), (value as num).toDouble()))
          : <String, double>{payerId: amount},
      addedById: json['addedById'] as String,
      participantIds: participantIds,
      participantShares: rawShares is Map
          ? rawShares.map((key, value) =>
              MapEntry(key.toString(), (value as num).toDouble()))
          : _equalShares(amount, participantIds),
      createdAt: DateTime.parse(json['createdAt'] as String),
      payerConfirmed: json['payerConfirmed'] as bool? ?? false,
    );
  }
}

class SplitSettlement {
  const SplitSettlement({
    required this.fromId,
    required this.toId,
    required this.amount,
  });

  final String fromId;
  final String toId;
  final double amount;

  String get key => '$fromId>$toId:${amount.toStringAsFixed(2)}';
}

class SplitBillEvent {
  SplitBillEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.createdAt,
    required this.localParticipantId,
    required List<SplitParticipant> participants,
    List<SplitBillEntry>? bills,
    Set<String>? clearedSettlementKeys,
    this.closedAt,
  })  : participants = participants,
        bills = bills ?? <SplitBillEntry>[],
        clearedSettlementKeys = clearedSettlementKeys ?? <String>{};

  final String id;
  final String name;
  final DateTime date;
  final DateTime createdAt;
  String localParticipantId;
  final List<SplitParticipant> participants;
  final List<SplitBillEntry> bills;
  final Set<String> clearedSettlementKeys;
  DateTime? closedAt;

  bool get isClosed => closedAt != null;
  double get total =>
      _money(bills.fold<double>(0, (sum, bill) => sum + bill.amount));

  SplitParticipant? participant(String id) {
    for (final item in participants) {
      if (item.id == id) return item;
    }
    return null;
  }

  Map<String, double> get balances {
    final result = <String, double>{
      for (final participant in participants) participant.id: 0,
    };
    for (final bill in bills) {
      if (bill.participantIds.isEmpty) {
        continue;
      }
      for (final contribution in bill.payerContributions.entries) {
        if (result.containsKey(contribution.key)) {
          result[contribution.key] =
              (result[contribution.key] ?? 0) + contribution.value;
        }
      }
      for (final share in bill.participantShares.entries) {
        if (result.containsKey(share.key)) {
          result[share.key] = (result[share.key] ?? 0) - share.value;
        }
      }
    }
    return result.map((key, value) => MapEntry(key, _money(value)));
  }

  List<SplitSettlement> get settlements => calculateSettlements(balances);

  bool get canClose =>
      bills.isNotEmpty &&
      settlements.every((item) => clearedSettlementKeys.contains(item.key));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'localParticipantId': localParticipantId,
        'participants': participants.map((item) => item.toJson()).toList(),
        'bills': bills.map((item) => item.toJson()).toList(),
        'clearedSettlementKeys': clearedSettlementKeys.toList(),
        'closedAt': closedAt?.toIso8601String(),
      };

  factory SplitBillEvent.fromJson(Map<String, dynamic> json) => SplitBillEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        date: DateTime.parse(json['date'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        localParticipantId: json['localParticipantId'] as String,
        participants: (json['participants'] as List)
            .map((item) => SplitParticipant.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        bills: (json['bills'] as List? ?? const [])
            .map((item) =>
                SplitBillEntry.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        clearedSettlementKeys: Set<String>.from(
            json['clearedSettlementKeys'] as List? ?? const []),
        closedAt: json['closedAt'] == null
            ? null
            : DateTime.parse(json['closedAt'] as String),
      );
}

List<SplitSettlement> calculateSettlements(Map<String, double> balances) {
  final debtors = balances.entries
      .where((entry) => entry.value < -0.009)
      .map((entry) => MapEntry(entry.key, -entry.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final creditors = balances.entries
      .where((entry) => entry.value > 0.009)
      .map((entry) => MapEntry(entry.key, entry.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final result = <SplitSettlement>[];
  var debtorIndex = 0;
  var creditorIndex = 0;
  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    final debtor = debtors[debtorIndex];
    final creditor = creditors[creditorIndex];
    final amount = _money(math.min(debtor.value, creditor.value));
    if (amount > 0) {
      result.add(SplitSettlement(
        fromId: debtor.key,
        toId: creditor.key,
        amount: amount,
      ));
    }
    final debtLeft = _money(debtor.value - amount);
    final creditLeft = _money(creditor.value - amount);
    debtors[debtorIndex] = MapEntry(debtor.key, debtLeft);
    creditors[creditorIndex] = MapEntry(creditor.key, creditLeft);
    if (debtLeft <= 0.009) debtorIndex++;
    if (creditLeft <= 0.009) creditorIndex++;
  }
  return result;
}

class SplitBillStore extends ChangeNotifier {
  SplitBillStore({required AppPersistence persistence})
      : _persistence = persistence;

  static const _schemaVersion = 3;
  final AppPersistence _persistence;
  final List<SplitBillEvent> _events = <SplitBillEvent>[];
  SplitBillLanguage language = SplitBillLanguage.english;
  String? activeEventId;
  bool initialized = false;
  String? importMessage;

  List<SplitBillEvent> get events {
    final copy = List<SplitBillEvent>.from(_events);
    copy.sort((a, b) {
      if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
      return b.date.compareTo(a.date);
    });
    return copy;
  }

  SplitBillEvent? get activeEvent {
    for (final event in _events) {
      if (event.id == activeEventId) return event;
    }
    return _events.where((event) => !event.isClosed).firstOrNull;
  }

  Future<void> initialize({Uri? launchUri}) async {
    final snapshot = await _persistence.readSnapshot();
    if (snapshot != null && snapshot.isNotEmpty) {
      try {
        final json = jsonDecode(snapshot) as Map<String, dynamic>;
        language = SplitBillLanguage.values.firstWhere(
          (item) => item.name == json['language'],
          orElse: () => SplitBillLanguage.english,
        );
        activeEventId = json['activeEventId'] as String?;
        _events.addAll((json['events'] as List? ?? const []).map((item) =>
            SplitBillEvent.fromJson(Map<String, dynamic>.from(item as Map))));
      } catch (_) {
        _events.clear();
      }
    }
    if (launchUri != null) await _importFromUri(launchUri);
    initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(SplitBillLanguage value) async {
    language = value;
    notifyListeners();
    await _save();
  }

  Future<SplitBillEvent> createEvent({
    required String name,
    required String ownerName,
    required DateTime date,
  }) async {
    final participant = SplitParticipant(
      id: _newId('person'),
      name: ownerName.trim(),
    );
    final event = SplitBillEvent(
      id: _newId('event'),
      name: name.trim(),
      date: date,
      createdAt: DateTime.now(),
      localParticipantId: participant.id,
      participants: <SplitParticipant>[participant],
    );
    _events.add(event);
    activeEventId = event.id;
    notifyListeners();
    await _save();
    return event;
  }

  Future<void> selectEvent(String eventId) async {
    activeEventId = eventId;
    notifyListeners();
    await _save();
  }

  Future<void> setLocalParticipant(
      SplitBillEvent event, String participantId) async {
    if (event.participant(participantId) == null) return;
    event.localParticipantId = participantId;
    notifyListeners();
    await _save();
  }

  Future<void> addParticipant(SplitBillEvent event, String name) async {
    if (event.isClosed || name.trim().isEmpty) return;
    event.participants
        .add(SplitParticipant(id: _newId('person'), name: name.trim()));
    notifyListeners();
    await _save();
  }

  Future<SplitBillEntry?> addBill({
    required SplitBillEvent event,
    required String description,
    required double amount,
    required String payerId,
    Map<String, double>? payerContributions,
    required List<String> participantIds,
    Map<String, double>? participantShares,
  }) async {
    final contributions = (payerContributions ??
            <String, double>{payerId: amount})
        .map((key, value) => MapEntry(key, _money(value)))
      ..removeWhere((key, value) => value <= 0);
    final paidTotal = _money(
        contributions.values.fold<double>(0, (sum, value) => sum + value));
    final shares = (participantShares ?? _equalShares(amount, participantIds))
        .map((key, value) => MapEntry(key, _money(value)))
      ..removeWhere((key, value) => value <= 0);
    final splitTotal =
        _money(shares.values.fold<double>(0, (sum, value) => sum + value));
    if (event.isClosed ||
        description.trim().isEmpty ||
        amount <= 0 ||
        contributions.isEmpty ||
        (paidTotal - _money(amount)).abs() > 0.009 ||
        contributions.keys.any((id) => event.participant(id) == null) ||
        participantIds.isEmpty ||
        shares.isEmpty ||
        (splitTotal - _money(amount)).abs() > 0.009 ||
        shares.keys.any((id) => event.participant(id) == null)) {
      return null;
    }
    final primaryPayerId = contributions.entries
        .reduce((left, right) => left.value >= right.value ? left : right)
        .key;
    final bill = SplitBillEntry(
      id: _newId('bill'),
      description: description.trim(),
      amount: _money(amount),
      payerId: primaryPayerId,
      payerContributions: contributions,
      addedById: event.localParticipantId,
      participantIds: List<String>.from(shares.keys),
      participantShares: shares,
      createdAt: DateTime.now(),
      payerConfirmed: contributions.containsKey(event.localParticipantId),
    );
    event.bills.add(bill);
    event.clearedSettlementKeys.clear();
    notifyListeners();
    await _save();
    return bill;
  }

  Future<void> confirmBill(SplitBillEvent event, String billId) async {
    final index = event.bills.indexWhere((bill) => bill.id == billId);
    if (index < 0 ||
        !event.bills[index].payerContributions
            .containsKey(event.localParticipantId)) {
      return;
    }
    event.bills[index] = event.bills[index].copyWith(payerConfirmed: true);
    notifyListeners();
    await _save();
  }

  Future<void> markSettlementPaid(
      SplitBillEvent event, SplitSettlement settlement) async {
    if (event.isClosed) return;
    event.clearedSettlementKeys.add(settlement.key);
    notifyListeners();
    await _save();
  }

  Future<bool> closeEvent(SplitBillEvent event) async {
    if (event.isClosed || !event.canClose) return false;
    event.closedAt = DateTime.now();
    if (activeEventId == event.id) activeEventId = null;
    notifyListeners();
    await _save();
    return true;
  }

  Uri shareBillUri(Uri baseUri, SplitBillEvent event, SplitBillEntry bill) {
    final payload = {
      'kind': 'split_bill_entry',
      'event': {
        'id': event.id,
        'name': event.name,
        'date': event.date.toIso8601String(),
        'participants':
            event.participants.map((item) => item.toJson()).toList(),
      },
      'bill': bill.toJson(),
    };
    return _shareUri(baseUri, payload);
  }

  Uri shareEventUri(Uri baseUri, SplitBillEvent event) =>
      _shareUri(baseUri, {'kind': 'split_bill_event', 'event': event.toJson()});

  Uri _shareUri(Uri baseUri, Map<String, dynamic> payload) {
    final encoded =
        base64UrlEncode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
    return baseUri.replace(
      path: '/splitz/',
      queryParameters: {'import': encoded},
      fragment: '',
    );
  }

  Future<void> _importFromUri(Uri uri) async {
    final encoded = uri.queryParameters['import'];
    if (encoded == null || encoded.isEmpty) return;
    try {
      final padded = encoded.padRight(
          encoded.length + ((4 - encoded.length % 4) % 4), '=');
      final payload = jsonDecode(utf8.decode(base64Url.decode(padded)))
          as Map<String, dynamic>;
      final kind = payload['kind'];
      if (kind == 'split_bill_event') {
        final incoming = SplitBillEvent.fromJson(
            Map<String, dynamic>.from(payload['event'] as Map));
        final existing = _events.indexWhere((item) => item.id == incoming.id);
        if (existing < 0) {
          _events.add(incoming);
        } else {
          _mergeEvent(_events[existing], incoming);
        }
        activeEventId = incoming.id;
        importMessage = 'Event imported';
      } else if (kind == 'split_bill_entry') {
        final eventJson = Map<String, dynamic>.from(payload['event'] as Map);
        final bill = SplitBillEntry.fromJson(
            Map<String, dynamic>.from(payload['bill'] as Map));
        var event =
            _events.where((item) => item.id == eventJson['id']).firstOrNull;
        if (event == null) {
          final participants = (eventJson['participants'] as List)
              .map((item) => SplitParticipant.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
          final localParticipant = participants.first;
          event = SplitBillEvent(
            id: eventJson['id'] as String,
            name: eventJson['name'] as String,
            date: DateTime.parse(eventJson['date'] as String),
            createdAt: DateTime.now(),
            localParticipantId: localParticipant.id,
            participants: participants,
          );
          _events.add(event);
        }
        if (event.bills.every((item) => item.id != bill.id)) {
          event.bills.add(bill);
        }
        activeEventId = event.id;
        importMessage = 'Transaction imported';
      }
      await _save();
    } catch (_) {
      importMessage = 'Could not import this shared link';
    }
  }

  void _mergeEvent(SplitBillEvent target, SplitBillEvent incoming) {
    for (final participant in incoming.participants) {
      if (target.participants.every((item) => item.id != participant.id)) {
        target.participants.add(participant);
      }
    }
    for (final bill in incoming.bills) {
      if (target.bills.every((item) => item.id != bill.id))
        target.bills.add(bill);
    }
  }

  Future<void> _save() => _persistence.writeSnapshot(jsonEncode({
        'schemaVersion': _schemaVersion,
        'language': language.name,
        'activeEventId': activeEventId,
        'events': _events.map((item) => item.toJson()).toList(),
      }));

  @override
  void dispose() {
    _persistence.close();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
