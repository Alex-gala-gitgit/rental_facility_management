import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'malaysia_holidays.dart';
import 'holiday_feed.dart';
import '../main.dart';
import '../persistence/app_persistence.dart';
import '../persistence/persistence_contract.dart';

class TenancyCalendarEvent {
  const TenancyCalendarEvent(this.date, this.title, this.detail, this.color,
      {this.isHoliday = false});
  final DateTime date;
  final String title;
  final String detail;
  final Color color;
  final bool isHoliday;
  Color get markerColor => isHoliday ? const Color(0xFFE11D48) : oceanDeep;
}

/// Sunday-first offset, including months that require six calendar rows.
int tenancyCalendarOffset(DateTime month) =>
    DateTime(month.year, month.month).weekday % 7;

class TenancyCalendar extends StatefulWidget {
  const TenancyCalendar({super.key, this.expanded = false});
  final bool expanded;
  @override
  State<TenancyCalendar> createState() => _TenancyCalendarState();
}

class _TenancyCalendarState extends State<TenancyCalendar>
    with WidgetsBindingObserver {
  final holidayFeed = HolidayFeed.shared;
  Timer? _holidayTimer;

  @override
  void initState() {
    super.initState();
    holidayFeed.addListener(_holidaysChanged);
    WidgetsBinding.instance.addObserver(this);
    _holidayTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted) refreshHolidays();
    });
  }

  void _holidaysChanged() {
    if (mounted) setState(() {});
  }

  void refreshHolidays() {
    if (RentalStoreScope.of(context).currentUser == null) return;
    holidayFeed.refresh(month.year);
    holidayFeed.refresh(month.year + 1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) refreshHolidays();
  }

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selected;
  AppPersistence? persistence;
  List<Map<String, dynamic>> notes = [];
  bool loaded = false;
  bool started = false;
  String? error;

  String text(String en, String zh) =>
      RentalStoreScope.of(context).appLanguage == AppLanguage.english ? en : zh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      final id = RentalStoreScope.of(context).currentUser?.id;
      if (id != null) load(id);
      refreshHolidays();
    }
  }

  Future<void> load(String id) async {
    try {
      final storage =
          persistence ?? await createAppPersistence(namespace: 'calendar_$id');
      if (!mounted) {
        await storage.close();
        return;
      }
      persistence = storage;
      final raw = await storage.readSnapshot();
      final saved = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
      if (mounted)
        setState(() {
          notes =
              saved.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          loaded = true;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = text('Events could not be loaded.', '无法加载事项。');
        });
    }
  }

  @override
  void dispose() {
    _holidayTimer?.cancel();
    holidayFeed.removeListener(_holidaysChanged);
    WidgetsBinding.instance.removeObserver(this);
    persistence?.close();
    super.dispose();
  }

  List<TenancyCalendarEvent> events() {
    final store = RentalStoreScope.of(context);
    final result = <TenancyCalendarEvent>[];
    final states = store.tenantTenancies
        .map((t) => store.facilityFor(t.facilityId).state)
        .toSet();
    for (final holiday in holidayFeed.forStates(month.year, states)) {
      final locations = states
          .where((state) => holiday.appliesTo(malaysiaHolidayStateCode(state)))
          .join(' / ');
      result.add(TenancyCalendarEvent(
          holiday.date,
          text(holiday.english, holiday.chinese),
          holiday.states.isEmpty
              ? text('Public holiday · Nationwide', '公共假日 · 全国')
              : '${text('Public holiday', '公共假日')} · $locations',
          const Color(0xFFE11D48),
          isHoliday: true));
    }
    for (final tenancy in store.tenantTenancies) {
      final unit =
          '${store.facilityFor(tenancy.facilityId).name} · ${tenancy.unitName}';
      result.add(TenancyCalendarEvent(tenancy.leaseStart,
          text('Move-in / Lease start', '入住／租约开始'), unit, oceanDeep));
      result.add(TenancyCalendarEvent(
          tenancy.lastActiveDate ?? tenancy.leaseEnd,
          tenancy.lastActiveDate != null
              ? text('Move-out date', '搬出日期')
              : text('Lease ends', '租约到期'),
          tenancy.lastActiveDate != null
              ? unit
              : '$unit · ${text('Not a confirmed move-out', '非已确认搬出日期')}',
          Colors.orange));
    }
    for (final bill in store.tenantBills) {
      final approved = bill.status == PaymentStatus.approved;
      final pending = bill.status == PaymentStatus.pendingApproval;
      if (!approved && !pending) continue;
      // Never invent a payment date from the invoice month.
      final date = bill.paymentDate ??
          bill.submittedAt ??
          (approved ? bill.reviewedAt : null);
      if (date == null) continue;
      result.add(TenancyCalendarEvent(
          date,
          approved
              ? text('Rent paid', '租金已付')
              : text('Payment awaiting review', '付款待审核'),
          '${money(bill.amountPaid > 0 ? bill.amountPaid : bill.totalAmount)} · ${approved ? text('Owner confirmed', '业主已确认') : text('Awaiting owner confirmation', '等待业主确认')}',
          approved ? const Color(0xFF169B72) : Colors.amber.shade800));
    }
    for (final request in store.currentTenantRequests) {
      final date = request.requestedMoveOutDate;
      if (date == null || request.status == 'Withdrawn') continue;
      result.add(TenancyCalendarEvent(
          date,
          text('Requested move-out', '申请搬出'),
          '${store.facilityFor(request.facilityId).name} · ${tr(context, request.status)}',
          Colors.orange));
    }
    final tenancyIds = store.tenantTenancies.map((e) => e.id).toSet();
    for (final note in notes) {
      if (!tenancyIds.contains(note['tenancyId'])) continue;
      final date = DateTime.tryParse(note['date'] as String? ?? '');
      if (date != null)
        result.add(TenancyCalendarEvent(
            date,
            note['title'] as String,
            text('Personal event · This device', '个人事项 · 此设备'),
            Colors.deepPurple));
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Future<void> addEvent() async {
    final store = RentalStoreScope.of(context);
    if (!loaded || store.tenantTenancies.isEmpty) return;
    final controller = TextEditingController();
    DateTime date = selected ?? DateTime.now();
    String tenancyId = store.tenantTenancies.first.id;
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(text('Add personal event', '添加个人事项')),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: controller,
                        maxLength: 80,
                        decoration: InputDecoration(
                            labelText: text('Event title', '事项标题'))),
                    if (store.tenantTenancies.length > 1)
                      DropdownButton<String>(
                          value: tenancyId,
                          isExpanded: true,
                          items: store.tenantTenancies
                              .map((e) => DropdownMenuItem(
                                  value: e.id, child: Text(e.unitName)))
                              .toList(),
                          onChanged: (value) =>
                              update(() => tenancyId = value!)),
                    TextButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(dateLabel(date)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null) update(() => date = picked);
                        }),
                    Text(text(
                        'Saved on this device. Not shared with your owner.',
                        '保存在此设备，不会分享给业主。')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(tr(context, 'Cancel'))),
                    FilledButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty)
                            Navigator.pop(dialogContext, true);
                        },
                        child: Text(tr(context, 'Save')))
                  ],
                )));
    final title = controller.text.trim();
    controller.dispose();
    if (saved != true || !mounted) return;
    final next = [
      ...notes,
      {'tenancyId': tenancyId, 'date': date.toIso8601String(), 'title': title}
    ];
    try {
      await persistence!.writeSnapshot(jsonEncode(next));
      if (mounted)
        setState(() {
          notes = next;
          month = DateTime(date.year, date.month);
          selected = date;
        });
    } catch (_) {
      if (mounted)
        showTenantToast(context,
            text('Event could not be saved. Please try again.', '无法保存事项，请重试。'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = events();
    final monthly = all
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();
    final visible = selected == null
        ? monthly
        : monthly.where((e) => e.date.day == selected!.day).toList();
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = tenancyCalendarOffset(month);
    return Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!widget.expanded)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        icon: const Icon(Icons.open_in_full, size: 16),
                        label: Text(text('Open calendar', '打开日历')),
                        onPressed: () async {
                          final store = RentalStoreScope.of(context);
                          await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => RentalStoreScope(
                                      store: store,
                                      child: Scaffold(
                                          backgroundColor: oceanCanvas,
                                          appBar: AppBar(
                                              title: Text(text(
                                                  'Tenancy calendar', '租住日历'))),
                                          body: const SingleChildScrollView(
                                              padding: EdgeInsets.all(16),
                                              child: TenancyCalendar(
                                                  expanded: true))))));
                          if (mounted && store.currentUser != null)
                            await load(store.currentUser!.id);
                        })),
              Row(children: [
                const Icon(Icons.calendar_month_outlined, color: oceanDeep),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(text('Tenancy calendar', '租住日历'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: text('Add event', '添加事项'),
                    onPressed: loaded &&
                            RentalStoreScope.of(context)
                                .tenantTenancies
                                .isNotEmpty
                        ? addEvent
                        : null,
                    icon:
                        const Icon(Icons.add_circle_outline, color: oceanDeep))
              ]),
              const SizedBox(height: 8),
              Container(
                key: const Key('tenancy_calendar_mint_panel'),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFAF4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                                tooltip: text('Previous month', '上个月'),
                                onPressed: () => setState(() {
                                      month =
                                          DateTime(month.year, month.month - 1);
                                      selected = null;
                                      refreshHolidays();
                                    }),
                                icon: const Icon(Icons.chevron_left)),
                            Text(
                                text(
                                    '${const [
                                      'January',
                                      'February',
                                      'March',
                                      'April',
                                      'May',
                                      'June',
                                      'July',
                                      'August',
                                      'September',
                                      'October',
                                      'November',
                                      'December'
                                    ][month.month - 1]} ${month.year}',
                                    '${month.year}年${month.month}月'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            IconButton(
                                tooltip: text('Next month', '下个月'),
                                onPressed: () => setState(() {
                                      month =
                                          DateTime(month.year, month.month + 1);
                                      selected = null;
                                      refreshHolidays();
                                    }),
                                icon: const Icon(Icons.chevron_right))
                          ]),
                      Container(
                          key: const Key('calendar_date_grid_border'),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDDE9E3)),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Stack(children: [
                            Positioned.fill(
                                child: Row(children: [
                              for (var column = 0; column < 7; column++)
                                Expanded(
                                    child: Container(
                                  key: column == 0 || column == 6
                                      ? ValueKey(
                                          'calendar_weekend_column_$column')
                                      : null,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: column == 0 || column == 6
                                        ? const Color(0xFFFFF0F2)
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                )),
                            ])),
                            Column(children: [
                              Row(children: [
                                for (final day in (RentalStoreScope.of(context)
                                            .appLanguage ==
                                        AppLanguage.english
                                    ? [
                                        'Sun',
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat'
                                      ]
                                    : ['日', '一', '二', '三', '四', '五', '六']))
                                  Expanded(
                                      child: Center(
                                          child: Text(day,
                                              style: const TextStyle(
                                                  color: oceanMuted,
                                                  fontSize: 12))))
                              ]),
                              const SizedBox(height: 8),
                              GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: ((offset + days + 6) ~/ 7) * 7,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 7,
                                          mainAxisExtent: 46),
                                  itemBuilder: (context, index) {
                                    final day = index - offset + 1;
                                    if (day < 1 || day > days)
                                      return const SizedBox.shrink();
                                    final chosen = selected?.day == day &&
                                        selected?.month == month.month &&
                                        selected?.year == month.year;
                                    final colors = monthly
                                        .where((e) => e.date.day == day)
                                        .map((e) => e.markerColor)
                                        .toSet()
                                        .take(3);
                                    return InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () => setState(() => selected =
                                            chosen
                                                ? null
                                                : DateTime(month.year,
                                                    month.month, day)),
                                        child: Column(children: [
                                          Container(
                                              width: 30,
                                              height: 30,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: chosen
                                                      ? oceanDeep
                                                      : null),
                                              child: Text('$day',
                                                  style: TextStyle(
                                                      color: chosen
                                                          ? Colors.white
                                                          : oceanText))),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                for (final color in colors)
                                                  Container(
                                                      width: 5,
                                                      height: 5,
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 1,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                          color: color,
                                                          shape:
                                                              BoxShape.circle))
                                              ])
                                        ]));
                                  }),
                            ]),
                          ])),
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 6, children: [
                        legend(oceanDeep, text('Tenancy event', '租住事项')),
                        legend(const Color(0xFFE11D48), text('Holiday', '假日')),
                      ]),
                    ]),
              ),
              const Divider(height: 28),
              Text(
                  holidayFeed.hasYear(month.year)
                      ? text(
                          '${month.year} official holidays · Auto-updates daily when online. Local replacement days may vary.',
                          '${month.year}年官方假日 · 联网时每日自动更新；当地补假可能不同。')
                      : text(
                          'Official schedule unavailable yet. The app will retry automatically.',
                          '官方假日表暂不可用，应用将自动重试。'),
                  style: const TextStyle(fontSize: 11, color: oceanMuted)),
              TextButton(
                  onPressed: () => launchUrl(Uri.parse(
                      'https://www.kabinet.gov.my/hari-kelepasan-am/')),
                  child: Text(text('Official holiday schedule', '官方假日表'))),
              Text(
                  selected == null
                      ? text('This month', '本月事项')
                      : dateLabel(selected!),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (visible.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(text('No events for these dates.', '这些日期没有事项。'),
                        style: const TextStyle(color: oceanMuted))),
              for (final event in visible)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: event.markerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${event.date.day}',
                            style: TextStyle(
                                color: event.markerColor,
                                fontWeight: FontWeight.w800))),
                    title: Text(event.title),
                    subtitle: Text(event.detail)),
            ])));
  }

  Widget legend(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: oceanMuted))
      ]);
}
