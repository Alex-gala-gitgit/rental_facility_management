import 'package:flutter/material.dart';

import '../persistence/persistence_contract.dart';
import 'nearby_share.dart';
import 'split_bill_store.dart';
import 'split_bill_text.dart';

const _splitGreen = Color(0xFF13784A);
const _splitCanvas = Color(0xFFF3F7F4);
const _splitInk = Color(0xFF17231C);
const _splitPurple = Color(0xFF7357C8);
const _splitOrange = Color(0xFFE47D35);
const _splitBlue = Color(0xFF2F79C8);
const _splitPink = Color(0xFFD85886);

const _profileColors = <Color>[
  _splitGreen,
  _splitPurple,
  _splitBlue,
  _splitOrange,
  _splitPink,
];

Color _profileColor(String seed) {
  final value = seed.codeUnits.fold<int>(0, (sum, item) => sum + item);
  return _profileColors[value % _profileColors.length];
}

Color _profileSurface(String seed) =>
    Color.lerp(_profileColor(seed), Colors.white, .84)!;

class SplitBillApp extends StatefulWidget {
  const SplitBillApp({
    super.key,
    required this.persistence,
    required this.launchUri,
  });

  final AppPersistence persistence;
  final Uri launchUri;

  @override
  State<SplitBillApp> createState() => _SplitBillAppState();
}

class _SplitBillAppState extends State<SplitBillApp> {
  late final SplitBillStore store;
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    store = SplitBillStore(persistence: widget.persistence);
    initialization = store.initialize(launchUri: widget.launchUri);
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Splitz',
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Manrope',
              colorScheme: ColorScheme.fromSeed(
                seedColor: _splitGreen,
                brightness: Brightness.light,
                surface: _splitCanvas,
              ),
              scaffoldBackgroundColor: _splitCanvas,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: _splitInk,
                surfaceTintColor: Colors.transparent,
              ),
              cardTheme: const CardTheme(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  side: BorderSide(color: Color(0xFFDCE7DF)),
                ),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            home: SplitBillHome(store: store),
          );
        },
      );
}

class SplitBillHome extends StatefulWidget {
  const SplitBillHome({super.key, required this.store});

  final SplitBillStore store;

  @override
  State<SplitBillHome> createState() => _SplitBillHomeState();
}

class _SplitBillHomeState extends State<SplitBillHome> {
  late int selectedIndex;

  SplitBillStore get store => widget.store;
  SplitBillText get text => SplitBillText(store.language);

  @override
  void initState() {
    super.initState();
    selectedIndex = store.activeEvent == null ? 4 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = store.importMessage;
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text('Imported shared data.'))),
        );
      }
    });
  }

  void goTo(int index) => setState(() => selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final pages = <Widget>[
          _BillsPage(store: store, goTo: goTo),
          _AddBillPage(store: store, onSaved: () => goTo(0)),
          _BalancesPage(store: store),
          _SettlePage(store: store, startNew: _closeAndStartNew),
          _EventsPage(store: store, openEvent: () => goTo(0)),
        ];
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                const _SplitzMark(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text('Splitz'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SegmentedButton<SplitBillLanguage>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: SplitBillLanguage.english, label: Text('EN')),
                    ButtonSegment(
                        value: SplitBillLanguage.chinese, label: Text('中')),
                  ],
                  selected: {store.language},
                  onSelectionChanged: (selection) =>
                      store.setLanguage(selection.first),
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: IndexedStack(index: selectedIndex, children: pages),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: goTo,
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined,
                      color: _splitBlue),
                  selectedIcon:
                      const Icon(Icons.receipt_long, color: _splitBlue),
                  label: text('Bills')),
              NavigationDestination(
                  icon:
                      const Icon(Icons.add_circle_outline, color: _splitOrange),
                  selectedIcon:
                      const Icon(Icons.add_circle, color: _splitOrange),
                  label: text('Add')),
              NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      color: _splitPurple),
                  selectedIcon: const Icon(Icons.account_balance_wallet,
                      color: _splitPurple),
                  label: text('Balances')),
              NavigationDestination(
                  icon:
                      const Icon(Icons.handshake_outlined, color: _splitGreen),
                  selectedIcon: const Icon(Icons.handshake, color: _splitGreen),
                  label: text('Settle')),
              NavigationDestination(
                  icon:
                      const Icon(Icons.event_note_outlined, color: _splitPink),
                  selectedIcon: const Icon(Icons.event_note, color: _splitPink),
                  label: text('Events')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _closeAndStartNew() async {
    final event = store.activeEvent;
    if (event == null) return;
    final closed = await store.closeEvent(event);
    if (!mounted) return;
    if (!closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                text('Complete every payment before closing this event.'))),
      );
      return;
    }
    setState(() => selectedIndex = 4);
    await _showCreateEventDialog(context, store);
    if (mounted && store.activeEvent != null) setState(() => selectedIndex = 0);
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: SizedBox(width: double.infinity, child: child),
      );
}

class _SplitzMark extends StatelessWidget {
  const _SplitzMark();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 42,
        height: 42,
        child: Stack(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _splitGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.call_split_rounded, color: Colors.white),
          ),
          const Positioned(
            right: 0,
            top: 2,
            child: CircleAvatar(backgroundColor: _splitPurple, radius: 5),
          ),
          const Positioned(
            right: 1,
            bottom: 1,
            child: CircleAvatar(backgroundColor: _splitOrange, radius: 4),
          ),
        ]),
      );
}

class _BillsPage extends StatelessWidget {
  const _BillsPage({required this.store, required this.goTo});
  final SplitBillStore store;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    final event = store.activeEvent;
    if (event == null) return _NoEvent(store: store);
    final paid = event.bills.fold<double>(
      0,
      (sum, bill) =>
          sum + (bill.payerContributions[event.localParticipantId] ?? 0),
    );
    final myBalance = event.balances[event.localParticipantId] ?? 0;
    return _Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(event.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        '${event.participants.length} ${text('people')} · ${event.bills.length} ${text('bills')} · MYR'),
                  ])),
              IconButton.filledTonal(
                tooltip: text('Share event'),
                onPressed: () => _shareEvent(context, store, event),
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _IdentitySelector(store: store, event: event),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _Metric(
                    label: text('Group spending'), value: _rm(event.total))),
            const SizedBox(width: 10),
            Expanded(child: _Metric(label: text('You paid'), value: _rm(paid))),
          ]),
          const SizedBox(height: 10),
          _Metric(
            label: myBalance > .009
                ? text("You'll receive")
                : myBalance < -.009
                    ? text('You need to pay')
                    : text("You're settled"),
            value: _rm(myBalance.abs()),
            emphasized: true,
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: Text(text('Bills'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))),
            TextButton.icon(
                onPressed: event.isClosed
                    ? null
                    : () => _addPerson(context, store, event),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(text('Add person'))),
          ]),
          const SizedBox(height: 8),
          if (event.bills.isEmpty)
            _EmptyCard(
                icon: Icons.receipt_long_outlined,
                title: text('No bills yet'),
                body: text('Add the first bill for this event.'),
                action: TextButton(
                    onPressed: () => goTo(1), child: Text(text('Add bill'))))
          else
            ...event.bills.reversed.map((bill) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BillCard(store: store, event: event, bill: bill),
                )),
          if (event.isClosed) ...[
            const SizedBox(height: 8),
            _Notice(
                icon: Icons.lock_outline,
                text: text('This event is closed and read-only.')),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard(
      {required this.store, required this.event, required this.bill});
  final SplitBillStore store;
  final SplitBillEvent event;
  final SplitBillEntry bill;

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    final payerNames = bill.payerContributions.keys
        .map((id) => event.participant(id)?.name ?? '—')
        .join(', ');
    final addedBy = event.participant(bill.addedById)?.name ?? '—';
    final canConfirm = !bill.payerConfirmed &&
        bill.payerContributions.containsKey(event.localParticipantId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                backgroundColor: _profileSurface(bill.description),
                foregroundColor: _profileColor(bill.description),
                child: const Icon(Icons.receipt_outlined)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(bill.description,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      '${text('Paid by')} $payerNames · ${bill.participantIds.length} ${text('people')}'),
                  if (!bill.payerContributions.containsKey(bill.addedById))
                    Text('${text('Added by')} $addedBy',
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 7),
                  if (bill.payerConfirmed)
                    _Status(text: text('Confirmed'), good: true)
                  else if (canConfirm)
                    TextButton.icon(
                        onPressed: () => store.confirmBill(event, bill.id),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(text('Confirm this bill')))
                  else
                    _Status(
                        text: text('Waiting for payer confirmation'),
                        good: false),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_rm(bill.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                  tooltip: text('Share transaction'),
                  onPressed: () => _shareBill(context, store, event, bill),
                  icon: const Icon(Icons.bluetooth_connected)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AddBillPage extends StatefulWidget {
  const _AddBillPage({required this.store, required this.onSaved});
  final SplitBillStore store;
  final VoidCallback onSaved;

  @override
  State<_AddBillPage> createState() => _AddBillPageState();
}

enum _SplitMode { equal, exact }

class _AddBillPageState extends State<_AddBillPage> {
  final description = TextEditingController();
  final amount = TextEditingController();
  final payerAmounts = <String, TextEditingController>{};
  final shareAmounts = <String, TextEditingController>{};
  final selectedPeople = <String>{};
  _SplitMode splitMode = _SplitMode.equal;

  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    for (final controller in payerAmounts.values) {
      controller.dispose();
    }
    for (final controller in shareAmounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final text = SplitBillText(store.language);
    final event = store.activeEvent;
    if (event == null) return _NoEvent(store: store);
    for (final person in event.participants) {
      payerAmounts.putIfAbsent(person.id, () => TextEditingController());
      shareAmounts.putIfAbsent(person.id, () => TextEditingController());
    }
    if (selectedPeople.isEmpty)
      selectedPeople.addAll(event.participants.map((item) => item.id));
    final numericAmount = double.tryParse(amount.text) ?? 0;
    final paidTotal = payerAmounts.values.fold<double>(
      0,
      (sum, controller) => sum + (double.tryParse(controller.text) ?? 0),
    );
    final contributionsMatch =
        numericAmount > 0 && (paidTotal - numericAmount).abs() < .009;
    final each =
        selectedPeople.isEmpty ? 0 : numericAmount / selectedPeople.length;
    final splitTotal = selectedPeople.fold<double>(
      0,
      (sum, id) => sum + (double.tryParse(shareAmounts[id]?.text ?? '') ?? 0),
    );
    final splitMatches =
        numericAmount > 0 && (splitTotal - numericAmount).abs() < .009;
    return _Page(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text('Add bill'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Card(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
                controller: description,
                enabled: !event.isClosed,
                decoration: InputDecoration(labelText: text('Description'))),
            const SizedBox(height: 12),
            TextField(
                controller: amount,
                enabled: !event.isClosed,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: text('Amount (MYR)'), prefixText: 'RM ')),
            const SizedBox(height: 12),
            Text(text('Who paid and how much'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...event.participants.map((person) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: _profileSurface(person.id),
                      foregroundColor: _profileColor(person.id),
                      child: Text(_initial(person.name),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(person.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox(
                      width: 142,
                      child: TextField(
                        controller: payerAmounts[person.id],
                        enabled: !event.isClosed,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            prefixText: 'RM ', hintText: '0.00'),
                      ),
                    ),
                  ]),
                )),
            _Notice(
              icon: contributionsMatch
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              text:
                  '${text('Paid total')}: ${_rm(paidTotal)} · ${contributionsMatch ? text('Amounts match') : text('Must equal the bill amount')}',
              color: contributionsMatch ? _splitGreen : _splitOrange,
            ),
            const SizedBox(height: 18),
            Text(text('Split with'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.participants
                    .map((person) => FilterChip(
                          label: Text(person.name),
                          selected: selectedPeople.contains(person.id),
                          onSelected: event.isClosed
                              ? null
                              : (selected) => setState(() => selected
                                  ? selectedPeople.add(person.id)
                                  : selectedPeople.remove(person.id)),
                        ))
                    .toList()),
            const SizedBox(height: 14),
            Text(text('Split method'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<_SplitMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: _SplitMode.equal, label: Text(text('Equal'))),
                ButtonSegment(
                    value: _SplitMode.exact,
                    label: Text(text('Exact amounts'))),
              ],
              selected: {splitMode},
              onSelectionChanged: event.isClosed
                  ? null
                  : (selection) => setState(() => splitMode = selection.first),
            ),
            const SizedBox(height: 14),
            if (splitMode == _SplitMode.exact)
              ...event.participants
                  .where((person) => selectedPeople.contains(person.id))
                  .map((person) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: _profileSurface(person.id),
                            foregroundColor: _profileColor(person.id),
                            child: Text(_initial(person.name),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(person.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          SizedBox(
                            width: 142,
                            child: TextField(
                              controller: shareAmounts[person.id],
                              enabled: !event.isClosed,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  labelText: text('Amount owed'),
                                  prefixText: 'RM ',
                                  hintText: '0.00'),
                            ),
                          ),
                        ]),
                      )),
            _Notice(
              icon: splitMode == _SplitMode.equal
                  ? Icons.calculate_outlined
                  : splitMatches
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              text: splitMode == _SplitMode.equal
                  ? '${text('Each person')}: ${_rm(each)}'
                  : '${text('Split total')}: ${_rm(splitTotal)} · ${splitMatches ? text('Amounts match') : text('Must equal the bill amount')}',
              color: splitMode == _SplitMode.equal || splitMatches
                  ? _splitGreen
                  : _splitOrange,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: event.isClosed ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(text('Save bill'))),
          ]),
        )),
        const SizedBox(height: 80),
      ]),
    );
  }

  Future<void> _save() async {
    final text = SplitBillText(widget.store.language);
    final event = widget.store.activeEvent!;
    final parsedAmount = double.tryParse(amount.text);
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text('Enter a valid amount.'))));
      return;
    }
    if (selectedPeople.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text('Select at least one person.'))));
      return;
    }
    final contributions = <String, double>{};
    for (final entry in payerAmounts.entries) {
      final value = double.tryParse(entry.value.text) ?? 0;
      if (value > 0) contributions[entry.key] = value;
    }
    final paidTotal = contributions.values
        .fold<double>(0, (sum, contribution) => sum + contribution);
    if (contributions.isEmpty || (paidTotal - parsedAmount).abs() > .009) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text('Payer amounts must equal the bill amount.'))));
      return;
    }
    Map<String, double>? participantShares;
    if (splitMode == _SplitMode.exact) {
      participantShares = <String, double>{};
      for (final id in selectedPeople) {
        final value = double.tryParse(shareAmounts[id]?.text ?? '') ?? 0;
        if (value > 0) participantShares[id] = value;
      }
      final splitTotal =
          participantShares.values.fold<double>(0, (sum, share) => sum + share);
      if (participantShares.isEmpty ||
          (splitTotal - parsedAmount).abs() > .009) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(text('Split amounts must equal the bill amount.'))));
        return;
      }
    }
    final bill = await widget.store.addBill(
        event: event,
        description: description.text,
        amount: parsedAmount,
        payerId: contributions.keys.first,
        payerContributions: contributions,
        participantIds: selectedPeople.toList(),
        participantShares: participantShares);
    if (!mounted || bill == null) return;
    description.clear();
    amount.clear();
    for (final controller in payerAmounts.values) {
      controller.clear();
    }
    for (final controller in shareAmounts.values) {
      controller.clear();
    }
    splitMode = _SplitMode.equal;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text('Bill saved.'))));
    widget.onSaved();
  }
}

class _BalancesPage extends StatelessWidget {
  const _BalancesPage({required this.store});
  final SplitBillStore store;

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    final event = store.activeEvent;
    if (event == null) return _NoEvent(store: store);
    return _Page(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text('Net balances'),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      ...event.participants.map((person) {
        final balance = event.balances[person.id] ?? 0;
        final label = balance > .009
            ? text('gets')
            : balance < -.009
                ? text('owes')
                : text('settled');
        return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
                child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: _profileSurface(person.id),
                  foregroundColor: _profileColor(person.id),
                  child: Text(_initial(person.name))),
              title: Text(person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(
                  balance.abs() < .009 ? label : '$label ${_rm(balance.abs())}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: balance > .009 ? _splitGreen : null)),
            )));
      }),
      const SizedBox(height: 80),
    ]));
  }
}

class _SettlePage extends StatelessWidget {
  const _SettlePage({required this.store, required this.startNew});
  final SplitBillStore store;
  final Future<void> Function() startNew;

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    final event = store.activeEvent;
    if (event == null) return _NoEvent(store: store);
    final settlements = event.settlements;
    return _Page(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text('Who pays whom'),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      if (settlements.isEmpty)
        _EmptyCard(
            icon: Icons.check_circle_outline,
            title: text("You're settled"),
            body: text('No payments are needed.'))
      else
        ...settlements.map((settlement) {
          final paid = event.clearedSettlementKeys.contains(settlement.key);
          final from = event.participant(settlement.fromId)?.name ?? '—';
          final to = event.participant(settlement.toId)?.name ?? '—';
          return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        CircleAvatar(
                            backgroundColor: _profileSurface(settlement.fromId),
                            foregroundColor: _profileColor(settlement.fromId),
                            child: Text(_initial(from))),
                        const SizedBox(width: 9),
                        Expanded(
                            child: Text('$from ${text('pays')} $to',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        Text(_rm(settlement.amount),
                            style: const TextStyle(fontWeight: FontWeight.w800))
                      ]),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          onPressed: paid || event.isClosed
                              ? null
                              : () =>
                                  store.markSettlementPaid(event, settlement),
                          icon: Icon(paid
                              ? Icons.check_circle
                              : Icons.payments_outlined),
                          label: Text(paid ? text('Paid') : text('Mark paid'))),
                    ]),
              )));
        }),
      const SizedBox(height: 14),
      if (!event.isClosed)
        FilledButton.icon(
            onPressed: event.canClose ? startNew : null,
            icon: const Icon(Icons.event_available),
            label: Text(text('Close event & start new'))),
      if (!event.isClosed && !event.canClose)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                text('Complete every payment before closing this event.'),
                textAlign: TextAlign.center)),
      if (event.isClosed)
        _Notice(
            icon: Icons.lock_outline,
            text: text('This event is closed and read-only.')),
      const SizedBox(height: 80),
    ]));
  }
}

class _EventsPage extends StatelessWidget {
  const _EventsPage({required this.store, required this.openEvent});
  final SplitBillStore store;
  final VoidCallback openEvent;

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    return _Page(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text('Manage events'),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(text('Each event keeps separate people, bills and balances.')),
        ])),
        IconButton.filled(
            onPressed: () => _showCreateEventDialog(context, store),
            icon: const Icon(Icons.add))
      ]),
      const SizedBox(height: 16),
      if (store.events.isEmpty)
        _EmptyCard(
            icon: Icons.event_note_outlined,
            title: text('No active event'),
            body: text('Create an event before adding people and bills.'),
            action: FilledButton(
                onPressed: () => _showCreateEventDialog(context, store),
                child: Text(text('Create event'))))
      else
        ...store.events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(event.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    '${event.participants.length} ${text('people')} · ${event.bills.length} ${text('bills')} · ${_rm(event.total)}')
                              ])),
                          _Status(
                              text: text(event.isClosed ? 'Settled' : 'Active'),
                              good: !event.isClosed)
                        ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () async {
                                await store.selectEvent(event.id);
                                openEvent();
                              },
                              child: Text(
                                  text(event.isClosed ? 'View' : 'Open')))),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                          tooltip: text('Share event'),
                          onPressed: () => _shareEvent(context, store, event),
                          icon: const Icon(Icons.ios_share))
                    ]),
                  ]),
            )))),
      const SizedBox(height: 80),
    ]));
  }
}

class _IdentitySelector extends StatelessWidget {
  const _IdentitySelector({required this.store, required this.event});
  final SplitBillStore store;
  final SplitBillEvent event;

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.phone_android, color: _splitGreen),
              const SizedBox(width: 10),
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: event.localParticipantId,
                decoration: InputDecoration(
                    labelText: text('You are'),
                    helperText: text('Choose your name on this device.'),
                    isDense: true),
                items: event.participants
                    .map((person) => DropdownMenuItem(
                        value: person.id, child: Text(person.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) store.setLocalParticipant(event, value);
                },
              )),
            ])));
  }
}

class _NoEvent extends StatelessWidget {
  const _NoEvent({required this.store});
  final SplitBillStore store;
  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(store.language);
    return _Page(
        child: _EmptyCard(
            icon: Icons.event_busy_outlined,
            title: text('No active event'),
            body: text('Create an event before adding people and bills.'),
            action: FilledButton(
                onPressed: () => _showCreateEventDialog(context, store),
                child: Text(text('Create event')))));
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: emphasized ? _splitGreen : Colors.black54)),
            const SizedBox(height: 5),
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: emphasized ? _splitGreen : _splitInk))
          ])));
}

class _Status extends StatelessWidget {
  const _Status({required this.text, required this.good});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: good ? const Color(0xFFE0F1E6) : const Color(0xFFFFF1D8),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  good ? const Color(0xFF13653C) : const Color(0xFF865C0B))));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final accent = color ?? _splitGreen;
    return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: Color.lerp(accent, Colors.white, .88),
            borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          Icon(icon, color: accent),
          const SizedBox(width: 9),
          Expanded(child: Text(text))
        ]));
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(
      {required this.icon,
      required this.title,
      required this.body,
      this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(icon, size: 42, color: _splitGreen),
            const SizedBox(height: 10),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 14), action!]
          ])));
}

Future<void> _showCreateEventDialog(
        BuildContext context, SplitBillStore store) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CreateEventDialog(store: store),
    );

Future<void> _addPerson(
        BuildContext context, SplitBillStore store, SplitBillEvent event) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AddPersonDialog(store: store, event: event),
    );

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.store});

  final SplitBillStore store;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final eventName = TextEditingController();
  final ownerName = TextEditingController();

  @override
  void dispose() {
    eventName.dispose();
    ownerName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(widget.store.language);
    return AlertDialog(
      title: Text(text('Create event')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: eventName,
            autofocus: true,
            decoration: InputDecoration(labelText: text('Event name'))),
        const SizedBox(height: 12),
        TextField(
            controller: ownerName,
            decoration:
                InputDecoration(labelText: text('Your name on this device'))),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text('Cancel'))),
        FilledButton(
            onPressed: () async {
              if (eventName.text.trim().isEmpty ||
                  ownerName.text.trim().isEmpty) return;
              await widget.store.createEvent(
                  name: eventName.text,
                  ownerName: ownerName.text,
                  date: DateTime.now());
              if (mounted) Navigator.pop(context);
            },
            child: Text(text('Create'))),
      ],
    );
  }
}

class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog({required this.store, required this.event});

  final SplitBillStore store;
  final SplitBillEvent event;

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = SplitBillText(widget.store.language);
    return AlertDialog(
      title: Text(text('Add person')),
      content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: text('Person name'))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text('Cancel'))),
        FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await widget.store.addParticipant(widget.event, controller.text);
              if (mounted) Navigator.pop(context);
            },
            child: Text(text('Add person'))),
      ],
    );
  }
}

Future<void> _shareEvent(
    BuildContext context, SplitBillStore store, SplitBillEvent event) async {
  final text = SplitBillText(store.language);
  final shared = await shareSplitBillLink(
      title: event.name,
      text: '${text('Share event')}: ${event.name}',
      uri: store.shareEventUri(Uri.base, event));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text(shared
          ? 'Nearby sharing opened.'
          : 'Link copied. Choose Bluetooth or Nearby Share when available.'))));
}

Future<void> _shareBill(BuildContext context, SplitBillStore store,
    SplitBillEvent event, SplitBillEntry bill) async {
  final text = SplitBillText(store.language);
  final shared = await shareSplitBillLink(
      title: bill.description,
      text: '${bill.description} · ${_rm(bill.amount)}',
      uri: store.shareBillUri(Uri.base, event, bill));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text(shared
          ? 'Nearby sharing opened.'
          : 'Link copied. Choose Bluetooth or Nearby Share when available.'))));
}

String _rm(num amount) => 'RM ${amount.toStringAsFixed(2)}';
String _initial(String name) =>
    name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
