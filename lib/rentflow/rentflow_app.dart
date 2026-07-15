import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../file_upload/payment_proof_picker.dart';
import '../pdf_open/pdf_document_opener.dart';

const _blue = Color(0xFF2563EB);
const _sky = Color(0xFF38BDF8);
const _canvas = Color(0xFFF4F7FB);
const _label = Color(0xFF0F172A);
const _secondary = Color(0xFF64748B);
const tenantPortalBaseUrl = 'https://facility-billing-management.pages.dev/';

Uri tenantInvoiceLink(String invoiceId) => Uri.parse(tenantPortalBaseUrl)
    .replace(queryParameters: {'invoice': invoiceId}, fragment: '');

class RentFlowApp extends StatefulWidget {
  const RentFlowApp({super.key});

  @override
  State<RentFlowApp> createState() => _RentFlowAppState();
}

/// Invoice workspace embedded inside the original owner application.
class RentFlowInvoiceCenter extends StatefulWidget {
  const RentFlowInvoiceCenter({super.key});

  @override
  State<RentFlowInvoiceCenter> createState() => _RentFlowInvoiceCenterState();
}

class _RentFlowInvoiceCenterState extends State<RentFlowInvoiceCenter> {
  final store = RentFlowStore();

  @override
  Widget build(BuildContext context) => RentFlowScope(
        store: store,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) => const Column(
            children: [
              TestModeBanner(),
              Expanded(child: BillingPage()),
            ],
          ),
        ),
      );
}

class _RentFlowAppState extends State<RentFlowApp> {
  final store = RentFlowStore();

  @override
  Widget build(BuildContext context) {
    final invoiceId = Uri.base.queryParameters['invoice'];
    return RentFlowScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'RentFlow',
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Outfit',
            scaffoldBackgroundColor: _canvas,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _blue,
              primary: _blue,
              surface: Colors.white,
            ),
            textTheme: ThemeData.light().textTheme.apply(
                  fontFamily: 'Outfit',
                  bodyColor: _label,
                  displayColor: _label,
                ),
            cardTheme: CardTheme(
              elevation: 0,
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0x12000000)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF7F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          home: invoiceId == null
              ? const OwnerShell()
              : TenantInvoicePage(invoiceId: invoiceId),
        ),
      ),
    );
  }
}

enum InvoiceStatus { draft, sent, slipSubmitted, paid }

class TenantAccount {
  const TenantAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.property,
    required this.unit,
    required this.rent,
    required this.water,
    required this.internet,
  });
  final String id;
  final String name;
  final String email;
  final String phone;
  final String property;
  final String unit;
  final double rent;
  final double water;
  final double internet;
}

class RentalInvoice {
  RentalInvoice({
    required this.id,
    required this.tenant,
    required this.period,
    required this.usagePeriod,
    required this.previousReading,
    required this.currentReading,
    required this.evidenceName,
    this.evidencePath,
    this.evidenceBytes,
    this.generalElectricAmount = 0,
    this.parkingRentalAmount = 0,
    this.electricityTariffName = 'TNB default tariff',
    this.electricityRatePerKwh = 0.516,
    this.electricityAmountOverride,
    this.electricityTariffSummary,
    required this.dueDate,
    this.status = InvoiceStatus.sent,
    this.slipName,
    this.slipPath,
  });
  final String id;
  final TenantAccount tenant;
  final String period;
  final String usagePeriod;
  final double previousReading;
  final double currentReading;
  final String evidenceName;
  final String? evidencePath;
  final Uint8List? evidenceBytes;
  final double generalElectricAmount;
  final double parkingRentalAmount;
  final String electricityTariffName;
  final double electricityRatePerKwh;
  final double? electricityAmountOverride;
  final String? electricityTariffSummary;
  final DateTime dueDate;
  InvoiceStatus status;
  String? slipName;
  String? slipPath;

  double get usage => math.max(0, currentReading - previousReading);
  double get electricity =>
      electricityAmountOverride ??
      (usage * electricityRatePerKwh * 100).round() / 100;
  double get total =>
      tenant.rent +
      tenant.water +
      tenant.internet +
      generalElectricAmount +
      electricity +
      parkingRentalAmount;
}

class RentFlowStore extends ChangeNotifier {
  static const bucket = 'rentflow-test-files';
  final SupabaseClient _cloud = Supabase.instance.client;
  bool loading = true;
  String? error;

  final tenants = const [
    TenantAccount(
      id: 'tenant_1',
      name: 'Nur Aisyah Binti Rahman',
      email: 'tenant1a@example.com',
      phone: '+60165666878',
      property: 'Facility 1',
      unit: 'Room A',
      rent: 1200,
      water: 0,
      internet: 0,
    ),
    TenantAccount(
      id: 'tenant_2',
      name: 'Daniel Lim Wei Jian',
      email: 'tenant1b@example.com',
      phone: '60198765432',
      property: 'Facility 1',
      unit: 'Room B',
      rent: 600,
      water: 25,
      internet: 0,
    ),
    TenantAccount(
      id: 'tenant_3',
      name: 'Mei Lin Tan',
      email: 'tenant2@example.com',
      phone: '601122334455',
      property: 'Facility 2',
      unit: 'Unit 12-3',
      rent: 950,
      water: 0,
      internet: 0,
    ),
    TenantAccount(
      id: 'tenant_4',
      name: 'Arif Hakim',
      email: 'tenant3@example.com',
      phone: '601177889900',
      property: 'Facility 3',
      unit: 'Studio 8A',
      rent: 1100,
      water: 30,
      internet: 0,
    ),
  ];

  final invoices = <RentalInvoice>[];
  final notifications = <String>[];

  RentFlowStore() {
    loadInvoices();
    _cloud
        .channel('rentflow-public-test')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rentflow_test_invoices',
          callback: (_) => loadInvoices(),
        )
        .subscribe();
  }

  TenantAccount _tenantFromRow(Map<String, dynamic> row) => TenantAccount(
        id: row['tenant_id'] as String,
        name: row['tenant_name'] as String,
        email: row['tenant_email'] as String,
        phone: row['tenant_phone'] as String,
        property: row['property_name'] as String,
        unit: row['unit_name'] as String,
        rent: (row['rent'] as num).toDouble(),
        water: (row['water'] as num).toDouble(),
        internet: (row['internet'] as num).toDouble(),
      );

  Future<void> loadInvoices() async {
    try {
      final rows = await _cloud
          .from('rentflow_test_invoices')
          .select()
          .order('created_at', ascending: false);
      invoices
        ..clear()
        ..addAll(rows.map((row) => RentalInvoice(
              id: row['id'] as String,
              tenant: _tenantFromRow(row),
              period: row['period'] as String,
              usagePeriod: row['usage_period'] as String,
              previousReading: (row['previous_reading'] as num).toDouble(),
              currentReading: (row['current_reading'] as num).toDouble(),
              evidenceName: row['evidence_name'] as String,
              evidencePath: row['evidence_path'] as String?,
              dueDate: DateTime.parse(row['due_date'] as String),
              status: InvoiceStatus.values.byName(row['status'] as String),
              slipName: row['slip_name'] as String?,
              slipPath: row['slip_path'] as String?,
            )));
      error = null;
    } catch (e) {
      error = 'Cloud test workspace is not ready: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  RentalInvoice? invoice(String id) {
    for (final item in invoices) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<RentalInvoice> createInvoice({
    required TenantAccount tenant,
    required double previous,
    required double current,
    required String evidence,
    required Uint8List evidenceBytes,
  }) async {
    final id = 'RF-${DateTime.now().millisecondsSinceEpoch}';
    final evidencePath = 'meter/$id/${_safeName(evidence)}';
    await _cloud.storage.from(bucket).uploadBinary(
          evidencePath,
          evidenceBytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final item = RentalInvoice(
      id: id,
      tenant: tenant,
      period: 'July 2026',
      usagePeriod: 'June 2026',
      previousReading: previous,
      currentReading: current,
      evidenceName: evidence,
      evidencePath: evidencePath,
      dueDate: DateTime.now().add(const Duration(days: 3)),
    );
    await _cloud.from('rentflow_test_invoices').insert({
      'id': item.id,
      'tenant_id': tenant.id,
      'tenant_name': tenant.name,
      'tenant_email': tenant.email,
      'tenant_phone': tenant.phone,
      'property_name': tenant.property,
      'unit_name': tenant.unit,
      'rent': tenant.rent,
      'water': tenant.water,
      'internet': tenant.internet,
      'period': item.period,
      'usage_period': item.usagePeriod,
      'previous_reading': previous,
      'current_reading': current,
      'evidence_name': evidence,
      'evidence_path': evidencePath,
      'due_date': item.dueDate.toIso8601String(),
      'status': item.status.name,
    });
    invoices.insert(0, item);
    notifications.insert(0, 'Invoice ${item.id} sent to ${tenant.name}.');
    notifyListeners();
    return item;
  }

  Future<void> submitSlip(
    RentalInvoice invoice,
    String name,
    Uint8List bytes,
  ) async {
    final path =
        'slips/${invoice.id}/${DateTime.now().millisecondsSinceEpoch}-${_safeName(name)}';
    await _cloud.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    invoice.slipName = name;
    invoice.slipPath = path;
    invoice.status = InvoiceStatus.slipSubmitted;
    await _cloud.from('rentflow_test_invoices').update({
      'slip_name': name,
      'slip_path': path,
      'status': invoice.status.name,
    }).eq('id', invoice.id);
    notifications.insert(
      0,
      '${invoice.tenant.name} uploaded a payment slip for ${invoice.period}.',
    );
    notifyListeners();
  }

  Future<void> approve(RentalInvoice invoice) async {
    invoice.status = InvoiceStatus.paid;
    await _cloud.from('rentflow_test_invoices').update({
      'status': invoice.status.name,
    }).eq('id', invoice.id);
    notifications.insert(0, 'Payment ${invoice.id} approved.');
    notifyListeners();
  }

  String publicFileUrl(String path) =>
      _cloud.storage.from(bucket).getPublicUrl(path);

  static String _safeName(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

class RentFlowScope extends InheritedWidget {
  const RentFlowScope({required this.store, required super.child, super.key});
  final RentFlowStore store;
  static RentFlowStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RentFlowScope>()!.store;
  @override
  bool updateShouldNotify(RentFlowScope oldWidget) => store != oldWidget.store;
}

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});
  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int index = 0;
  static const labels = ['Overview', 'Properties', 'Billing', 'Notifications'];
  static const icons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.building_2_fill,
    CupertinoIcons.doc_text_fill,
    CupertinoIcons.bell_fill,
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const PropertiesPage(),
      const BillingPage(),
      const NotificationPage(),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final content = Column(
          children: [
            const TestModeBanner(),
            if (desktop) OwnerTopBar(title: labels[index]),
            Expanded(child: pages[index]),
          ],
        );
        if (desktop) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: 238,
                    child: OwnerSidebar(
                      index: index,
                      labels: labels,
                      icons: icons,
                      onChanged: (value) => setState(() => index = value),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: _canvas,
            title: Text(labels[index],
                style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                onPressed: () => setState(() => index = 3),
                icon: const Icon(CupertinoIcons.bell),
              ),
            ],
          ),
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: List.generate(
              labels.length,
              (i) =>
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
            ),
          ),
        );
      },
    );
  }
}

class OwnerSidebar extends StatelessWidget {
  const OwnerSidebar({
    required this.index,
    required this.labels,
    required this.icons,
    required this.onChanged,
    super.key,
  });
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withOpacity(.84),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(CupertinoIcons.house_fill, color: _blue),
              SizedBox(width: 10),
              Text('RentFlow',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _blue)),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _canvas, borderRadius: BorderRadius.circular(13)),
              child: const Row(children: [
                CircleAvatar(
                    radius: 15,
                    child: Icon(CupertinoIcons.person_fill, size: 16)),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Owner',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                Icon(CupertinoIcons.chevron_down, size: 14),
              ]),
            ),
            const SizedBox(height: 18),
            ...List.generate(labels.length, (i) {
              final selected = i == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: ListTile(
                  selected: selected,
                  selectedTileColor: const Color(0x16007AFF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(icons[i], color: selected ? _blue : _secondary),
                  title: Text(labels[i],
                      style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                  onTap: () => onChanged(i),
                ),
              );
            }),
            const Spacer(),
            const ListTile(
              leading: CircleAvatar(
                  backgroundColor: Color(0xFFE5F2FF), child: Text('AJ')),
              title: Text('Alex Johnson',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Property owner'),
            ),
          ],
        ),
      ),
    );
  }
}

class TestModeBanner extends StatelessWidget {
  const TestModeBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFFFF1D6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: const Text(
          'TEMPORARY PUBLIC TEST MODE • Anyone with an invoice link can view and upload a payment slip.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9A5A00),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class OwnerTopBar extends StatelessWidget {
  const OwnerTopBar({required this.title, super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        color: Colors.white.withOpacity(.7),
        child: Row(children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          SizedBox(
            width: 310,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search properties, tenants, payments…',
                prefixIcon: Icon(CupertinoIcons.search),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const CircleAvatar(child: Icon(CupertinoIcons.person_fill)),
        ]),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = RentFlowScope.of(context);
    final pending = store.invoices
        .where((e) => e.status != InvoiceStatus.paid)
        .fold<double>(0, (a, b) => a + b.total);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Good morning, Alex',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Here’s how your portfolio is performing',
            style: TextStyle(color: _secondary)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          final cardWidth =
              (constraints.maxWidth - (14 * (columns - 1))) / columns;
          return Wrap(spacing: 14, runSpacing: 14, children: [
            MetricCard(
                width: cardWidth,
                icon: CupertinoIcons.building_2_fill,
                label: 'Total Properties',
                value: '3',
                tint: _blue),
            MetricCard(
                width: cardWidth,
                icon: CupertinoIcons.person_2_fill,
                label: 'Occupancy',
                value: '91.7%',
                tint: _sky),
            MetricCard(
                width: cardWidth,
                icon: CupertinoIcons.money_dollar_circle_fill,
                label: 'Rent Collected',
                value: 'RM 8,450',
                tint: const Color(0xFF34C759)),
            MetricCard(
                width: cardWidth,
                icon: CupertinoIcons.clock_fill,
                label: 'Outstanding',
                value: rm(pending),
                tint: const Color(0xFFFF9500)),
          ]);
        }),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 760;
          final chart = const PerformanceCard();
          final activity = RecentInvoicesCard(invoices: store.invoices);
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: chart),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: activity)
                ])
              : Column(children: [chart, const SizedBox(height: 16), activity]);
        }),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {required this.width,
      required this.icon,
      required this.label,
      required this.value,
      required this.tint,
      super.key});
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: tint.withOpacity(.12),
                  foregroundColor: tint,
                  child: Icon(icon)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _secondary, fontSize: 12),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class PerformanceCard extends StatelessWidget {
  const PerformanceCard({super.key});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Text('Rental Performance',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Spacer(),
              Text('Last 6 months', style: TextStyle(color: _secondary))
            ]),
            const SizedBox(height: 24),
            SizedBox(
                height: 220,
                child: CustomPaint(
                    painter: PerformancePainter(),
                    size: const Size(double.infinity, 220))),
          ]),
        ),
      );
}

class PerformancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x0F000000)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final values = [0.62, .48, .44, .25, .43, .18];
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p =
          Offset(size.width * i / (values.length - 1), size.height * values[i]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = _blue
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(size.width * i / 5, size.height * values[i]), 4,
          Paint()..color = _blue);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RecentInvoicesCard extends StatelessWidget {
  const RecentInvoicesCard({required this.invoices, super.key});
  final List<RentalInvoice> invoices;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent Invoices',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (invoices.isEmpty)
              const Text('No invoices yet.')
            else
              ...invoices.take(5).map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        child: Text(item.tenant.name.substring(0, 1))),
                    title: Text(item.tenant.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${item.period} • ${item.tenant.unit}'),
                    trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(rm(item.total),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          InvoiceStatusPill(status: item.status)
                        ]),
                  )),
          ]),
        ),
      );
}

class PropertiesPage extends StatelessWidget {
  const PropertiesPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Properties',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          ...[
            'MH 2 Platinum Residences',
            'Harmony Residence',
            'Skyline Suites'
          ].map((name) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                    child: ListTile(
                        contentPadding: const EdgeInsets.all(18),
                        leading: const CircleAvatar(
                            child: Icon(CupertinoIcons.building_2_fill)),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('Active • Kuala Lumpur'),
                        trailing: const Icon(CupertinoIcons.chevron_right))),
              )),
        ],
      );
}

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = RentFlowScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Billing',
                    style:
                        TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                Text('Create, send and review tenant invoices',
                    style: TextStyle(color: _secondary))
              ])),
          FilledButton.icon(
              onPressed: () => showCreateInvoice(context),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('New invoice')),
        ]),
        const SizedBox(height: 20),
        if (store.loading) const LinearProgressIndicator(),
        if (store.error != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(store.error!,
                      style: const TextStyle(color: Colors.red)))),
        if (store.invoices.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(28), child: Text('No invoices yet.')))
        else
          ...store.invoices.map((invoice) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                    child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: const CircleAvatar(
                      child: Icon(CupertinoIcons.doc_text_fill)),
                  title: Text('${invoice.tenant.name} • ${invoice.period}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${invoice.id} • ${invoice.usage.toStringAsFixed(2)} kWh • ${invoice.tenant.unit}'),
                  trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      children: [
                        InvoiceStatusPill(status: invoice.status),
                        Text(rm(invoice.total),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        IconButton(
                            onPressed: () =>
                                showInvoiceActions(context, invoice),
                            icon: const Icon(CupertinoIcons.ellipsis_circle)),
                      ]),
                )),
              )),
      ],
    );
  }
}

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = RentFlowScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Notifications',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        if (store.notifications.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('You’re all caught up.')))
        else
          ...store.notifications.map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                    child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE5F2FF),
                            child:
                                Icon(CupertinoIcons.bell_fill, color: _blue)),
                        title: Text(text,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Just now'))),
              )),
      ],
    );
  }
}

class TenantInvoicePage extends StatefulWidget {
  const TenantInvoicePage({required this.invoiceId, super.key});
  final String invoiceId;

  @override
  State<TenantInvoicePage> createState() => _TenantInvoicePageState();
}

class _TenantInvoicePageState extends State<TenantInvoicePage> {
  final code = List.generate(4, (_) => TextEditingController());
  final focus = List.generate(4, (_) => FocusNode());
  final amount = TextEditingController();
  final paymentDate = TextEditingController();
  final reference = TextEditingController();
  PickedImageData? proof;
  bool verified = false;
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    for (final controller in code) {
      controller.dispose();
    }
    for (final node in focus) {
      node.dispose();
    }
    amount.dispose();
    paymentDate.dispose();
    reference.dispose();
    super.dispose();
  }

  void verify(RentalInvoice invoice) {
    final entered = code.map((item) => item.text).join();
    final digits = invoice.tenant.phone.replaceAll(RegExp(r'\D'), '');
    final expected =
        digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    if (entered != expected) {
      setState(() => error = 'The verification code is incorrect.');
      return;
    }
    setState(() {
      verified = true;
      error = null;
      amount.text = invoice.total.toStringAsFixed(2);
      paymentDate.text = shortDate(DateTime.now());
    });
  }

  Future<void> chooseProof() async {
    try {
      final selected = await pickPaymentProof();
      if (selected == null || !mounted) return;
      if (selected.bytes.length > 10 * 1024 * 1024) {
        setState(() => error = 'Payment proof must be 10 MB or smaller.');
        return;
      }
      setState(() {
        proof = selected;
        error = null;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> submit(RentFlowStore store, RentalInvoice invoice) async {
    if (proof == null) {
      setState(() => error = 'Attach your payment proof before submitting.');
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await store.submitSlip(
          invoice, proof!.name, Uint8List.fromList(proof!.bytes));
    } catch (exception) {
      if (mounted) setState(() => error = 'Upload failed: $exception');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RentFlowScope.of(context);
    final invoice = store.invoice(widget.invoiceId);
    if (store.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (invoice == null) {
      return const Scaffold(
          body: Center(
              child: Text('This invoice link is invalid or has expired.')));
    }
    final completed = invoice.status == InvoiceStatus.slipSubmitted ||
        invoice.status == InvoiceStatus.paid;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0F7),
      body: SafeArea(
        child: completed
            ? _PaymentSubmittedView(invoice: invoice)
            : verified
                ? _InvoiceSettlementView(
                    invoice: invoice,
                    proof: proof,
                    amount: amount,
                    paymentDate: paymentDate,
                    reference: reference,
                    error: error,
                    submitting: submitting,
                    onChooseProof: chooseProof,
                    onSubmit: () => submit(store, invoice),
                  )
                : _InvoiceVerificationView(
                    invoice: invoice,
                    code: code,
                    focus: focus,
                    error: error,
                    onContinue: () => verify(invoice),
                  ),
      ),
    );
  }
}

class _InvoiceVerificationView extends StatelessWidget {
  const _InvoiceVerificationView({
    required this.invoice,
    required this.code,
    required this.focus,
    required this.error,
    required this.onContinue,
  });

  final RentalInvoice invoice;
  final List<TextEditingController> code;
  final List<FocusNode> focus;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final brand = _PortalBrandPanel(
                  title: 'A calmer way to\nmanage your tenancy.',
                  subtitle:
                      'Secure one-time access — no account to create, no app to download.',
                );
                final form = Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(wide ? 48 : 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVOICE #${invoice.id}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Verify it’s you',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the last four digits of the mobile number on file ${_maskedPhone(invoice.tenant.phone)}.',
                        style: const TextStyle(color: _secondary),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: List.generate(4, (index) {
                          return Padding(
                            padding:
                                EdgeInsets.only(right: index == 3 ? 0 : 10),
                            child: SizedBox(
                              width: 64,
                              child: TextField(
                                controller: code[index],
                                focusNode: focus[index],
                                autofocus: index == 0,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800),
                                decoration:
                                    const InputDecoration(counterText: ''),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 3) {
                                    focus[index + 1].requestFocus();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF14243D),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: onContinue,
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: wide
                      ? Row(children: [
                          SizedBox(width: 415, child: brand),
                          Expanded(child: form)
                        ])
                      : Column(children: [
                          SizedBox(height: 250, child: brand),
                          form
                        ]),
                );
              },
            ),
          ),
        ),
      );
}

class _InvoiceSettlementView extends StatelessWidget {
  const _InvoiceSettlementView({
    required this.invoice,
    required this.proof,
    required this.amount,
    required this.paymentDate,
    required this.reference,
    required this.error,
    required this.submitting,
    required this.onChooseProof,
    required this.onSubmit,
  });

  final RentalInvoice invoice;
  final PickedImageData? proof;
  final TextEditingController amount;
  final TextEditingController paymentDate;
  final TextEditingController reference;
  final String? error;
  final bool submitting;
  final VoidCallback onChooseProof;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final summary = _InvoicePortalSummary(invoice: invoice);
              final form = Container(
                color: Colors.white,
                padding: EdgeInsets.all(wide ? 40 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settle your invoice',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    const Text(
                        'Two quick steps — transfer, then attach your slip.',
                        style: TextStyle(color: _secondary)),
                    const SizedBox(height: 22),
                    const _PortalSectionLabel('STEP 1 — TRANSFER TO OWNER'),
                    const SizedBox(height: 10),
                    const _BankDetailsCard(),
                    const SizedBox(height: 24),
                    const _PortalSectionLabel('STEP 2 — ATTACH PAY SLIP'),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onChooseProof,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5FAFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF78B9FF)),
                        ),
                        child: Row(children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(Icons.upload_rounded, color: _blue),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  proof?.name ?? 'Tap to attach your receipt',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const Text('JPG, PNG or PDF · up to 10 MB',
                                    style: TextStyle(
                                        color: _secondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: amount,
                              decoration: const InputDecoration(
                                  labelText: 'Amount paid',
                                  prefixText: 'RM '))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: paymentDate,
                              decoration: const InputDecoration(
                                  labelText: 'Date paid'))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: reference,
                        decoration: const InputDecoration(
                            labelText: 'Payment reference (optional)')),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF14243D),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: submitting ? null : onSubmit,
                        child: Text(
                            submitting ? 'Sending…' : 'Send payment proof'),
                      ),
                    ),
                  ],
                ),
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            SizedBox(width: 380, child: summary),
                            Expanded(child: form)
                          ])
                    : Column(children: [summary, form]),
              );
            }),
          ),
        ),
      );
}

class _PortalBrandPanel extends StatelessWidget {
  const _PortalBrandPanel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3285DC), Color(0xFF1D5CB9)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.home_outlined, color: Colors.white),
              SizedBox(width: 12),
              Text('PLATINUM VICTORY',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ]),
            const SizedBox(height: 62),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.25)),
            const SizedBox(height: 16),
            Text(subtitle,
                style: const TextStyle(color: Color(0xDDFFFFFF), height: 1.5)),
            const SizedBox(height: 48),
            const Text('© 2026 Platinum Victory',
                style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
          ],
        ),
      );
}

class _InvoicePortalSummary extends StatelessWidget {
  const _InvoicePortalSummary({required this.invoice});
  final RentalInvoice invoice;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        color: const Color(0xFF2876D4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.home_outlined, color: Colors.white),
            SizedBox(width: 12),
            Text('PLATINUM VICTORY',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2))
          ]),
          const SizedBox(height: 44),
          Text('AMOUNT DUE · ${invoice.period.toUpperCase()}',
              style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(rm(invoice.total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800)),
          Text(
              'Due ${shortDate(invoice.dueDate)} · Unit ${invoice.tenant.unit}',
              style: const TextStyle(color: Color(0xDDFFFFFF))),
          const Divider(height: 42, color: Color(0x55FFFFFF)),
          _PortalCharge('Monthly rent', invoice.tenant.rent),
          _PortalCharge('Water', invoice.tenant.water),
          _PortalCharge('Internet', invoice.tenant.internet),
          _PortalCharge('Electricity · ${invoice.usage.toStringAsFixed(2)} kWh',
              invoice.electricity),
          const Divider(height: 30, color: Color(0x55FFFFFF)),
          TextButton.icon(
            onPressed: () => showInvoicePdfPreview(context, invoice),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Download invoice PDF'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ]),
      );
}

class _PortalCharge extends StatelessWidget {
  const _PortalCharge(this.label, this.amount);
  final String label;
  final double amount;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Color(0xDDFFFFFF)))),
          Text(rm(amount),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800))
        ]),
      );
}

class _PortalSectionLabel extends StatelessWidget {
  const _PortalSectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2));
}

class _BankDetailsCard extends StatelessWidget {
  const _BankDetailsCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDCE5F0)),
            borderRadius: BorderRadius.circular(16)),
        child: const Column(children: [
          _BankRow('Bank', 'Maybank'),
          Divider(height: 1),
          _BankRow('Account no.', '5124 8890 2201'),
          Divider(height: 1),
          _BankRow('Beneficiary', 'Ahmad Faisal'),
        ]),
      );
}

class _BankRow extends StatelessWidget {
  const _BankRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
              child: Text(label, style: const TextStyle(color: _secondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800))
        ]),
      );
}

class _PaymentSubmittedView extends StatelessWidget {
  const _PaymentSubmittedView({required this.invoice});
  final RentalInvoice invoice;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(42),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x180F172A),
                      blurRadius: 30,
                      offset: Offset(0, 14))
                ]),
            child: Column(children: [
              const CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0xFFE7F7EE),
                  child: Icon(Icons.check_rounded,
                      color: Color(0xFF16A34A), size: 38)),
              const SizedBox(height: 22),
              Text('Thank you, ${invoice.tenant.name.split(' ').first}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                  invoice.status == InvoiceStatus.paid
                      ? 'Your payment has been confirmed.'
                      : 'Your pay slip for ${rm(invoice.total)} has reached the owner.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _secondary, height: 1.5)),
              const SizedBox(height: 24),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded,
                        color: Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            invoice.status == InvoiceStatus.paid
                                ? 'Payment confirmed'
                                : 'Awaiting owner confirmation',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                  onPressed: () => printInvoice(invoice),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download receipt')),
            ]),
          ),
        ),
      );
}

String _maskedPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return value;
  return '••• ${digits.substring(digits.length - 4)}';
}

class InvoiceDocument extends StatelessWidget {
  const InvoiceDocument({required this.invoice, super.key});
  final RentalInvoice invoice;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('RENTAL PAYMENT NOTICE',
                        style: TextStyle(
                            fontSize: 12,
                            color: _blue,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8)),
                    SizedBox(height: 4),
                    Text('RentFlow',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800))
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('AMOUNT DUE',
                    style: TextStyle(fontSize: 11, color: _secondary)),
                Text(rm(invoice.total),
                    style: const TextStyle(
                        fontSize: 25,
                        color: Color(0xFF248A3D),
                        fontWeight: FontWeight.w800))
              ]),
            ]),
            const Divider(height: 34),
            Wrap(spacing: 45, runSpacing: 14, children: [
              InvoiceInfo(
                  label: 'BILL TO',
                  value:
                      '${invoice.tenant.name}\n${invoice.tenant.unit}\n${invoice.tenant.property}'),
              InvoiceInfo(
                  label: 'BILL DETAILS',
                  value:
                      '${invoice.period}\nUsage: ${invoice.usagePeriod}\nReference: ${invoice.id}'),
            ]),
            const SizedBox(height: 24),
            const Text('CHARGE SUMMARY',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ChargeRow(label: 'Monthly rent', value: invoice.tenant.rent),
            ChargeRow(label: 'Water', value: invoice.tenant.water),
            ChargeRow(label: 'Internet', value: invoice.tenant.internet),
            ChargeRow(
                label:
                    'Electricity (${invoice.usage.toStringAsFixed(2)} kWh × RM 0.516)',
                value: invoice.electricity),
            const Divider(),
            ChargeRow(
                label: 'TOTAL AMOUNT DUE', value: invoice.total, bold: true),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  'Please complete payment by ${shortDate(invoice.dueDate)} and attach the receipt using the button below.'),
            ),
          ]),
        ),
      );
}

class InvoiceInfo extends StatelessWidget {
  const InvoiceInfo({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 250,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: _secondary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600))
      ]));
}

class ChargeRow extends StatelessWidget {
  const ChargeRow(
      {required this.label, required this.value, this.bold = false, super.key});
  final String label;
  final double value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
        Text(rm(value),
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 17 : 14))
      ]));
}

class InvoiceStatusPill extends StatelessWidget {
  const InvoiceStatusPill({required this.status, super.key});
  final InvoiceStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvoiceStatus.draft => ('Draft', _secondary),
      InvoiceStatus.sent => ('Awaiting payment', const Color(0xFFFF9500)),
      InvoiceStatus.slipSubmitted => ('Slip received', _blue),
      InvoiceStatus.paid => ('Paid', const Color(0xFF34C759)),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w800)));
  }
}

Future<void> showCreateInvoice(BuildContext context) async {
  final store = RentFlowScope.of(context);
  var tenant = store.tenants.first;
  final previous = TextEditingController(text: '1240.00');
  final current = TextEditingController(text: '1376.25');
  String? evidence;
  Uint8List? evidenceBytes;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(builder: (context, setState) {
      final usage = math.max(
        0,
        (double.tryParse(current.text) ?? 0) -
            (double.tryParse(previous.text) ?? 0),
      );
      return AlertDialog(
        title: const Text('Create tenant invoice'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<TenantAccount>(
                  value: tenant,
                  decoration: const InputDecoration(labelText: 'Tenant'),
                  items: store.tenants
                      .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text('${item.name} • ${item.unit}')))
                      .toList(),
                  onChanged: (value) => setState(() => tenant = value!)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: previous,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Previous reading', suffixText: 'kWh'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: current,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Current reading', suffixText: 'kWh')))
              ]),
              const SizedBox(height: 12),
              ListTile(
                  tileColor: const Color(0xFFEAF4FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: const Text('Calculated electricity usage'),
                  subtitle: const Text('Automatic rate: RM 0.516 per kWh'),
                  trailing: Text('${usage.toStringAsFixed(2)} kWh',
                      style: const TextStyle(
                          color: _blue, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform
                        .pickFiles(type: FileType.image, withData: true);
                    if (result != null)
                      setState(() {
                        evidence = result.files.single.name;
                        evidenceBytes = result.files.single.bytes;
                      });
                  },
                  icon: const Icon(CupertinoIcons.camera_fill),
                  label: Text(evidence ?? 'Attach meter photo')),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: evidenceBytes == null
                  ? null
                  : () async {
                      final invoice = await store.createInvoice(
                          tenant: tenant,
                          previous: double.tryParse(previous.text) ?? 0,
                          current: double.tryParse(current.text) ?? 0,
                          evidence: evidence!,
                          evidenceBytes: evidenceBytes!);
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      showInvoiceActions(context, invoice);
                    },
              child: const Text('Generate invoice'))
        ],
      );
    }),
  );
}

Future<void> showInvoiceActions(
    BuildContext context, RentalInvoice invoice) async {
  final store = RentFlowScope.of(context);
  final base = tenantInvoiceLink(invoice.id);
  await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: Text('Invoice ${invoice.id}'),
            content: SizedBox(
                width: 560,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InvoiceDocument(invoice: invoice),
                      const SizedBox(height: 12),
                      SelectableText(base.toString(),
                          style: const TextStyle(color: _blue, fontSize: 12)),
                    ])),
            actions: [
              TextButton(
                  onPressed: () => printInvoice(invoice),
                  child: const Text('PDF')),
              TextButton(
                  onPressed: () => shareEmail(invoice, base),
                  child: const Text('Email')),
              if (invoice.slipPath != null)
                TextButton(
                    onPressed: () => launchUrl(
                        Uri.parse(store.publicFileUrl(invoice.slipPath!))),
                    child: const Text('Review slip')),
              if (invoice.status == InvoiceStatus.slipSubmitted)
                TextButton(
                    onPressed: () async {
                      await store.approve(invoice);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Approve payment')),
              FilledButton.icon(
                  onPressed: () => shareWhatsApp(invoice, base),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send WhatsApp')),
            ],
          ));
}

Future<void> shareEmail(RentalInvoice invoice, Uri link) async {
  final subject = 'RentFlow invoice ${invoice.id} – ${invoice.period}';
  final body =
      'Hi ${invoice.tenant.name},\n\nYour rental invoice is ready. Amount due: ${rm(invoice.total)}.\n\nOpen this link to review/download the invoice and upload your payment slip:\n$link';
  await launchUrl(Uri(
    scheme: 'mailto',
    path: invoice.tenant.email,
    queryParameters: {'subject': subject, 'body': body},
  ));
}

Future<void> shareWhatsApp(
  RentalInvoice invoice,
  Uri link, {
  Uri? pdfLink,
}) async {
  final message =
      'Hi ${invoice.tenant.name}, your ${invoice.period} rental invoice is ready. Amount due: ${rm(invoice.total)}.\n\nOpen the secure payment portal and upload your payment slip:\n$link${pdfLink == null ? '' : '\n\nDownload your PDF invoice:\n$pdfLink'}';
  final whatsappPhone = invoice.tenant.phone.replaceAll(RegExp(r'\D'), '');
  final uri = Uri.parse(
      'https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(message)}');
  if (kIsWeb) {
    // Mobile browsers commonly block a new window after PDF generation and
    // upload. Reusing the current tab remains permitted and opens the
    // WhatsApp app when its universal link is installed.
    await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );
  } else {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> uploadSlip(BuildContext context, RentalInvoice invoice) async {
  final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true);
  if (result == null || !context.mounted) return;
  final file = result.files.single;
  if (file.bytes == null) return;
  await RentFlowScope.of(context).submitSlip(invoice, file.name, file.bytes!);
}

Future<Uint8List> invoicePdf(RentalInvoice invoice) async {
  final evidence = _prepareEvidenceForPdf(invoice.evidenceBytes);
  final doc = pw.Document();
  doc.addPage(_noticePage(invoice));
  doc.addPage(_evidencePage(invoice, evidence));
  return doc.save();
}

Uint8List? _prepareEvidenceForPdf(Uint8List? source) {
  if (source == null || source.isEmpty) return null;
  try {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;
    const maximumSide = 1400;
    final longestSide = math.max(decoded.width, decoded.height);
    final resized = longestSide > maximumSide
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maximumSide : null,
            height: decoded.height > decoded.width ? maximumSide : null,
            interpolation: img.Interpolation.linear,
          )
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 72));
  } catch (_) {
    // Keep invoice generation available even when an unusual image cannot be
    // decoded. The evidence filename will still appear on the evidence page.
    return null;
  }
}

pw.Page _noticePage(RentalInvoice invoice) {
  final navy = PdfColor.fromHex('#17233C');
  final muted = PdfColor.fromHex('#62708A');
  final line = PdfColor.fromHex('#CCD6E5');
  final paleBlue = PdfColor.fromHex('#EEF4FD');
  final paleGreen = PdfColor.fromHex('#E8F7F1');
  final green = PdfColor.fromHex('#167457');
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(50, 24, 50, 26),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfTopLine(muted),
        pw.SizedBox(height: 34),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text('${invoice.period.toUpperCase()} RENTAL PAYMENT\nNOTICE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 18,
                      lineSpacing: 2,
                      color: navy,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                  "This month's rent with the previous month's electricity usage",
                  style: pw.TextStyle(fontSize: 9, color: muted)),
            ]),
          ),
          pw.SizedBox(width: 22),
          pw.Container(
            width: 180,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            decoration: pw.BoxDecoration(
                color: paleGreen,
                border: pw.Border.all(color: PdfColor.fromHex('#A9DDCB'))),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('AMOUNT DUE',
                      style: pw.TextStyle(fontSize: 9, color: green)),
                  pw.SizedBox(height: 4),
                  pw.Text(rm(invoice.total),
                      style: pw.TextStyle(
                          fontSize: 25,
                          color: green,
                          fontWeight: pw.FontWeight.bold)),
                ]),
          ),
        ]),
        pw.SizedBox(height: 18),
        pw.Container(
          height: 158,
          decoration: pw.BoxDecoration(
              color: paleBlue, border: pw.Border.all(color: line)),
          child: pw.Row(children: [
            pw.Expanded(
                child: pw.Padding(
              padding: const pw.EdgeInsets.all(18),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSection('BILL TO', navy),
                    pw.SizedBox(height: 12),
                    pw.Text(
                        '${invoice.tenant.name}\n${invoice.tenant.unit}\n${invoice.tenant.property}',
                        style:
                            const pw.TextStyle(fontSize: 11, lineSpacing: 5)),
                  ]),
            )),
            pw.Container(width: .7, color: line),
            pw.Expanded(
                child: pw.Padding(
              padding: const pw.EdgeInsets.all(18),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSection('BILL DETAILS', navy),
                    pw.SizedBox(height: 10),
                    _pdfDetail('Rent period', invoice.period, muted),
                    _pdfDetail('Electricity usage', invoice.usagePeriod, muted),
                    _pdfDetail('Issue date', shortDate(DateTime.now()), muted),
                    _pdfDetail('Reference', invoice.id, muted),
                    _pdfDetail('Status', 'Payment due', muted),
                  ]),
            )),
          ]),
        ),
        pw.SizedBox(height: 25),
        _pdfSection('CHARGE SUMMARY', navy),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: line, width: .7),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.25),
            1: pw.FlexColumnWidth(1.7),
            2: pw.FlexColumnWidth(.9)
          },
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: navy), children: [
              _pdfHead('Description'),
              _pdfHead('Details'),
              _pdfHead('Amount')
            ]),
            _pdfChargeRow(
                'Monthly rent',
                '${invoice.tenant.unit} - ${invoice.period}',
                rm(invoice.tenant.rent),
                false,
                line,
                muted),
            _pdfChargeRow(
                'Water',
                invoice.tenant.water == 0
                    ? 'Included in rent'
                    : 'Monthly water charge',
                rm(invoice.tenant.water),
                true,
                line,
                muted),
            _pdfChargeRow(
                'Internet',
                invoice.tenant.internet == 0
                    ? 'Included in rent'
                    : 'Monthly internet charge',
                rm(invoice.tenant.internet),
                false,
                line,
                muted),
            _pdfChargeRow(
                'General electricity',
                'Monthly general electricity charge',
                rm(invoice.generalElectricAmount),
                true,
                line,
                muted),
            _pdfChargeRow(
                'Air-con electricity',
                '${invoice.usagePeriod} usage: ${invoice.usage.toStringAsFixed(2)} kWh\n${invoice.electricityTariffSummary ?? '${invoice.electricityTariffName} RM ${invoice.electricityRatePerKwh.toStringAsFixed(3)} / kWh'}\nRounded to ${rm(invoice.electricity)}',
                rm(invoice.electricity),
                false,
                line,
                muted),
            _pdfChargeRow('Car park rental', 'Monthly parking rental fee',
                rm(invoice.parkingRentalAmount), true, line, muted),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: line, width: .7),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1)
          },
          children: [
            pw.TableRow(children: [
              _pdfCell('Total electricity charges'),
              _pdfCell(rm(invoice.generalElectricAmount + invoice.electricity))
            ]),
            pw.TableRow(
                decoration: pw.BoxDecoration(color: paleGreen),
                children: [
                  _pdfCell('TOTAL AMOUNT DUE', bold: true),
                  _pdfCell(rm(invoice.total), bold: true)
                ]),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFF8E8'),
              border: pw.Border.all(color: PdfColor.fromHex('#E8D39A'))),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfSection('PAYMENT NOTE', navy),
                pw.SizedBox(height: 8),
                pw.Text(
                    'Please arrange payment of ${rm(invoice.total)} to the designated bank account and send the payment receipt to person in charge for confirmation. Kindly complete the payment within three (3) days from the date of this bill.',
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 4)),
              ]),
        ),
        pw.Spacer(),
        _pdfFooter(invoice, 1, line, muted),
      ],
    ),
  );
}

pw.Page _evidencePage(RentalInvoice invoice, Uint8List? evidenceBytes) {
  final navy = PdfColor.fromHex('#17233C');
  final muted = PdfColor.fromHex('#62708A');
  final line = PdfColor.fromHex('#CCD6E5');
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(50, 24, 50, 26),
    build: (_) =>
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Align(alignment: pw.Alignment.centerLeft, child: _pdfTopLine(muted)),
      pw.SizedBox(height: 36),
      pw.Text('COMBINED ELECTRICITY USAGE EVIDENCE',
          style: pw.TextStyle(
              fontSize: 22, color: navy, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      pw.Text(
          '${invoice.usagePeriod} recorded usage: ${invoice.usage.toStringAsFixed(2)} kWh',
          style: pw.TextStyle(fontSize: 10, color: muted)),
      pw.SizedBox(height: 24),
      if (evidenceBytes != null)
        pw.Container(
            width: 330,
            height: 570,
            alignment: pw.Alignment.center,
            child:
                pw.Image(pw.MemoryImage(evidenceBytes), fit: pw.BoxFit.contain))
      else
        pw.Container(
            width: 330,
            height: 570,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: line)),
            child: pw.Text(invoice.evidenceName)),
      pw.SizedBox(height: 18),
      pw.Text(
          'Calculation: ${invoice.usage.toStringAsFixed(2)} kWh x RM 0.516 per kWh = RM ${(invoice.usage * 0.516).toStringAsFixed(5)}, rounded to ${rm(invoice.electricity)}.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, color: muted)),
      pw.Spacer(),
      _pdfFooter(invoice, 2, line, muted),
    ]),
  );
}

pw.Widget _pdfTopLine(PdfColor muted) =>
    pw.Text('Digital bill generated and powered by CodexAI.',
        style: pw.TextStyle(fontSize: 8, color: muted));
pw.Widget _pdfSection(String text, PdfColor color) => pw.Text(text,
    style: pw.TextStyle(
        fontSize: 12, color: color, fontWeight: pw.FontWeight.bold));
pw.Widget _pdfDetail(String label, String value, PdfColor muted) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(children: [
      pw.SizedBox(
          width: 88,
          child:
              pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: muted))),
      pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)))
    ]));
pw.Widget _pdfHead(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold)));
pw.Widget _pdfCell(String text,
        {bool bold = false, PdfColor? color}) =>
    pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: pw.Text(
            text,
            style: pw.TextStyle(
                fontSize: 9.5,
                color: color,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));
pw.TableRow _pdfChargeRow(String name, String detail, String amount, bool shade,
        PdfColor line, PdfColor muted) =>
    pw.TableRow(
        decoration:
            shade ? pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFD')) : null,
        children: [
          _pdfCell(name),
          _pdfCell(detail, color: muted),
          _pdfCell(amount)
        ]);
pw.Widget _pdfFooter(
        RentalInvoice invoice, int page, PdfColor line, PdfColor muted) =>
    pw.Column(children: [
      pw.Container(height: .7, color: line),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        pw.Text('Rental payment notice - ${invoice.period}',
            style: pw.TextStyle(fontSize: 8, color: muted)),
        pw.Spacer(),
        pw.Text('Page $page', style: pw.TextStyle(fontSize: 8, color: muted))
      ])
    ]);

// Kept as a fallback while existing cloud invoices are migrated.
// ignore: unused_element
Future<Uint8List> _legacyInvoicePdf(RentalInvoice invoice) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(42),
      build: (context) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EEF4FD'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                '${invoice.period.toUpperCase()} RENTAL PAYMENT NOTICE',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#17233C'),
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              "This month's rent with the previous month's electricity usage",
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 24),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                    pw.Text('PLATINUM VICTORY',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text('Rental Facility Manager',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600))
                  ])),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                color: PdfColor.fromHex('#EAF8EF'),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('AMOUNT DUE',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(rm(invoice.total),
                          style: pw.TextStyle(
                              fontSize: 22,
                              color: PdfColor.fromHex('#15803D'),
                              fontWeight: pw.FontWeight.bold))
                    ]),
              ),
            ]),
            pw.Divider(height: 30),
            pw.Row(children: [
              pw.Expanded(
                  child: pdfInfo('BILL TO',
                      '${invoice.tenant.name}\n${invoice.tenant.unit}\n${invoice.tenant.property}')),
              pw.Expanded(
                  child: pdfInfo('BILL DETAILS',
                      'Rent period: ${invoice.period}\nElectricity usage: ${invoice.usagePeriod}\nIssue date: ${shortDate(DateTime.now())}\nReference: ${invoice.id}\nStatus: Pending payment'))
            ]),
            pw.SizedBox(height: 28),
            pw.Text('CHARGE SUMMARY',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pdfCharge('Monthly rent', invoice.tenant.rent),
            pdfCharge('Water', invoice.tenant.water),
            pdfCharge('Internet', invoice.tenant.internet),
            pdfCharge(
                'Electricity (${invoice.usage.toStringAsFixed(2)} kWh x RM 0.516)',
                invoice.electricity),
            pw.Divider(),
            pdfCharge('TOTAL AMOUNT DUE', invoice.total, bold: true),
            pw.SizedBox(height: 20),
            pw.Container(
                padding: const pw.EdgeInsets.all(14),
                color: PdfColors.amber50,
                child: pw.Text(
                    'Please complete payment by ${shortDate(invoice.dueDate)} and upload the receipt through the invoice link.')),
            pw.Spacer(),
            pw.Text('Meter evidence: ${invoice.evidenceName}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]));
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(42),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AIR-CON ELECTRICITY USAGE EVIDENCE',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            '${invoice.usagePeriod} recorded usage: ${invoice.usage.toStringAsFixed(2)} kWh',
          ),
          pw.SizedBox(height: 24),
          if (invoice.evidenceBytes != null)
            pw.Container(
              width: double.infinity,
              height: 430,
              alignment: pw.Alignment.center,
              child: pw.Image(
                pw.MemoryImage(invoice.evidenceBytes!),
                fit: pw.BoxFit.contain,
              ),
            )
          else
            pw.Container(
              width: double.infinity,
              height: 360,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F4F7FB'),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text('Attached reading: ${invoice.evidenceName}',
                  style: const pw.TextStyle(color: PdfColors.grey600)),
            ),
          pw.SizedBox(height: 22),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            color: PdfColor.fromHex('#EEF4FD'),
            child: pw.Text(
              '${invoice.usage.toStringAsFixed(2)} kWh x RM 0.516 = ${rm(invoice.electricity)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget pdfInfo(String label, String value) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label,
          style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 5),
      pw.Text(value, style: const pw.TextStyle(lineSpacing: 4))
    ]);
pw.Widget pdfCharge(String label, double value, {bool bold = false}) =>
    pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(rm(value),
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))
        ]));
Future<void> printInvoice(RentalInvoice invoice) => Printing.layoutPdf(
    onLayout: (_) => invoicePdf(invoice), name: '${invoice.id}.pdf');

Future<void> showInvoicePdfPreview(
  BuildContext context,
  RentalInvoice invoice,
) async {
  try {
    await openPdfDocument(
      fileName: '${invoice.id}.pdf',
      build: () => invoicePdf(invoice),
    );
  } catch (error) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('PDF could not be generated'),
        content: Text(
          error.toString().replaceFirst('Exception: ', ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

String rm(double value) => 'RM ${value.toStringAsFixed(2)}';
String shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
