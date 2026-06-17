import 'package:flutter/material.dart';

void main() {
  runApp(const RentalFacilityApp());
}

enum UserRole { owner, propertyAgent, tenant }

enum UtilityPackage { included, excluded }

enum PaymentStatus { notSubmitted, pendingApproval, approved, rejected }

enum FacilityStatus { active, sold }

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
}

class Facility {
  Facility({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.installmentAmount,
    required this.maintenanceFee,
    required this.insuranceFee,
    required this.otherFee,
    this.extraInstallmentPayment = 0,
    this.status = FacilityStatus.active,
    this.soldAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String address;
  double installmentAmount;
  double maintenanceFee;
  double insuranceFee;
  double otherFee;
  double extraInstallmentPayment;
  FacilityStatus status;
  DateTime? soldAt;
}

class Tenancy {
  Tenancy({
    required this.id,
    required this.facilityId,
    required this.tenantId,
    required this.unitName,
    required this.monthlyRent,
    required this.electricityPackage,
    required this.electricityCharge,
    required this.waterPackage,
    required this.waterCharge,
    required this.internetPackage,
    required this.internetCharge,
    required this.leaseStart,
    required this.leaseEnd,
    this.active = true,
  });

  final String id;
  final String facilityId;
  final String tenantId;
  final String unitName;
  double monthlyRent;
  UtilityPackage electricityPackage;
  double electricityCharge;
  UtilityPackage waterPackage;
  double waterCharge;
  UtilityPackage internetPackage;
  double internetCharge;
  DateTime leaseStart;
  DateTime leaseEnd;
  bool active;
}

class MonthlyBill {
  MonthlyBill({
    required this.id,
    required this.facilityId,
    required this.tenantId,
    required this.month,
    required this.rentAmount,
    required this.electricityAmount,
    required this.waterAmount,
    required this.internetAmount,
    this.status = PaymentStatus.notSubmitted,
    this.slipFileName,
    this.amountPaid = 0,
    this.submittedAt,
    this.rejectReason,
  });

  final String id;
  final String facilityId;
  final String tenantId;
  final DateTime month;
  final double rentAmount;
  double electricityAmount;
  double waterAmount;
  double internetAmount;
  PaymentStatus status;
  String? slipFileName;
  double amountPaid;
  DateTime? submittedAt;
  String? rejectReason;

  double get totalAmount =>
      rentAmount + electricityAmount + waterAmount + internetAmount;
}

class FacilityReport {
  FacilityReport({
    required this.facility,
    required this.inflow,
    required this.outflow,
    required this.netCashflow,
  });

  final Facility facility;
  final double inflow;
  final double outflow;
  final double netCashflow;
}

class TenantRequest {
  TenantRequest({
    required this.id,
    required this.tenantId,
    required this.facilityId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.status = 'Open',
  });

  final String id;
  final String tenantId;
  final String facilityId;
  final String title;
  final String message;
  final DateTime createdAt;
  String status;
}

class RentalStore extends ChangeNotifier {
  RentalStore() {
    _seed();
  }

  final List<AppUser> users = [];
  final List<Facility> facilities = [];
  final List<Tenancy> tenancies = [];
  final List<MonthlyBill> bills = [];
  final List<TenantRequest> tenantRequests = [];
  final List<String> notifications = [];

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;
  bool get isOwner => currentUser?.role == UserRole.owner;
  bool get isPropertyAgent => currentUser?.role == UserRole.propertyAgent;
  bool get isManager => isOwner || isPropertyAgent;

  List<Facility> get ownerFacilities {
    final user = currentUser;
    if (user == null) return [];
    if (user.role == UserRole.propertyAgent) {
      return facilities.toList();
    }
    return facilities.where((facility) => facility.ownerId == user.id).toList();
  }

  List<Tenancy> get tenantTenancies {
    final user = currentUser;
    if (user == null) return [];
    return tenancies.where((tenancy) => tenancy.tenantId == user.id).toList();
  }

  List<MonthlyBill> get tenantBills {
    final user = currentUser;
    if (user == null) return [];
    return bills.where((bill) => bill.tenantId == user.id).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<MonthlyBill> get tenantPaymentHistory {
    return tenantBills
        .where((bill) => bill.status != PaymentStatus.notSubmitted)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<MonthlyBill> get tenantPayableBills {
    return tenantBills
        .where((bill) => bill.status != PaymentStatus.approved)
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  List<TenantRequest> get currentTenantRequests {
    final user = currentUser;
    if (user == null) return [];
    return tenantRequests
        .where((request) => request.tenantId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  double get totalInflow {
    return bills
        .where((bill) => bill.status == PaymentStatus.approved)
        .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
  }

  double get totalOutflow {
    return ownerFacilities.fold<double>(0, (sum, facility) {
      return sum +
          facility.installmentAmount +
          facility.extraInstallmentPayment +
          facility.maintenanceFee +
          facility.insuranceFee +
          facility.otherFee;
    });
  }

  double get netCashflow => totalInflow - totalOutflow;

  double facilityInflow(String facilityId) {
    return bills.where((bill) {
      return bill.facilityId == facilityId &&
          bill.status == PaymentStatus.approved;
    }).fold<double>(0, (sum, bill) => sum + bill.totalAmount);
  }

  double facilityOutflow(Facility facility) {
    return facility.installmentAmount +
        facility.extraInstallmentPayment +
        facility.maintenanceFee +
        facility.insuranceFee +
        facility.otherFee;
  }

  List<MonthlyBill> facilityBills(String facilityId) {
    return bills.where((bill) => bill.facilityId == facilityId).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<FacilityReport> get facilityReports {
    return ownerFacilities.map((facility) {
      final inflow = facilityInflow(facility.id);
      final outflow = facilityOutflow(facility);
      return FacilityReport(
        facility: facility,
        inflow: inflow,
        outflow: outflow,
        netCashflow: inflow - outflow,
      );
    }).toList();
  }

  List<MonthlyBill> get pendingBills {
    return bills
        .where((bill) => bill.status == PaymentStatus.pendingApproval)
        .toList()
      ..sort((a, b) => b.submittedAt?.compareTo(a.submittedAt ?? b.month) ?? 0);
  }

  void loginAs(UserRole role) {
    currentUser = users.firstWhere((user) => user.role == role);
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  void addFacility({
    required String name,
    required String address,
    required double installmentAmount,
    required double maintenanceFee,
    required double insuranceFee,
    required double otherFee,
  }) {
    final owner = currentUser;
    if (owner == null) return;
    facilities.add(
      Facility(
        id: 'facility_${facilities.length + 1}',
        ownerId: owner.id,
        name: name,
        address: address,
        installmentAmount: installmentAmount,
        maintenanceFee: maintenanceFee,
        insuranceFee: insuranceFee,
        otherFee: otherFee,
      ),
    );
    notifications.insert(0, 'Owner created a new facility: $name.');
    notifyListeners();
  }

  void updateFacilityCosts(
    Facility facility, {
    required double installmentAmount,
    required double extraInstallmentPayment,
    required double maintenanceFee,
    required double insuranceFee,
    required double otherFee,
  }) {
    facility.installmentAmount = installmentAmount;
    facility.extraInstallmentPayment = extraInstallmentPayment;
    facility.maintenanceFee = maintenanceFee;
    facility.insuranceFee = insuranceFee;
    facility.otherFee = otherFee;
    notifications.insert(0, '${facility.name} costs were updated.');
    notifyListeners();
  }

  void markFacilitySold(Facility facility) {
    facility.status = FacilityStatus.sold;
    facility.soldAt = DateTime.now();
    for (final tenancy in tenancies.where((item) {
      return item.facilityId == facility.id;
    })) {
      tenancy.active = false;
    }
    notifications.insert(
      0,
      '${facility.name} was marked as sold and inactive.',
    );
    notifyListeners();
  }

  void removeSoldFacility(Facility facility) {
    if (facility.status != FacilityStatus.sold) return;
    bills.removeWhere((bill) => bill.facilityId == facility.id);
    tenancies.removeWhere((tenancy) => tenancy.facilityId == facility.id);
    tenantRequests.removeWhere((request) => request.facilityId == facility.id);
    facilities.removeWhere((item) => item.id == facility.id);
    notifications.insert(0, '${facility.name} was removed after confirmation.');
    notifyListeners();
  }

  void updateBillUtilities(
    MonthlyBill bill, {
    required double electricityAmount,
    required double waterAmount,
    required double internetAmount,
  }) {
    bill.electricityAmount = electricityAmount;
    bill.waterAmount = waterAmount;
    bill.internetAmount = internetAmount;
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    notifications.insert(
      0,
      '${tenant.name} bill updated: utilities are now ${money(bill.totalAmount)} total.',
    );
    notifyListeners();
  }

  void submitPaymentSlip(MonthlyBill bill, String fileName, double amountPaid) {
    bill.slipFileName = fileName;
    bill.amountPaid = amountPaid;
    bill.submittedAt = DateTime.now();
    bill.status = PaymentStatus.pendingApproval;
    bill.rejectReason = null;
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    notifications.insert(
      0,
      '${tenant.name} submitted payment slip for ${monthLabel(bill.month)}.',
    );
    notifyListeners();
  }

  void approveBill(MonthlyBill bill) {
    bill.status = PaymentStatus.approved;
    bill.rejectReason = null;
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    notifications.insert(
      0,
      'Payment approved for ${tenant.name}, ${monthLabel(bill.month)}.',
    );
    notifyListeners();
  }

  void rejectBill(MonthlyBill bill, String reason) {
    bill.status = PaymentStatus.rejected;
    bill.rejectReason = reason;
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    notifications.insert(
      0,
      'Payment rejected for ${tenant.name}: $reason',
    );
    notifyListeners();
  }

  void addTenantRequest({
    required String title,
    required String message,
  }) {
    final user = currentUser;
    final tenancy = tenantTenancies.isEmpty ? null : tenantTenancies.first;
    if (user == null || tenancy == null) return;
    tenantRequests.add(
      TenantRequest(
        id: 'request_${tenantRequests.length + 1}',
        tenantId: user.id,
        facilityId: tenancy.facilityId,
        title: title,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
    notifications.insert(0, '${user.name} submitted a request: $title.');
    notifyListeners();
  }

  Facility facilityFor(String id) {
    return facilities.firstWhere((facility) => facility.id == id);
  }

  AppUser userFor(String id) {
    return users.firstWhere((user) => user.id == id);
  }

  void _seed() {
    users.addAll([
      AppUser(
        id: 'owner_1',
        name: 'Property Owner',
        email: 'owner@example.com',
        role: UserRole.owner,
      ),
      AppUser(
        id: 'agent_1',
        name: 'Property Agent',
        email: 'agent@example.com',
        role: UserRole.propertyAgent,
      ),
      AppUser(
        id: 'tenant_1',
        name: 'Tenant 1A',
        email: 'tenant1a@example.com',
        role: UserRole.tenant,
      ),
      AppUser(
        id: 'tenant_2',
        name: 'Tenant 1B',
        email: 'tenant1b@example.com',
        role: UserRole.tenant,
      ),
    ]);

    facilities.add(
      Facility(
        id: 'facility_1',
        ownerId: 'owner_1',
        name: 'Facility 1',
        address: 'Sample address',
        installmentAmount: 3700,
        maintenanceFee: 450,
        insuranceFee: 230,
        otherFee: 155,
      ),
    );

    tenancies.addAll([
      Tenancy(
        id: 'tenancy_1',
        facilityId: 'facility_1',
        tenantId: 'tenant_1',
        unitName: 'Room A',
        monthlyRent: 1200,
        electricityPackage: UtilityPackage.included,
        electricityCharge: 0,
        waterPackage: UtilityPackage.included,
        waterCharge: 0,
        internetPackage: UtilityPackage.included,
        internetCharge: 0,
        leaseStart: DateTime(2026),
        leaseEnd: DateTime(2026, 12, 31),
      ),
      Tenancy(
        id: 'tenancy_2',
        facilityId: 'facility_1',
        tenantId: 'tenant_2',
        unitName: 'Room B',
        monthlyRent: 600,
        electricityPackage: UtilityPackage.excluded,
        electricityCharge: 80,
        waterPackage: UtilityPackage.excluded,
        waterCharge: 25,
        internetPackage: UtilityPackage.included,
        internetCharge: 0,
        leaseStart: DateTime(2026),
        leaseEnd: DateTime(2026, 12, 31),
      ),
    ]);

    final months = [
      DateTime(2026, 1),
      DateTime(2026, 2),
      DateTime(2026, 3),
    ];
    for (final month in months) {
      for (final tenancy in tenancies) {
        bills.add(
          MonthlyBill(
            id: 'bill_${bills.length + 1}',
            facilityId: tenancy.facilityId,
            tenantId: tenancy.tenantId,
            month: month,
            rentAmount: tenancy.monthlyRent,
            electricityAmount:
                tenancy.electricityPackage == UtilityPackage.excluded
                    ? tenancy.electricityCharge
                    : 0,
            waterAmount: tenancy.waterPackage == UtilityPackage.excluded
                ? tenancy.waterCharge
                : 0,
            internetAmount: tenancy.internetPackage == UtilityPackage.excluded
                ? tenancy.internetCharge
                : 0,
          ),
        );
      }
    }

    bills[0]
      ..status = PaymentStatus.approved
      ..amountPaid = bills[0].totalAmount
      ..slipFileName = 'jan_room_a_slip.jpg'
      ..submittedAt = DateTime(2026, 1, 3);
    bills[1]
      ..status = PaymentStatus.pendingApproval
      ..amountPaid = bills[1].totalAmount
      ..slipFileName = 'jan_room_b_slip.jpg'
      ..submittedAt = DateTime(2026, 1, 4);

    notifications.addAll([
      'Tenant 1B submitted payment slip for Jan 2026.',
      'Monthly bills generated for Facility 1.',
    ]);

    tenantRequests.add(
      TenantRequest(
        id: 'request_1',
        tenantId: 'tenant_1',
        facilityId: 'facility_1',
        title: 'Air-condition service',
        message: 'The room air-conditioner is not cold enough.',
        createdAt: DateTime(2026, 1, 10),
      ),
    );
  }
}

class RentalFacilityApp extends StatefulWidget {
  const RentalFacilityApp({super.key});

  @override
  State<RentalFacilityApp> createState() => _RentalFacilityAppState();
}

class _RentalFacilityAppState extends State<RentalFacilityApp> {
  final RentalStore store = RentalStore();

  @override
  Widget build(BuildContext context) {
    return RentalStoreScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Rental Facility Manager',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F766E),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            ),
            home: store.isLoggedIn
                ? store.isManager
                    ? const OwnerHomeScreen()
                    : const TenantHomeScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class RentalStoreScope extends InheritedWidget {
  const RentalStoreScope({
    required this.store,
    required super.child,
    super.key,
  });

  final RentalStore store;

  static RentalStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RentalStoreScope>();
    assert(scope != null, 'RentalStoreScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(RentalStoreScope oldWidget) =>
      store != oldWidget.store;
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.apartment, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Rental Facility Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prototype login. Choose a role to preview the app flow.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => store.loginAs(UserRole.owner),
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Login as Owner'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => store.loginAs(UserRole.propertyAgent),
                    icon: const Icon(Icons.real_estate_agent_rounded),
                    label: const Text('Login as Property Agent'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => store.loginAs(UserRole.tenant),
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('Login as Tenant'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int selectedIndex = 0;

  static const pages = [
    OwnerReportTab(),
    FacilitiesTab(),
    PaymentApprovalsTab(),
    UtilitiesTab(),
  ];

  static const titles = [
    'Portfolio',
    'Facilities',
    'Slip Review',
    'Utilities',
  ];

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showNotifications(context),
            icon: Badge(
              label: Text('${store.notifications.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: store.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Report',
              ),
              NavigationDestination(
                icon: Icon(Icons.maps_home_work_outlined),
                selectedIcon: Icon(Icons.maps_home_work_rounded),
                label: 'Facilities',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'Review',
              ),
              NavigationDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop_rounded),
                label: 'Utilities',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerReportTab extends StatelessWidget {
  const OwnerReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final reports = store.facilityReports;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              title: 'Total Inflow',
              value: money(store.totalInflow),
              icon: Icons.arrow_downward,
            ),
            MetricCard(
              title: 'Total Outflow',
              value: money(store.totalOutflow),
              icon: Icons.arrow_upward,
            ),
            MetricCard(
              title: 'Net Cashflow',
              value: money(store.netCashflow),
              icon: Icons.account_balance_wallet,
              positive: store.netCashflow >= 0,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Tap a Facility for Individual Performance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ...reports.map((report) {
          return Card(
            elevation: 0,
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FacilityDetailScreen(facility: report.facility),
                  ),
                );
              },
              leading:
                  const CircleAvatar(child: Icon(Icons.maps_home_work_rounded)),
              title: Text(report.facility.name),
              subtitle: Text(
                '${report.facility.address} • ${facilityStatusText(report.facility)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(report.netCashflow),
                    style: TextStyle(
                      color: report.netCashflow >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                      'In ${money(report.inflow)} / Out ${money(report.outflow)}'),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class FacilityDetailScreen extends StatelessWidget {
  const FacilityDetailScreen({required this.facility, super.key});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final inflow = store.facilityInflow(facility.id);
    final outflow = store.facilityOutflow(facility);
    final net = inflow - outflow;
    final tenants = store.tenancies
        .where((tenancy) => tenancy.facilityId == facility.id)
        .toList();
    final facilityBills = store.facilityBills(facility.id);

    return Scaffold(
      appBar: AppBar(title: Text(facility.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(facility.address, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          StatusChipText(label: facilityStatusText(facility)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricCard(
                title: 'Facility Inflow',
                value: money(inflow),
                icon: Icons.south_west_rounded,
              ),
              MetricCard(
                title: 'Facility Outflow',
                value: money(outflow),
                icon: Icons.north_east_rounded,
              ),
              MetricCard(
                title: 'Facility Net',
                value: money(net),
                icon: Icons.account_balance_wallet_rounded,
                positive: net >= 0,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Tenants', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...tenants.map((tenancy) {
            final tenant = store.userFor(tenancy.tenantId);
            return Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.meeting_room_rounded),
                title: Text('${tenant.name} • ${tenancy.unitName}'),
                subtitle: Text(
                  'Rent ${money(tenancy.monthlyRent)} • Lease ${dateLabel(tenancy.leaseStart)} to ${dateLabel(tenancy.leaseEnd)}',
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('Bill Performance',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...facilityBills.map((bill) {
            final tenant = store.userFor(bill.tenantId);
            return Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
                subtitle: Text('Due ${money(bill.totalAmount)}'),
                trailing: StatusChip(status: bill.status),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FacilitiesTab extends StatelessWidget {
  const FacilitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showAddFacilityDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Facility'),
          ),
        ),
        const SizedBox(height: 12),
        ...store.ownerFacilities.map((facility) {
          final tenants = store.tenancies
              .where((tenancy) => tenancy.facilityId == facility.id)
              .toList();
          return Card(
            elevation: 0,
            child: ExpansionTile(
              leading: const Icon(Icons.apartment),
              title: Text(facility.name),
              subtitle: Text('${facility.address} • ${tenants.length} tenants'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                CostSummary(facility: facility),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => showEditCostsDialog(context, facility),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit Costs'),
                      ),
                      if (facility.status == FacilityStatus.active)
                        OutlinedButton.icon(
                          onPressed: () =>
                              showMarkSoldDialog(context, facility),
                          icon: const Icon(Icons.sell_rounded),
                          label: const Text('Mark Sold'),
                        ),
                      if (facility.status == FacilityStatus.sold)
                        FilledButton.icon(
                          onPressed: () =>
                              showRemoveFacilityDialog(context, facility),
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: const Text('Remove Sold Facility'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                ...tenants.map((tenancy) {
                  final tenant = store.userFor(tenancy.tenantId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.meeting_room),
                    title: Text('${tenant.name} • ${tenancy.unitName}'),
                    subtitle: Text(
                      'Rent ${money(tenancy.monthlyRent)} • Elec ${packageText(tenancy.electricityPackage)} • Water ${packageText(tenancy.waterPackage)} • Internet ${packageText(tenancy.internetPackage)}',
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class PaymentApprovalsTab extends StatelessWidget {
  const PaymentApprovalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final pending = store.pendingBills;
    if (pending.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle,
        title: 'No pending approvals',
        message: 'Tenant payment slips will appear here after submission.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final bill = pending[index];
        final tenant = store.userFor(bill.tenantId);
        final facility = store.facilityFor(bill.facilityId);
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tenant.name} • ${monthLabel(bill.month)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${facility.name} • Slip: ${bill.slipFileName}'),
                const SizedBox(height: 8),
                Text(
                    'Amount paid: ${money(bill.amountPaid)} / Due: ${money(bill.totalAmount)}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => store.approveBill(bill),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => store.rejectBill(
                        bill,
                        'Slip amount or reference needs checking.',
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UtilitiesTab extends StatelessWidget {
  const UtilitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final openBills = store.bills.where((bill) {
      return bill.status == PaymentStatus.notSubmitted ||
          bill.status == PaymentStatus.rejected;
    }).toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Owner Utility Entry',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Use this every 1st of the month to enter charges for electricity, water, and internet when tenants pay them separately.',
        ),
        const SizedBox(height: 12),
        ...openBills.map((bill) {
          final tenant = store.userFor(bill.tenantId);
          final facility = store.facilityFor(bill.facilityId);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.bolt),
              title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
              subtitle: Text(
                '${facility.name} • Elec ${money(bill.electricityAmount)} • Water ${money(bill.waterAmount)} • Internet ${money(bill.internetAmount)}',
              ),
              trailing: OutlinedButton(
                onPressed: () => showUtilityDialog(context, bill),
                child: const Text('Edit'),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  int selectedIndex = 0;

  static const pages = [
    TenantPayTab(),
    TenantPaymentHistoryTab(),
    TenantRequestsTab(),
    TenantTermsTab(),
  ];

  static const titles = [
    'Pay',
    'Payment History',
    'Requests',
    'Tenancy Term',
  ];

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final user = store.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${titles[selectedIndex]} • ${user.name}'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showNotifications(context),
            icon: Badge(
              label: Text('${store.notifications.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: store.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            height: 72,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Pay',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.handyman_outlined),
                selectedIcon: Icon(Icons.handyman_rounded),
                label: 'Request',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description_rounded),
                label: 'Terms',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantPayTab extends StatelessWidget {
  const TenantPayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final bills = store.tenantPayableBills;
    if (bills.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_rounded,
        title: 'All paid',
        message: 'Approved bills will remain available in Payment History.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Current Bills', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...bills.map((bill) => TenantBillCard(bill: bill, showPayAction: true)),
      ],
    );
  }
}

class TenantPaymentHistoryTab extends StatelessWidget {
  const TenantPaymentHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final history = store.tenantPaymentHistory;
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No payment history yet',
        message: 'Submitted and approved payments will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Payment History', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...history.map((bill) => TenantBillCard(bill: bill)),
      ],
    );
  }
}

class TenantRequestsTab extends StatelessWidget {
  const TenantRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final requests = store.currentTenantRequests;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showAddRequestDialog(context),
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('New Request'),
          ),
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          const EmptyState(
            icon: Icons.handyman_rounded,
            title: 'No requests yet',
            message:
                'Submit repair, document, or general tenancy requests here.',
          )
        else
          ...requests.map((request) {
            final facility = store.facilityFor(request.facilityId);
            return Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: Text(request.title),
                subtitle: Text(
                  '${facility.name} • ${request.message}\n${dateLabel(request.createdAt)}',
                ),
                trailing: StatusChipText(label: request.status),
              ),
            );
          }),
      ],
    );
  }
}

class TenantTermsTab extends StatelessWidget {
  const TenantTermsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final tenancies = store.tenantTenancies;
    if (tenancies.isEmpty) {
      return const EmptyState(
        icon: Icons.description_rounded,
        title: 'No tenancy found',
        message: 'Your tenancy agreement will appear here once assigned.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tenancy Agreement View',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...tenancies.map((tenancy) {
          final facility = store.facilityFor(tenancy.facilityId);
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(facility.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(facility.address),
                  const Divider(height: 24),
                  AmountRow(label: 'Monthly Rent', value: tenancy.monthlyRent),
                  Text('Unit / Room: ${tenancy.unitName}'),
                  Text(
                    'Lease Period: ${dateLabel(tenancy.leaseStart)} to ${dateLabel(tenancy.leaseEnd)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Utilities: Electricity ${packageText(tenancy.electricityPackage)}, Water ${packageText(tenancy.waterPackage)}, Internet ${packageText(tenancy.internetPackage)}',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('View Agreement File'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class TenantBillCard extends StatelessWidget {
  const TenantBillCard({
    required this.bill,
    this.showPayAction = false,
    super.key,
  });

  final MonthlyBill bill;
  final bool showPayAction;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facility = store.facilityFor(bill.facilityId);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${facility.name} • ${monthLabel(bill.month)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusChip(status: bill.status),
              ],
            ),
            const SizedBox(height: 12),
            BillBreakdown(bill: bill),
            if (showPayAction) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => showSubmitSlipDialog(context, bill),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Submit Payment Slip'),
                ),
              ),
            ],
            if (bill.slipFileName != null) ...[
              const SizedBox(height: 8),
              Text('Uploaded slip: ${bill.slipFileName}'),
            ],
            if (bill.rejectReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reject reason: ${bill.rejectReason}',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.positive,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    final color = positive == null
        ? Theme.of(context).colorScheme.primary
        : positive!
            ? Colors.green.shade700
            : Colors.red.shade700;
    return SizedBox(
      width: 230,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CostSummary extends StatelessWidget {
  const CostSummary({required this.facility, super.key});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MiniPill(
            label: 'Installment', value: money(facility.installmentAmount)),
        MiniPill(
            label: 'Extra', value: money(facility.extraInstallmentPayment)),
        MiniPill(label: 'Maintenance', value: money(facility.maintenanceFee)),
        MiniPill(label: 'Insurance', value: money(facility.insuranceFee)),
        MiniPill(label: 'Other', value: money(facility.otherFee)),
      ],
    );
  }
}

class BillBreakdown extends StatelessWidget {
  const BillBreakdown({required this.bill, super.key});

  final MonthlyBill bill;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AmountRow(label: 'Rent', value: bill.rentAmount),
        AmountRow(label: 'Electricity', value: bill.electricityAmount),
        AmountRow(label: 'Water', value: bill.waterAmount),
        AmountRow(label: 'Internet', value: bill.internetAmount),
        const Divider(),
        AmountRow(label: 'Total Due', value: bill.totalAmount, bold: true),
      ],
    );
  }
}

class AmountRow extends StatelessWidget {
  const AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
    super.key,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(money(value), style: style),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaymentStatus.notSubmitted => ('Not Submitted', Colors.grey),
      PaymentStatus.pendingApproval => ('Pending', Colors.orange),
      PaymentStatus.approved => ('Approved', Colors.green),
      PaymentStatus.rejected => ('Rejected', Colors.red),
    };
    return Chip(
      label: Text(label),
      side: BorderSide(color: color.shade300),
      backgroundColor: color.shade50,
      labelStyle: TextStyle(color: color.shade900),
    );
  }
}

class StatusChipText extends StatelessWidget {
  const StatusChipText({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}

class MiniPill extends StatelessWidget {
  const MiniPill({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value'),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

void showAddFacilityDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final name = TextEditingController(text: 'New Facility');
  final address = TextEditingController(text: 'Address');
  final installment = TextEditingController(text: '3700');
  final maintenance = TextEditingController(text: '450');
  final insurance = TextEditingController(text: '230');
  final other = TextEditingController(text: '155');

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Facility'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: name, label: 'Facility Name'),
            AppTextField(controller: address, label: 'Address'),
            AppTextField(controller: installment, label: 'Installment'),
            AppTextField(controller: maintenance, label: 'Maintenance'),
            AppTextField(controller: insurance, label: 'Insurance'),
            AppTextField(controller: other, label: 'Other Fee'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            store.addFacility(
              name: name.text,
              address: address.text,
              installmentAmount: parseMoney(installment.text),
              maintenanceFee: parseMoney(maintenance.text),
              insuranceFee: parseMoney(insurance.text),
              otherFee: parseMoney(other.text),
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showEditCostsDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  final installment = TextEditingController(
      text: facility.installmentAmount.toStringAsFixed(0));
  final extra = TextEditingController(
      text: facility.extraInstallmentPayment.toStringAsFixed(0));
  final maintenance =
      TextEditingController(text: facility.maintenanceFee.toStringAsFixed(0));
  final insurance =
      TextEditingController(text: facility.insuranceFee.toStringAsFixed(0));
  final other =
      TextEditingController(text: facility.otherFee.toStringAsFixed(0));

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Edit ${facility.name} Costs'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: installment, label: 'Installment'),
            AppTextField(controller: extra, label: 'Extra Installment Payment'),
            AppTextField(controller: maintenance, label: 'Maintenance'),
            AppTextField(controller: insurance, label: 'Insurance'),
            AppTextField(controller: other, label: 'Other Fee'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            store.updateFacilityCosts(
              facility,
              installmentAmount: parseMoney(installment.text),
              extraInstallmentPayment: parseMoney(extra.text),
              maintenanceFee: parseMoney(maintenance.text),
              insuranceFee: parseMoney(insurance.text),
              otherFee: parseMoney(other.text),
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showMarkSoldDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Mark ${facility.name} as sold?'),
      content: const Text(
        'This will keep the facility records but mark it inactive and stop active tenancy tracking. You can remove it only after it is marked sold.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            store.markFacilitySold(facility);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.sell_rounded),
          label: const Text('Confirm Sold'),
        ),
      ],
    ),
  );
}

void showRemoveFacilityDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Remove ${facility.name}?'),
      content: const Text(
        'This facility is already marked sold. Removing it will delete the prototype records for its tenancies, bills, and requests. This is not a direct delete.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep'),
        ),
        FilledButton.icon(
          onPressed: () {
            store.removeSoldFacility(facility);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Remove'),
        ),
      ],
    ),
  );
}

void showUtilityDialog(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final electricity =
      TextEditingController(text: bill.electricityAmount.toStringAsFixed(0));
  final water =
      TextEditingController(text: bill.waterAmount.toStringAsFixed(0));
  final internet =
      TextEditingController(text: bill.internetAmount.toStringAsFixed(0));

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Utilities for ${monthLabel(bill.month)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: electricity, label: 'Electricity Charge'),
          AppTextField(controller: water, label: 'Water Charge'),
          AppTextField(controller: internet, label: 'Internet Charge'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            store.updateBillUtilities(
              bill,
              electricityAmount: parseMoney(electricity.text),
              waterAmount: parseMoney(water.text),
              internetAmount: parseMoney(internet.text),
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showSubmitSlipDialog(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final fileName = TextEditingController(
      text: 'payment_slip_${monthLabel(bill.month).replaceAll(' ', '_')}.jpg');
  final amount =
      TextEditingController(text: bill.totalAmount.toStringAsFixed(0));

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Submit Payment Slip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: fileName, label: 'Slip File Name'),
          AppTextField(controller: amount, label: 'Amount Paid'),
          const SizedBox(height: 8),
          const Text(
            'Prototype note: real app will use image/PDF picker and Firebase Storage.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            store.submitPaymentSlip(
              bill,
              fileName.text,
              parseMoney(amount.text),
            );
            Navigator.pop(context);
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

void showAddRequestDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final title = TextEditingController(text: 'Repair request');
  final message = TextEditingController(text: 'Please help check this issue.');

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New Tenant Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: title, label: 'Request Title'),
          AppTextField(controller: message, label: 'Message'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            store.addTenantRequest(
              title: title.text,
              message: message.text,
            );
            Navigator.pop(context);
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

void showNotifications(BuildContext context) {
  final store = RentalStoreScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (store.notifications.isEmpty)
            const ListTile(title: Text('No notifications yet')),
          ...store.notifications.map(
            (message) => ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(message),
            ),
          ),
        ],
      );
    },
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}

String money(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  final whole = abs.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '$sign\$${buffer.toString()}';
}

String monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String packageText(UtilityPackage package) {
  return package == UtilityPackage.included ? 'Included' : 'Excluded';
}

String facilityStatusText(Facility facility) {
  if (facility.status == FacilityStatus.sold) {
    final soldAt = facility.soldAt;
    return soldAt == null ? 'Sold' : 'Sold on ${dateLabel(soldAt)}';
  }
  return 'Active';
}

String dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

double parseMoney(String text) {
  return double.tryParse(
          text.replaceAll(',', '').replaceAll('\$', '').trim()) ??
      0;
}
