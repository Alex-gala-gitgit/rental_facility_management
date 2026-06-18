import 'dart:math' as math;

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
    this.originAddress,
    this.dateOfBirth,
    this.sex,
    this.accountStatus = 'Active',
    this.profileComplete = true,
    this.invitationSentAt,
    this.accountCreatedAt,
    this.avatarStyle = 0,
    this.paymentReminderAfterDays = 3,
    this.paymentReminderFrequencyDays = 2,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? originAddress;
  final DateTime? dateOfBirth;
  final String? sex;
  final String accountStatus;
  bool profileComplete;
  DateTime? invitationSentAt;
  DateTime? accountCreatedAt;
  int avatarStyle;
  int paymentReminderAfterDays;
  int paymentReminderFrequencyDays;

  bool get invitationSent => invitationSentAt != null;
  bool get accountCreated => profileComplete || accountCreatedAt != null;
}

class Facility {
  Facility({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.addressLine,
    required this.postcode,
    required this.city,
    required this.state,
    required this.installmentAmount,
    required this.maintenanceFee,
    required this.insuranceFee,
    this.extraInstallmentPayment = 0,
    this.status = FacilityStatus.active,
    this.soldAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String addressLine;
  final String postcode;
  final String city;
  final String state;
  double installmentAmount;
  double maintenanceFee;
  double insuranceFee;
  double extraInstallmentPayment;
  FacilityStatus status;
  DateTime? soldAt;

  String get address => '$addressLine, $postcode $city, $state';
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
    this.carParkIncluded = false,
    this.carParkDetails = 'Not included',
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
  bool carParkIncluded;
  String carParkDetails;
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
    this.electricityUsageKwh = 0,
    this.utilityEvidenceFileName,
    this.status = PaymentStatus.notSubmitted,
    this.slipFileName,
    this.amountPaid = 0,
    this.submittedAt,
    this.rejectReason,
    this.reviewedAt,
  });

  final String id;
  final String facilityId;
  final String tenantId;
  final DateTime month;
  final double rentAmount;
  double electricityUsageKwh;
  double electricityAmount;
  double waterAmount;
  double internetAmount;
  String? utilityEvidenceFileName;
  PaymentStatus status;
  String? slipFileName;
  double amountPaid;
  DateTime? submittedAt;
  String? rejectReason;
  DateTime? reviewedAt;

  double get totalAmount =>
      rentAmount + electricityAmount + waterAmount + internetAmount;

  double get totalUtilityAmount =>
      electricityAmount + waterAmount + internetAmount;
}

class MonthlyFinancialSummary {
  const MonthlyFinancialSummary({
    required this.month,
    required this.collection,
    required this.expenses,
  });

  final int month;
  final double collection;
  final double expenses;
}

class FinancialBreakdownItem {
  const FinancialBreakdownItem({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;
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
    this.reviewedAt,
  });

  final String id;
  final String tenantId;
  final String facilityId;
  final String title;
  final String message;
  final DateTime createdAt;
  String status;
  DateTime? reviewedAt;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  bool isRead;
}

class PaymentReviewEvent {
  PaymentReviewEvent({
    required this.id,
    required this.billId,
    required this.status,
    required this.timestamp,
    this.reason,
  });

  final String id;
  final String billId;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? reason;
}

class AdditionalIncome {
  AdditionalIncome({
    required this.id,
    required this.facilityId,
    required this.month,
    required this.category,
    required this.amount,
    required this.note,
  });

  final String id;
  final String facilityId;
  final DateTime month;
  final String category;
  final double amount;
  final String note;
}

class RentalStore extends ChangeNotifier {
  static const double electricityRatePerKwh = 0.516;

  RentalStore({DateTime? now}) : _now = now ?? DateTime.now() {
    _seed();
  }

  final DateTime _now;
  final List<AppUser> users = [];
  final List<Facility> facilities = [];
  final List<Tenancy> tenancies = [];
  final List<MonthlyBill> bills = [];
  final List<TenantRequest> tenantRequests = [];
  final List<AppNotification> notifications = [];
  final List<PaymentReviewEvent> paymentReviewHistory = [];
  final List<AdditionalIncome> additionalIncomes = [];

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;
  bool get isOwner => currentUser?.role == UserRole.owner;
  bool get isPropertyAgent => currentUser?.role == UserRole.propertyAgent;
  bool get isManager => isOwner || isPropertyAgent;
  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;
  int get elapsedMonthsThisYear => _now.month;

  bool isCurrentOrPastMonth(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    final currentMonth = DateTime(_now.year, _now.month);
    return !normalizedMonth.isAfter(currentMonth);
  }

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
    final facilityIds = ownerFacilities.map((facility) => facility.id).toSet();
    final rentalIncome = bills
        .where((bill) =>
            facilityIds.contains(bill.facilityId) &&
            isCurrentOrPastMonth(bill.month) &&
            bill.status == PaymentStatus.approved)
        .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    final otherIncome = additionalIncomes
        .where((income) =>
            facilityIds.contains(income.facilityId) &&
            isCurrentOrPastMonth(income.month))
        .fold<double>(0, (sum, income) => sum + income.amount);
    return rentalIncome + otherIncome;
  }

  double get monthlyTotalOutflow {
    return ownerFacilities.fold<double>(
      0,
      (sum, facility) => sum + monthlyFacilityOutflow(facility),
    );
  }

  double get totalOutflow {
    return monthlyTotalOutflow * elapsedMonthsThisYear;
  }

  double get netCashflow => totalInflow - totalOutflow;

  double facilityInflow(String facilityId) {
    final rentalIncome = bills.where((bill) {
      return bill.facilityId == facilityId &&
          isCurrentOrPastMonth(bill.month) &&
          bill.status == PaymentStatus.approved;
    }).fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    final otherIncome = additionalIncomes
        .where((income) =>
            income.facilityId == facilityId &&
            isCurrentOrPastMonth(income.month))
        .fold<double>(0, (sum, income) => sum + income.amount);
    return rentalIncome + otherIncome;
  }

  double monthlyFacilityOutflow(Facility facility) {
    return facility.installmentAmount +
        facility.extraInstallmentPayment +
        facility.maintenanceFee +
        facility.insuranceFee;
  }

  double facilityOutflow(Facility facility) {
    return monthlyFacilityOutflow(facility) * elapsedMonthsThisYear;
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

  List<MonthlyBill> billsForTenant(String tenantId) {
    return bills.where((bill) => bill.tenantId == tenantId).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<MonthlyFinancialSummary> yearlyFinancialSummary(int year) {
    final facilityIds = ownerFacilities.map((facility) => facility.id).toSet();
    return List.generate(12, (index) {
      final month = index + 1;
      final isFutureMonth = DateTime(year, month).isAfter(
        DateTime(_now.year, _now.month),
      );
      if (isFutureMonth) {
        return MonthlyFinancialSummary(
          month: month,
          collection: 0,
          expenses: 0,
        );
      }
      final monthlyCollection = bills.where((bill) {
        return facilityIds.contains(bill.facilityId) &&
            bill.month.year == year &&
            bill.month.month == month &&
            bill.status == PaymentStatus.approved;
      }).fold<double>(0, (sum, bill) => sum + bill.totalAmount);
      final otherIncome = additionalIncomes.where((income) {
        return facilityIds.contains(income.facilityId) &&
            income.month.year == year &&
            income.month.month == month;
      }).fold<double>(0, (sum, income) => sum + income.amount);
      return MonthlyFinancialSummary(
        month: month,
        collection: monthlyCollection + otherIncome,
        expenses: monthlyTotalOutflow,
      );
    });
  }

  List<FinancialBreakdownItem> monthlyCollectionBreakdown(
    int year,
    int month,
  ) {
    if (!isCurrentOrPastMonth(DateTime(year, month))) return [];
    final facilityIds = ownerFacilities.map((facility) => facility.id).toSet();
    final items = <FinancialBreakdownItem>[];
    for (final bill in bills.where((bill) {
      return facilityIds.contains(bill.facilityId) &&
          bill.month.year == year &&
          bill.month.month == month &&
          bill.status == PaymentStatus.approved;
    })) {
      final tenancy = tenancies.firstWhere(
        (item) =>
            item.tenantId == bill.tenantId &&
            item.facilityId == bill.facilityId,
      );
      items.add(
        FinancialBreakdownItem(
          label:
              '${userFor(bill.tenantId).name} • ${tenancy.unitName} • ${facilityFor(bill.facilityId).name}',
          amount: bill.totalAmount,
        ),
      );
    }
    for (final income in additionalIncomes.where((income) {
      return facilityIds.contains(income.facilityId) &&
          income.month.year == year &&
          income.month.month == month;
    })) {
      items.add(
        FinancialBreakdownItem(
          label: '${income.category} • ${facilityFor(income.facilityId).name}',
          amount: income.amount,
        ),
      );
    }
    return items;
  }

  List<FinancialBreakdownItem> monthlyExpenseBreakdown(int year, int month) {
    if (!isCurrentOrPastMonth(DateTime(year, month))) return [];
    final items = <FinancialBreakdownItem>[];
    for (final facility in ownerFacilities) {
      final costs = <(String, double)>[
        ('Installment', facility.installmentAmount),
        ('Extra installment', facility.extraInstallmentPayment),
        ('Maintenance', facility.maintenanceFee),
        ('Fire insurance', facility.insuranceFee),
      ];
      for (final cost in costs.where((cost) => cost.$2 > 0)) {
        items.add(
          FinancialBreakdownItem(
            label: '${facility.name} • ${cost.$1}',
            amount: cost.$2,
          ),
        );
      }
    }
    return items;
  }

  void loginAs(UserRole role) {
    currentUser = users.firstWhere((user) => user.role == role);
    notifyListeners();
  }

  void addTenantToFacility({
    required Facility facility,
    required String fullName,
    required String email,
    required String originAddress,
    required DateTime dateOfBirth,
    required String sex,
    required String unitName,
    required double monthlyRent,
    required DateTime leaseStart,
    required DateTime leaseEnd,
    required UtilityPackage electricityPackage,
    required UtilityPackage waterPackage,
    required UtilityPackage internetPackage,
    required bool carParkIncluded,
    required String carParkDetails,
  }) {
    final tenantId = 'tenant_${users.length + 1}';
    final tenant = AppUser(
      id: tenantId,
      name: fullName,
      email: email,
      role: UserRole.tenant,
      originAddress: originAddress,
      dateOfBirth: dateOfBirth,
      sex: sex,
      profileComplete: false,
    );
    users.add(tenant);
    tenancies.add(
      Tenancy(
        id: 'tenancy_${tenancies.length + 1}',
        facilityId: facility.id,
        tenantId: tenantId,
        unitName: unitName,
        monthlyRent: monthlyRent,
        electricityPackage: electricityPackage,
        electricityCharge: 0,
        waterPackage: waterPackage,
        waterCharge: 0,
        internetPackage: internetPackage,
        internetCharge: 0,
        leaseStart: leaseStart,
        leaseEnd: leaseEnd,
        carParkIncluded: carParkIncluded,
        carParkDetails:
            carParkIncluded ? carParkDetails : 'Not included in agreement',
      ),
    );
    _notify('$fullName was added to ${facility.name}, $unitName.');
    notifyListeners();
  }

  void sendTenantInvitation(AppUser tenant) {
    tenant.invitationSentAt = DateTime.now();
    _notify(
        'Profile invitation prepared for ${tenant.name} at ${tenant.email}.');
    notifyListeners();
  }

  void acceptTenantInvitation(AppUser tenant) {
    if (!tenant.invitationSent) return;
    tenant.accountCreatedAt = DateTime.now();
    tenant.profileComplete = true;
    _notify(
        '${tenant.name} accepted the invitation and created a tenant account.');
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  Facility? addFacility({
    required String name,
    required String addressLine,
    required String postcode,
    required String city,
    required String state,
    required double installmentAmount,
    required double maintenanceFee,
    required double insuranceFee,
  }) {
    final owner = currentUser;
    if (owner == null) return null;
    final facility = Facility(
      id: 'facility_${facilities.length + 1}',
      ownerId: owner.id,
      name: name,
      addressLine: addressLine,
      postcode: postcode,
      city: city,
      state: state,
      installmentAmount: installmentAmount,
      maintenanceFee: maintenanceFee,
      insuranceFee: insuranceFee,
    );
    facilities.add(facility);
    _notify('Owner created a new facility: $name.');
    notifyListeners();
    return facility;
  }

  void updateFacilityCosts(
    Facility facility, {
    required double installmentAmount,
    required double extraInstallmentPayment,
    required double maintenanceFee,
    required double insuranceFee,
  }) {
    facility.installmentAmount = installmentAmount;
    facility.extraInstallmentPayment = extraInstallmentPayment;
    facility.maintenanceFee = maintenanceFee;
    facility.insuranceFee = insuranceFee;
    _notify('${facility.name} costs were updated.');
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
    _notify('${facility.name} was marked as sold and inactive.');
    notifyListeners();
  }

  void removeSoldFacility(Facility facility) {
    if (facility.status != FacilityStatus.sold) return;
    bills.removeWhere((bill) => bill.facilityId == facility.id);
    tenancies.removeWhere((tenancy) => tenancy.facilityId == facility.id);
    tenantRequests.removeWhere((request) => request.facilityId == facility.id);
    additionalIncomes.removeWhere((income) => income.facilityId == facility.id);
    facilities.removeWhere((item) => item.id == facility.id);
    _notify('${facility.name} was removed after confirmation.');
    notifyListeners();
  }

  void updateBillUtilities(
    MonthlyBill bill, {
    required double electricityUsageKwh,
    required double waterAmount,
    required double internetAmount,
    required String utilityEvidenceFileName,
  }) {
    bill.electricityUsageKwh = electricityUsageKwh;
    bill.electricityAmount =
        electricityUsageKwh * RentalStore.electricityRatePerKwh;
    bill.waterAmount = waterAmount;
    bill.internetAmount = internetAmount;
    bill.utilityEvidenceFileName = utilityEvidenceFileName.trim().isEmpty
        ? null
        : utilityEvidenceFileName.trim();
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify(
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
    _notify(
        '${tenant.name} submitted payment slip for ${monthLabel(bill.month)}.');
    notifyListeners();
  }

  void approveBill(MonthlyBill bill) {
    bill.status = PaymentStatus.approved;
    bill.rejectReason = null;
    bill.reviewedAt = DateTime.now();
    paymentReviewHistory.add(
      PaymentReviewEvent(
        id: 'review_${paymentReviewHistory.length + 1}',
        billId: bill.id,
        status: PaymentStatus.approved,
        timestamp: bill.reviewedAt!,
      ),
    );
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify('Payment approved for ${tenant.name}, ${monthLabel(bill.month)}.');
    notifyListeners();
  }

  void rejectBill(MonthlyBill bill, String reason) {
    bill.status = PaymentStatus.rejected;
    bill.rejectReason = reason;
    bill.reviewedAt = DateTime.now();
    paymentReviewHistory.add(
      PaymentReviewEvent(
        id: 'review_${paymentReviewHistory.length + 1}',
        billId: bill.id,
        status: PaymentStatus.rejected,
        timestamp: bill.reviewedAt!,
        reason: reason,
      ),
    );
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify(
      'Payment rejected for ${tenant.name}. Please resubmit: $reason',
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
    _notify('${user.name} submitted a request: $title.');
    notifyListeners();
  }

  void reviewTenantRequest(TenantRequest request, String status) {
    request.status = status;
    request.reviewedAt = DateTime.now();
    final tenant = userFor(request.tenantId);
    _notify('${tenant.name} request "${request.title}" was $status.');
    notifyListeners();
  }

  void addAdditionalIncome({
    required Facility facility,
    required DateTime month,
    required String category,
    required double amount,
    required String note,
  }) {
    additionalIncomes.add(
      AdditionalIncome(
        id: 'income_${additionalIncomes.length + 1}',
        facilityId: facility.id,
        month: DateTime(month.year, month.month),
        category: category,
        amount: amount,
        note: note,
      ),
    );
    _notify(
      '${money(amount)} $category income added to ${facility.name} for ${monthLabel(month)}.',
    );
    notifyListeners();
  }

  void updateReminderSettings({
    required int afterDays,
    required int frequencyDays,
  }) {
    final user = currentUser;
    if (user == null) return;
    user.paymentReminderAfterDays = afterDays;
    user.paymentReminderFrequencyDays = frequencyDays;
    _notify('Payment reminder settings were updated.');
    notifyListeners();
  }

  void updateAvatar(int avatarStyle) {
    final user = currentUser;
    if (user == null) return;
    user.avatarStyle = avatarStyle;
    notifyListeners();
  }

  void markNotificationRead(AppNotification notification) {
    notification.isRead = true;
    notifyListeners();
  }

  void _notify(String message) {
    notifications.insert(
      0,
      AppNotification(
        id: 'notification_${notifications.length + 1}',
        message: message,
        createdAt: DateTime.now(),
      ),
    );
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
        name: 'Alex',
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
        name: 'Nur Aisyah Binti Rahman',
        email: 'tenant1a@example.com',
        role: UserRole.tenant,
        originAddress: '22 Jalan Melur, Shah Alam, Selangor',
        dateOfBirth: DateTime(1996, 5, 14),
        sex: 'Female',
      ),
      AppUser(
        id: 'tenant_2',
        name: 'Daniel Lim Wei Jian',
        email: 'tenant1b@example.com',
        role: UserRole.tenant,
        originAddress: '18 Lorong Damai, Ipoh, Perak',
        dateOfBirth: DateTime(1992, 11, 2),
        sex: 'Male',
      ),
    ]);

    facilities.add(
      Facility(
        id: 'facility_1',
        ownerId: 'owner_1',
        name: 'Facility 1',
        addressLine: '12 Jalan Harmoni 3',
        postcode: '47301',
        city: 'Petaling Jaya',
        state: 'Selangor',
        installmentAmount: 3700,
        maintenanceFee: 450,
        insuranceFee: 230,
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
        carParkIncluded: true,
        carParkDetails: '1 covered car park bay (A-18)',
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
        carParkIncluded: false,
        carParkDetails: 'Not included in agreement',
      ),
    ]);

    const seedYear = 2026;
    final lastSeedMonth = _now.year > seedYear
        ? 12
        : _now.year == seedYear
            ? _now.month
            : 0;
    final months = List.generate(
      lastSeedMonth,
      (index) => DateTime(seedYear, index + 1),
    );
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
            electricityUsageKwh: tenancy.electricityPackage ==
                    UtilityPackage.excluded
                ? tenancy.electricityCharge / RentalStore.electricityRatePerKwh
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
      ..submittedAt = DateTime(2026, 1, 3)
      ..reviewedAt = DateTime(2026, 1, 4);
    bills[1]
      ..status = PaymentStatus.pendingApproval
      ..amountPaid = bills[1].totalAmount
      ..slipFileName = 'jan_room_b_slip.jpg'
      ..submittedAt = DateTime(2026, 1, 4);
    bills[3]
      ..status = PaymentStatus.approved
      ..amountPaid = bills[3].totalAmount
      ..slipFileName = 'feb_room_b_slip.jpg'
      ..submittedAt = DateTime(2026, 2, 4)
      ..reviewedAt = DateTime(2026, 2, 5);
    bills[4]
      ..status = PaymentStatus.approved
      ..amountPaid = bills[4].totalAmount
      ..slipFileName = 'mar_room_a_slip.jpg'
      ..submittedAt = DateTime(2026, 3, 3)
      ..reviewedAt = DateTime(2026, 3, 4);
    for (final bill in bills.where((bill) => bill.month.month >= 4)) {
      bill
        ..status = PaymentStatus.approved
        ..amountPaid = bill.totalAmount
        ..slipFileName =
            '${FinancialChartPainter.monthNames[bill.month.month - 1].toLowerCase()}_${bill.tenantId}_slip.jpg'
        ..submittedAt = DateTime(seedYear, bill.month.month, 3)
        ..reviewedAt = DateTime(seedYear, bill.month.month, 4);
    }

    for (final bill in bills.where((bill) {
      return bill.status == PaymentStatus.approved && bill.reviewedAt != null;
    })) {
      paymentReviewHistory.add(
        PaymentReviewEvent(
          id: 'review_${paymentReviewHistory.length + 1}',
          billId: bill.id,
          status: PaymentStatus.approved,
          timestamp: bill.reviewedAt!,
        ),
      );
    }

    _notify('Tenant 1B submitted payment slip for Jan 2026.');
    _notify('Monthly bills generated for Facility 1.');

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
                seedColor: const Color(0xFF3156A3),
                brightness: Brightness.light,
                surface: Colors.white,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF4F7FC),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF4F7FC),
                foregroundColor: Color(0xFF17233C),
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleTextStyle: TextStyle(
                  color: Color(0xFF17233C),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              cardTheme: CardTheme(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE4EAF4)),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xFFDDE7FF),
                elevation: 0,
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  return TextStyle(
                    color: states.contains(MaterialState.selected)
                        ? const Color(0xFF24498F)
                        : const Color(0xFF667085),
                    fontWeight: states.contains(MaterialState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  );
                }),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF8FAFD),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD6DEEB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD6DEEB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3156A3),
                    width: 2,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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
  int selectedIndex = 2;

  static const pages = [
    FacilitiesTab(),
    AdvancedReviewTab(),
    OwnerReportTab(),
    UtilitiesTab(),
    OwnerAccountTab(),
  ];

  static const titles = [
    'Facilities',
    'Slip Review',
    'Main',
    'Utilities',
    'Account',
  ];

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final title = selectedIndex == 2
        ? '${timeGreeting(DateTime.now())}, ${firstName(store.currentUser!.name)}'
        : titles[selectedIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showNotifications(context),
            icon: store.unreadNotificationCount == 0
                ? const Icon(Icons.notifications_outlined)
                : Badge(
                    label: Text('${store.unreadNotificationCount}'),
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
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Main',
              ),
              NavigationDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop_rounded),
                label: 'Utilities',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                selectedIcon: Icon(Icons.account_circle_rounded),
                label: 'Account',
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
    final reportYear = DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Total Rental Collection',
                  value: money(store.totalInflow),
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF16856B),
                  fullWidth: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinancialDetailsScreen(
                        mode: FinancialDetailMode.collection,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Total Expenses',
                  value: money(store.totalOutflow),
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFD16432),
                  fullWidth: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinancialDetailsScreen(
                        mode: FinancialDetailMode.expenses,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Net Rental Income',
                  value: money(store.netCashflow),
                  icon: Icons.savings_rounded,
                  positive: store.netCashflow >= 0,
                  fullWidth: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinancialDetailsScreen(
                        mode: FinancialDetailMode.netIncome,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => showAddIncomeDialog(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Add Other Monthly Income'),
          ),
        ),
        const SizedBox(height: 16),
        YearlyFinancialChart(
          year: reportYear,
          summaries: store.yearlyFinancialSummary(reportYear),
        ),
        const SizedBox(height: 20),
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
              trailing: SizedBox(
                width: 108,
                child: Column(
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
                      '${money(report.inflow)} / ${money(report.outflow)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({required this.facility, super.key});

  final Facility facility;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  String? selectedTenantId;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facility = widget.facility;
    final inflow = store.facilityInflow(facility.id);
    final outflow = store.facilityOutflow(facility);
    final net = inflow - outflow;
    final tenants = store.tenancies
        .where((tenancy) => tenancy.facilityId == facility.id)
        .toList();
    final facilityBills = store.facilityBills(facility.id);
    final displayedBills = selectedTenantId == null
        ? facilityBills
        : facilityBills
            .where((bill) => bill.tenantId == selectedTenantId)
            .toList();
    final selectedTenant =
        selectedTenantId == null ? null : store.userFor(selectedTenantId!);

    return Scaffold(
      appBar: AppBar(title: Text(facility.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(facility.address, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          StatusChipText(label: facilityStatusText(facility)),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Rental Collection',
                    value: money(inflow),
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF16856B),
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Facility Expenses',
                    value: money(outflow),
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFD16432),
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Net Rental Income',
                    value: money(net),
                    icon: Icons.savings_rounded,
                    positive: net >= 0,
                    fullWidth: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Tenants', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (selectedTenantId != null)
                TextButton.icon(
                  onPressed: () => setState(() => selectedTenantId = null),
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('All Tenants'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...tenants.map((tenancy) {
            final tenant = store.userFor(tenancy.tenantId);
            final selected = tenant.id == selectedTenantId;
            return Card(
              elevation: 0,
              color: selected ? const Color(0xFFE8EEFC) : null,
              child: ListTile(
                onTap: () {
                  setState(() => selectedTenantId = tenant.id);
                },
                leading: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.meeting_room_rounded,
                  color: selected ? const Color(0xFF3156A3) : null,
                ),
                title: Text('${tenant.name} • ${tenancy.unitName}'),
                subtitle: Text(
                  'Rent ${money(tenancy.monthlyRent)} • Lease ${dateLabel(tenancy.leaseStart)} to ${dateLabel(tenancy.leaseEnd)}',
                ),
                trailing: IconButton(
                  tooltip: 'View tenant profile',
                  onPressed: () => showTenantProfileDialog(
                    context,
                    tenant: tenant,
                    tenancy: tenancy,
                  ),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            selectedTenant == null
                ? 'Bill Performance • All Tenants'
                : 'Bill Performance • ${selectedTenant.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (displayedBills.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No bill records',
              message: 'This tenant does not have any bill records yet.',
            )
          else
            ...displayedBills.map((bill) {
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

enum FinancialDetailMode { collection, expenses, netIncome }

class FinancialDetailsScreen extends StatelessWidget {
  const FinancialDetailsScreen({required this.mode, super.key});

  final FinancialDetailMode mode;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final title = switch (mode) {
      FinancialDetailMode.collection => 'Rental Collection Details',
      FinancialDetailMode.expenses => 'Expense Details',
      FinancialDetailMode.netIncome => 'Net Rental Income Details',
    };
    final total = switch (mode) {
      FinancialDetailMode.collection => store.totalInflow,
      FinancialDetailMode.expenses => store.totalOutflow,
      FinancialDetailMode.netIncome => store.netCashflow,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Icon(
                      switch (mode) {
                        FinancialDetailMode.collection =>
                          Icons.payments_rounded,
                        FinancialDetailMode.expenses =>
                          Icons.receipt_long_rounded,
                        FinancialDetailMode.netIncome => Icons.savings_rounded,
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Facilities Total',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF667085),
                                  ),
                        ),
                        Text(
                          money(total),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...store.ownerFacilities.map((facility) {
            return switch (mode) {
              FinancialDetailMode.collection =>
                _CollectionFacilitySection(facility: facility),
              FinancialDetailMode.expenses =>
                _ExpenseFacilitySection(facility: facility),
              FinancialDetailMode.netIncome =>
                _NetFacilitySection(facility: facility),
            };
          }),
        ],
      ),
    );
  }
}

class _CollectionFacilitySection extends StatelessWidget {
  const _CollectionFacilitySection({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final approvedBills = store
        .facilityBills(facility.id)
        .where((bill) =>
            bill.status == PaymentStatus.approved &&
            store.isCurrentOrPastMonth(bill.month))
        .toList();
    final tenantIds = approvedBills.map((bill) => bill.tenantId).toSet();
    final otherIncome = store.additionalIncomes
        .where((income) =>
            income.facilityId == facility.id &&
            store.isCurrentOrPastMonth(income.month))
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
        title: Text(facility.name),
        subtitle: Text(facility.address),
        trailing: Text(
          money(store.facilityInflow(facility.id)),
          style: const TextStyle(
            color: Color(0xFF16856B),
            fontWeight: FontWeight.w800,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (approvedBills.isEmpty)
            const ListTile(
              title: Text('No approved rental collections yet.'),
            )
          else
            ...tenantIds.map((tenantId) {
              final tenant = store.userFor(tenantId);
              final tenancy = store.tenancies.firstWhere(
                (item) =>
                    item.tenantId == tenantId && item.facilityId == facility.id,
              );
              final tenantBills = approvedBills
                  .where((bill) => bill.tenantId == tenantId)
                  .toList();
              final tenantTotal = tenantBills.fold<double>(
                0,
                (sum, bill) => sum + bill.totalAmount,
              );
              return Card(
                color: const Color(0xFFF8FAFD),
                child: ExpansionTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text('${tenant.name} • ${tenancy.unitName}'),
                  subtitle: Text('${tenantBills.length} approved payment(s)'),
                  trailing: Text(
                    money(tenantTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: tenantBills.map((bill) {
                    return ListTile(
                      leading: const Icon(Icons.receipt_rounded),
                      title: Text(monthLabel(bill.month)),
                      subtitle: Text(
                        bill.submittedAt == null
                            ? 'Approved payment'
                            : 'Submitted ${dateTimeLabel(bill.submittedAt!)}',
                      ),
                      trailing: Text(
                        money(bill.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          if (otherIncome.isNotEmpty) ...[
            const Divider(),
            const ListTile(
              leading: Icon(Icons.add_circle_outline_rounded),
              title: Text(
                'Other Monthly Income',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ...otherIncome.map(
              (income) => ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('${income.category} • ${monthLabel(income.month)}'),
                subtitle: Text(income.note),
                trailing: Text(
                  money(income.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseFacilitySection extends StatelessWidget {
  const _ExpenseFacilitySection({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final elapsedMonths = store.elapsedMonthsThisYear;
    final items = <(String, double, IconData)>[
      (
        'Installment',
        facility.installmentAmount * elapsedMonths,
        Icons.account_balance_rounded
      ),
      (
        'Extra installment',
        facility.extraInstallmentPayment * elapsedMonths,
        Icons.add_card_rounded,
      ),
      (
        'Maintenance',
        facility.maintenanceFee * elapsedMonths,
        Icons.handyman_rounded
      ),
      (
        'Fire Insurance',
        facility.insuranceFee * elapsedMonths,
        Icons.local_fire_department_rounded
      ),
    ];

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
        title: Text(facility.name),
        subtitle: Text(
          '${facility.address} • January to ${FinancialChartPainter.monthNames[elapsedMonths - 1]}',
        ),
        trailing: Text(
          money(store.facilityOutflow(facility)),
          style: const TextStyle(
            color: Color(0xFFD16432),
            fontWeight: FontWeight.w800,
          ),
        ),
        children: items.map((item) {
          return ListTile(
            leading: Icon(item.$3),
            title: Text(item.$1),
            trailing: Text(
              money(item.$2),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NetFacilitySection extends StatelessWidget {
  const _NetFacilitySection({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final collection = store.facilityInflow(facility.id);
    final expenses = store.facilityOutflow(facility);
    final net = collection - expenses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              facility.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              facility.address,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 12),
            AmountRow(label: 'Rental collection', value: collection),
            AmountRow(label: 'Expenses', value: expenses),
            const Divider(),
            AmountRow(label: 'Net rental income', value: net, bold: true),
          ],
        ),
      ),
    );
  }
}

class FacilitiesTab extends StatefulWidget {
  const FacilitiesTab({super.key});

  @override
  State<FacilitiesTab> createState() => _FacilitiesTabState();
}

class _FacilitiesTabState extends State<FacilitiesTab> {
  String? selectedFacilityId;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facilities = store.ownerFacilities;
    if (facilities.isEmpty) {
      return EmptyState(
        icon: Icons.apartment_rounded,
        title: 'No facilities yet',
        message: 'Create your first facility to begin managing tenants.',
        action: FilledButton.icon(
          onPressed: () async {
            final facility = await showAddFacilityDialog(context);
            if (facility != null && mounted) {
              setState(() => selectedFacilityId = facility.id);
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Facility'),
        ),
      );
    }

    final selectedFacility = facilities.firstWhere(
      (facility) => facility.id == selectedFacilityId,
      orElse: () => facilities.first,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebar = _FacilitySidebar(
          facilities: facilities,
          selectedFacilityId: selectedFacility.id,
          onSelected: (facility) {
            setState(() => selectedFacilityId = facility.id);
          },
          onCreateFacility: () async {
            final facility = await showAddFacilityDialog(context);
            if (facility != null && mounted) {
              setState(() => selectedFacilityId = facility.id);
            }
          },
        );
        final detail = _FacilityWorkspace(facility: selectedFacility);

        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              _CompactFacilitySelector(
                facilities: facilities,
                selectedFacilityId: selectedFacility.id,
                onSelected: (facility) {
                  setState(() => selectedFacilityId = facility.id);
                },
                onCreateFacility: () async {
                  final facility = await showAddFacilityDialog(context);
                  if (facility != null && mounted) {
                    setState(() => selectedFacilityId = facility.id);
                  }
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: _FacilityWorkspace(
                  facility: selectedFacility,
                  compact: true,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 290, child: sidebar),
            const VerticalDivider(width: 1),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

class _CompactFacilitySelector extends StatelessWidget {
  const _CompactFacilitySelector({
    required this.facilities,
    required this.selectedFacilityId,
    required this.onSelected,
    required this.onCreateFacility,
  });

  final List<Facility> facilities;
  final String selectedFacilityId;
  final ValueChanged<Facility> onSelected;
  final Future<void> Function() onCreateFacility;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 98,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: facilities.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            if (index == facilities.length) {
              return _FacilityCircleButton(
                label: 'Add',
                icon: Icons.add_rounded,
                selected: false,
                onTap: () => onCreateFacility(),
              );
            }
            final facility = facilities[index];
            return _FacilityCircleButton(
              label: facility.name,
              icon: Icons.apartment_rounded,
              selected: facility.id == selectedFacilityId,
              onTap: () => onSelected(facility),
            );
          },
        ),
      ),
    );
  }
}

class _FacilityCircleButton extends StatelessWidget {
  const _FacilityCircleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF667085);
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFDDE7FF)
                    : const Color(0xFFF3F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFD6DEEB),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilitySidebar extends StatelessWidget {
  const _FacilitySidebar({
    required this.facilities,
    required this.selectedFacilityId,
    required this.onSelected,
    required this.onCreateFacility,
  });

  final List<Facility> facilities;
  final String selectedFacilityId;
  final ValueChanged<Facility> onSelected;
  final Future<void> Function() onCreateFacility;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => onCreateFacility(),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('New Facility'),
            ),
            const SizedBox(height: 14),
            Text(
              'MY FACILITIES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: facilities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final facility = facilities[index];
                  final selected = facility.id == selectedFacilityId;
                  return Material(
                    color:
                        selected ? const Color(0xFFE8EEFC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        Icons.apartment_rounded,
                        color: selected ? const Color(0xFF3156A3) : null,
                      ),
                      title: Text(
                        facility.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        facility.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelected(facility),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityWorkspace extends StatelessWidget {
  const _FacilityWorkspace({
    required this.facility,
    this.compact = false,
  });

  final Facility facility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final tenants = store.tenancies
        .where((tenancy) => tenancy.facilityId == facility.id)
        .toList();

    return ListView(
      padding: EdgeInsets.all(compact ? 12 : 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: (compact
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facility.address,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => showAddTenantDialog(context, facility),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(compact ? 'Tenant' : 'New Tenant'),
              style: compact
                  ? FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            if (compact)
              IconButton.filledTonal(
                tooltip: 'Facility Settings',
                onPressed: () => showFacilitySettingsDialog(context, facility),
                icon: const Icon(Icons.settings_rounded),
              )
            else
              OutlinedButton.icon(
                onPressed: () => showFacilitySettingsDialog(context, facility),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Settings'),
              ),
          ],
        ),
        SizedBox(height: compact ? 10 : 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Facility Costs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => showEditCostsDialog(context, facility),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                      style: compact
                          ? OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 6 : 10),
                CostSummary(facility: facility),
                SizedBox(height: compact ? 6 : 12),
                Wrap(
                  spacing: 8,
                  children: [
                    StatusChipText(label: facilityStatusText(facility)),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 18),
        Row(
          children: [
            Text(
              'Tenants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Chip(label: Text('${tenants.length}')),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        if (tenants.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 24),
              child: Column(
                children: [
                  Icon(
                    Icons.person_add_alt_rounded,
                    size: compact ? 30 : 42,
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  const Text('No tenants assigned to this facility.'),
                  SizedBox(height: compact ? 8 : 12),
                  FilledButton(
                    onPressed: () => showAddTenantDialog(context, facility),
                    child: const Text('Create Tenant'),
                  ),
                ],
              ),
            ),
          )
        else
          ...tenants.map((tenancy) {
            final tenant = store.userFor(tenancy.tenantId);
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () => showTenantProfileDialog(
                    context,
                    tenant: tenant,
                    tenancy: tenancy,
                  ),
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_rounded),
                  ),
                  title: Text('${tenant.name} • ${tenancy.unitName}'),
                  subtitle: Text(
                    'Rent ${money(tenancy.monthlyRent)} • ${tenant.accountCreated ? tenant.accountCreatedAt == null ? 'Account active' : 'Account created ${dateLabel(tenant.accountCreatedAt!)}' : tenant.invitationSent ? 'Awaiting tenant acceptance' : 'Invitation not sent'}',
                  ),
                  trailing: tenant.accountCreated
                      ? const StatusChipText(label: 'Account Created')
                      : FilledButton.icon(
                          onPressed: () =>
                              showSendInvitationDialog(context, tenant),
                          icon: Icon(
                            tenant.invitationSent
                                ? Icons.forward_to_inbox_rounded
                                : Icons.mark_email_unread_rounded,
                          ),
                          label: Text(
                            tenant.invitationSent
                                ? 'Resend Invite'
                                : 'Send Invite',
                          ),
                        ),
                ),
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
                Text('${facility.name} • ${bill.slipFileName}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text('Paid: ${money(bill.amountPaid)}'),
                    Text('Due: ${money(bill.totalAmount)}'),
                    Text(
                      'Submitted: ${bill.submittedAt == null ? 'Not recorded' : dateTimeLabel(bill.submittedAt!)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showPaymentReviewDialog(context, bill),
                  icon: const Icon(Icons.image_search_rounded),
                  label: const Text('View Attachment & Review'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdvancedReviewTab extends StatefulWidget {
  const AdvancedReviewTab({super.key});

  @override
  State<AdvancedReviewTab> createState() => _AdvancedReviewTabState();
}

class _AdvancedReviewTabState extends State<AdvancedReviewTab>
    with SingleTickerProviderStateMixin {
  late final TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final openRequests = store.tenantRequests
            .where((request) => request.status == 'Open')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final requestHistory = store.tenantRequests
            .where((request) => request.status != 'Open')
            .toList()
          ..sort((a, b) => (b.reviewedAt ?? b.createdAt)
              .compareTo(a.reviewedAt ?? a.createdAt));
        final paymentHistory = [...store.paymentReviewHistory]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TabBar(
                controller: controller,
                tabs: [
                  Tab(
                    text:
                        'Pending Action (${store.pendingBills.length + openRequests.length})',
                  ),
                  Tab(
                    text:
                        'History (${paymentHistory.length + requestHistory.length})',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: controller,
                children: [
                  _PendingReviewList(
                    bills: store.pendingBills,
                    requests: openRequests,
                  ),
                  _ReviewHistoryList(
                    paymentEvents: paymentHistory,
                    requests: requestHistory,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PendingReviewList extends StatelessWidget {
  const _PendingReviewList({required this.bills, required this.requests});

  final List<MonthlyBill> bills;
  final List<TenantRequest> requests;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    if (bills.isEmpty && requests.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_rounded,
        title: 'No pending actions',
        message: 'Payment slips and tenant requests will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...bills.map((bill) {
          final tenant = store.userFor(bill.tenantId);
          final facility = store.facilityFor(bill.facilityId);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReviewTypeBadge(
                    label: 'PAYMENT SLIP',
                    icon: Icons.receipt_long_rounded,
                    color: Color(0xFF3156A3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${tenant.name} • ${monthLabel(bill.month)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text('${facility.name} • ${bill.slipFileName}'),
                  const SizedBox(height: 8),
                  Text(
                    'Paid ${money(bill.amountPaid)} • Due ${money(bill.totalAmount)} • ${bill.submittedAt == null ? 'Time not recorded' : dateTimeLabel(bill.submittedAt!)}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => showPaymentReviewDialog(context, bill),
                    icon: const Icon(Icons.image_search_rounded),
                    label: const Text('Review Payment'),
                  ),
                ],
              ),
            ),
          );
        }),
        ...requests.map((request) {
          final tenant = store.userFor(request.tenantId);
          final facility = store.facilityFor(request.facilityId);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReviewTypeBadge(
                    label: 'TENANT REQUEST',
                    icon: Icons.handyman_rounded,
                    color: Color(0xFFD16432),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text('${tenant.name} • ${facility.name}'),
                  const SizedBox(height: 6),
                  Text(request.message),
                  const SizedBox(height: 6),
                  Text('Submitted ${dateTimeLabel(request.createdAt)}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            store.reviewTenantRequest(request, 'Approved'),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            store.reviewTenantRequest(request, 'Rejected'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                    ],
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

class _ReviewHistoryList extends StatelessWidget {
  const _ReviewHistoryList({
    required this.paymentEvents,
    required this.requests,
  });

  final List<PaymentReviewEvent> paymentEvents;
  final List<TenantRequest> requests;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final items = <({DateTime time, Widget widget})>[
      ...paymentEvents.map((event) {
        final bill = store.bills.firstWhere((bill) => bill.id == event.billId);
        final tenant = store.userFor(bill.tenantId);
        return (
          time: event.timestamp,
          widget: ListTile(
            leading: const Icon(Icons.receipt_long_rounded),
            title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
            subtitle: Text(
              'PAYMENT SLIP • ${dateTimeLabel(event.timestamp)}${event.reason == null ? '' : '\n${event.reason}'}',
            ),
            trailing: StatusChip(status: event.status),
          ),
        );
      }),
      ...requests.map((request) {
        final tenant = store.userFor(request.tenantId);
        final time = request.reviewedAt ?? request.createdAt;
        return (
          time: time,
          widget: ListTile(
            leading: const Icon(Icons.handyman_rounded),
            title: Text(request.title),
            subtitle: Text(
              'TENANT REQUEST • ${tenant.name}\n${dateTimeLabel(time)}',
            ),
            trailing: StatusChipText(label: request.status),
          ),
        );
      }),
    ]..sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No review history',
        message: 'Approved and rejected items will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map((item) => Card(child: item.widget)).toList(),
    );
  }
}

class ReviewTypeBadge extends StatelessWidget {
  const ReviewTypeBadge({
    required this.label,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class UtilitiesTab extends StatelessWidget {
  const UtilitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Owner Utility Entry',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Expand a facility and tenant to enter electricity usage in kWh. Electricity is calculated automatically at RM 0.516 per kWh.',
        ),
        const SizedBox(height: 12),
        ...store.ownerFacilities.map((facility) {
          final facilityTenancies = store.tenancies
              .where((tenancy) => tenancy.facilityId == facility.id)
              .toList();
          return Card(
            child: ExpansionTile(
              leading: const CircleAvatar(
                child: Icon(Icons.apartment_rounded),
              ),
              title: Text(facility.name),
              subtitle: Text(
                '${facility.address} • ${facilityTenancies.length} tenants',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: facilityTenancies.map((tenancy) {
                final tenant = store.userFor(tenancy.tenantId);
                final tenantBills = store.bills
                    .where((bill) =>
                        bill.tenantId == tenancy.tenantId &&
                        bill.facilityId == facility.id &&
                        (bill.status == PaymentStatus.notSubmitted ||
                            bill.status == PaymentStatus.rejected))
                    .toList()
                  ..sort((a, b) => a.month.compareTo(b.month));
                return Card(
                  color: const Color(0xFFF8FAFD),
                  child: ExpansionTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text('${tenant.name} • ${tenancy.unitName}'),
                    subtitle: Text(
                      '${tenantBills.length} bill${tenantBills.length == 1 ? '' : 's'} awaiting utility entry',
                    ),
                    children: tenantBills.isEmpty
                        ? const [
                            ListTile(
                              title: Text('No open bills for this tenant.'),
                            ),
                          ]
                        : tenantBills.map((bill) {
                            return ListTile(
                              leading: const Icon(Icons.electric_meter_rounded),
                              title: Text(monthLabel(bill.month)),
                              subtitle: Text(
                                '${bill.electricityUsageKwh.toStringAsFixed(1)} kWh = ${money(bill.electricityAmount)} • Total utilities ${money(bill.totalUtilityAmount)}',
                              ),
                              trailing: OutlinedButton.icon(
                                onPressed: () =>
                                    showUtilityDialog(context, bill),
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Enter'),
                              ),
                            );
                          }).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}

class OwnerAccountTab extends StatelessWidget {
  const OwnerAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final user = store.currentUser!;
    final roleLabel =
        user.role == UserRole.owner ? 'Property Owner' : 'Property Agent';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ProfileAvatar(user: user, radius: 38),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showAvatarPickerDialog(context),
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Choose Profile Picture'),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 16),
                ProfileInfoRow(label: 'Email', value: user.email),
                ProfileInfoRow(
                  label: 'Facilities',
                  value: '${store.ownerFacilities.length}',
                ),
                ProfileInfoRow(
                  label: 'Unread Notifications',
                  value: '${store.unreadNotificationCount}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                subtitle: const Text('Payment reminders and account settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showAccountSettingsDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: store.logout,
              ),
            ],
          ),
        ),
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
            icon: store.unreadNotificationCount == 0
                ? const Icon(Icons.notifications_outlined)
                : Badge(
                    label: Text('${store.unreadNotificationCount}'),
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
              if (bill.status == PaymentStatus.rejected)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'Payment was rejected. Please correct the issue and submit a new slip.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => showSubmitSlipDialog(context, bill),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    bill.status == PaymentStatus.rejected
                        ? 'Resubmit Payment Slip'
                        : 'Submit Payment Slip',
                  ),
                ),
              ),
            ],
            if (bill.slipFileName != null) ...[
              const SizedBox(height: 8),
              Text('Uploaded slip: ${bill.slipFileName}'),
            ],
            if (bill.utilityEvidenceFileName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.photo_camera_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Meter evidence: ${bill.utilityEvidenceFileName}',
                    ),
                  ),
                ],
              ),
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

class YearlyFinancialChart extends StatefulWidget {
  const YearlyFinancialChart({
    required this.year,
    required this.summaries,
    super.key,
  });

  final int year;
  final List<MonthlyFinancialSummary> summaries;

  @override
  State<YearlyFinancialChart> createState() => _YearlyFinancialChartState();
}

class _YearlyFinancialChartState extends State<YearlyFinancialChart> {
  int? hoveredMonthIndex;
  int? selectedMonthIndex;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final selectedSummary = selectedMonthIndex == null
        ? null
        : widget.summaries[selectedMonthIndex!];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.year} Collection & Expenses',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Monthly amounts; select a month to see its breakdown',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF667085),
                      ),
                ),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 18,
                  children: [
                    ChartLegend(
                      color: Color(0xFF16856B),
                      label: 'Rental collection',
                    ),
                    ChartLegend(
                      color: Color(0xFFD16432),
                      label: 'Expenses',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 155,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final hovered = hoveredMonthIndex == null
                          ? null
                          : widget.summaries[hoveredMonthIndex!];
                      final tooltipWidth = width < 180 ? width : 180.0;
                      final groupWidth = (width - 16) / widget.summaries.length;
                      final tooltipLeft = hoveredMonthIndex == null
                          ? 0.0
                          : (8 +
                                  groupWidth * hoveredMonthIndex! +
                                  groupWidth / 2 -
                                  tooltipWidth / 2)
                              .clamp(0.0, width - tooltipWidth);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onHover: (event) {
                          final index = financialChartMonthIndex(
                            event.localPosition.dx,
                            width,
                            widget.summaries.length,
                          );
                          if (index != hoveredMonthIndex) {
                            setState(() => hoveredMonthIndex = index);
                          }
                        },
                        onExit: (_) {
                          if (hoveredMonthIndex != null) {
                            setState(() => hoveredMonthIndex = null);
                          }
                        },
                        child: GestureDetector(
                          key: const Key('financial_chart_touch_area'),
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final index = financialChartMonthIndex(
                              details.localPosition.dx,
                              width,
                              widget.summaries.length,
                            );
                            setState(() => selectedMonthIndex = index);
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: FinancialChartPainter(
                                    widget.summaries,
                                    highlightedIndex:
                                        hoveredMonthIndex ?? selectedMonthIndex,
                                  ),
                                ),
                              ),
                              if (hovered != null)
                                Positioned(
                                  left: tooltipLeft,
                                  top: 2,
                                  width: tooltipWidth,
                                  child: IgnorePointer(
                                    child: _FinancialChartTooltip(
                                      year: widget.year,
                                      summary: hovered,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedSummary == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Select a month above to view its collection and expense charts.',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
                  )
                else ...[
                  Text(
                    '${monthLabel(DateTime(widget.year, selectedSummary.month))} Breakdown',
                    key: const Key('inline_month_breakdown_title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'See who contributed to collection and where expenses went.',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth < 680
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2;
                      final month = selectedSummary.month;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: FinancialBreakdownPieCard(
                              key: ValueKey('collection_${widget.year}_$month'),
                              title: 'Total Rental Collection',
                              icon: Icons.payments_rounded,
                              accentColor: const Color(0xFF16856B),
                              items: store.monthlyCollectionBreakdown(
                                widget.year,
                                month,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: FinancialBreakdownPieCard(
                              key: ValueKey('expenses_${widget.year}_$month'),
                              title: 'Total Expenses',
                              icon: Icons.receipt_long_rounded,
                              accentColor: const Color(0xFFD16432),
                              items: store.monthlyExpenseBreakdown(
                                widget.year,
                                month,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinancialChartTooltip extends StatelessWidget {
  const _FinancialChartTooltip({
    required this.year,
    required this.summary,
  });

  final int year;
  final MonthlyFinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFF17233C),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${FinancialChartPainter.monthNames[summary.month - 1]} $year',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Collection  ${money(summary.collection)}',
              style: const TextStyle(
                color: Color(0xFF7CE0C2),
                fontSize: 12,
              ),
            ),
            Text(
              'Expenses   ${money(summary.expenses)}',
              style: const TextStyle(
                color: Color(0xFFFFB18D),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinancialBreakdownPieCard extends StatelessWidget {
  const FinancialBreakdownPieCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<FinancialBreakdownItem> items;

  static const colors = [
    Color(0xFF16856B),
    Color(0xFF3156A3),
    Color(0xFFD16432),
    Color(0xFF8A4FA3),
    Color(0xFFDAA520),
    Color(0xFF2D8BA8),
    Color(0xFFB04A6F),
    Color(0xFF6A7B3F),
  ];

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              money(total),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutBack,
                  builder: (context, progress, child) {
                    final visibleProgress = progress.clamp(0.0, 1.0);
                    return CustomPaint(
                      painter: FinancialPieChartPainter(
                        items: items,
                        colors: colors,
                        progress: visibleProgress,
                      ),
                      child: Opacity(
                        opacity: visibleProgress,
                        child: Transform.scale(
                          scale: 0.8 + visibleProgress * 0.2,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Center(
                    child: Text(
                      items.isEmpty ? 'No data' : money(total),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const Text(
                'No collection or expense recorded for this month.',
                style: TextStyle(color: Color(0xFF667085)),
              )
            else
              ...List.generate(items.length, (index) {
                final item = items[index];
                final percentage = total == 0 ? 0 : item.amount / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(item.amount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class FinancialPieChartPainter extends CustomPainter {
  FinancialPieChartPainter({
    required this.items,
    required this.colors,
    required this.progress,
  });

  final List<FinancialBreakdownItem> items;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) {
      canvas.drawCircle(
          center, radius, Paint()..color = const Color(0xFFE8EDF5));
    } else {
      var startAngle = -math.pi / 2;
      for (var index = 0; index < items.length; index++) {
        final sweepAngle = items[index].amount / total * math.pi * 2 * progress;
        canvas.drawArc(
          rect,
          startAngle,
          sweepAngle,
          true,
          Paint()..color = colors[index % colors.length],
        );
        startAngle += sweepAngle;
      }
    }
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()..color = ThemeData.light().cardColor,
    );
  }

  @override
  bool shouldRepaint(FinancialPieChartPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.colors != colors ||
      oldDelegate.progress != progress;
}

int financialChartMonthIndex(double dx, double width, int monthCount) {
  if (monthCount <= 0 || width <= 16) return 0;
  final chartWidth = width - 16;
  final normalized = ((dx - 8) / chartWidth).clamp(0.0, 0.999999);
  return (normalized * monthCount).floor();
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({
    required this.color,
    required this.label,
    super.key,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class FinancialChartPainter extends CustomPainter {
  FinancialChartPainter(this.summaries, {this.highlightedIndex});

  final List<MonthlyFinancialSummary> summaries;
  final int? highlightedIndex;

  static const monthNames = [
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

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 8.0;
    const bottomPadding = 28.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - leftPadding - rightPadding;
    final maxValue = summaries.fold<double>(1, (current, summary) {
      final monthMax = summary.collection > summary.expenses
          ? summary.collection
          : summary.expenses;
      return monthMax > current ? monthMax : current;
    });

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDF5)
      ..strokeWidth = 1;
    for (var line = 0; line <= 4; line++) {
      final y = topPadding + chartHeight * line / 4;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final groupWidth = chartWidth / summaries.length;
    final barWidth = groupWidth * 0.25;
    final collectionPaint = Paint()..color = const Color(0xFF16856B);
    final expensePaint = Paint()..color = const Color(0xFFD16432);

    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index];
      final centerX = leftPadding + groupWidth * index + groupWidth / 2;
      final collectionHeight =
          chartHeight * (summary.collection / maxValue).clamp(0, 1);
      final expenseHeight =
          chartHeight * (summary.expenses / maxValue).clamp(0, 1);
      final bottom = topPadding + chartHeight;

      final isHighlighted = index == highlightedIndex;
      final collectionBarPaint = Paint()
        ..color =
            isHighlighted ? const Color(0xFF0F6D56) : collectionPaint.color;
      final expenseBarPaint = Paint()
        ..color = isHighlighted ? const Color(0xFFB64B20) : expensePaint.color;

      if (isHighlighted) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX - groupWidth / 2 + 2,
              topPadding,
              groupWidth - 4,
              chartHeight,
            ),
            const Radius.circular(6),
          ),
          Paint()..color = const Color(0x123156A3),
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - barWidth - 1,
            bottom - collectionHeight,
            barWidth,
            collectionHeight,
          ),
          const Radius.circular(4),
        ),
        collectionBarPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX + 1,
            bottom - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(4),
        ),
        expenseBarPaint,
      );

      final label = TextPainter(
        text: TextSpan(
          text: monthNames[index],
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(centerX - label.width / 2, size.height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(FinancialChartPainter oldDelegate) =>
      oldDelegate.summaries != summaries ||
      oldDelegate.highlightedIndex != highlightedIndex;
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.positive,
    this.color,
    this.fullWidth = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool? positive;
  final Color? color;
  final bool fullWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = color ??
        (positive == null
            ? Theme.of(context).colorScheme.primary
            : positive!
                ? const Color(0xFF16856B)
                : const Color(0xFFC43D4B));
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 145;
        return SizedBox(
          width: fullWidth ? double.infinity : 250,
          height: compact ? 118 : 168,
          child: Card(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: EdgeInsets.all(compact ? 8 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 30 : 42,
                          height: compact ? 30 : 42,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(compact ? 9 : 12),
                          ),
                          child: Icon(
                            icon,
                            color: accentColor,
                            size: compact ? 17 : 22,
                          ),
                        ),
                        if (onTap != null) ...[
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: accentColor,
                            size: compact ? 16 : 20,
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? Theme.of(context).textTheme.labelSmall
                              : Theme.of(context).textTheme.bodyMedium)
                          ?.copyWith(
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: (compact
                                ? Theme.of(context).textTheme.titleMedium
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17233C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CostSummary extends StatelessWidget {
  const CostSummary({required this.facility, super.key});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final total = facility.installmentAmount +
        facility.extraInstallmentPayment +
        facility.maintenanceFee +
        facility.insuranceFee;
    final items = [
      (
        'Installment',
        facility.installmentAmount,
        Icons.account_balance_rounded,
        const Color(0xFF3156A3)
      ),
      (
        'Extra Payment',
        facility.extraInstallmentPayment,
        Icons.add_card_rounded,
        const Color(0xFF6B5CB8)
      ),
      (
        'Maintenance',
        facility.maintenanceFee,
        Icons.handyman_rounded,
        const Color(0xFFD16432)
      ),
      (
        'Fire Insurance',
        facility.insuranceFee,
        Icons.local_fire_department_rounded,
        const Color(0xFFC43D4B)
      ),
    ];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF17233C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Monthly Facility Commitment',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                money(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 72,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.$4.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: item.$4.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(item.$3, color: item.$4, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF667085),
                          ),
                        ),
                        Text(
                          money(item.$2),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

Future<Facility?> showAddFacilityDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final name = TextEditingController(text: 'New Facility');
  final addressLine = TextEditingController(text: '');
  final postcode = TextEditingController(text: '');
  final city = TextEditingController(text: '');
  final state = TextEditingController(text: '');
  final installment = TextEditingController(text: '3700');
  final maintenance = TextEditingController(text: '450');
  final insurance = TextEditingController(text: '230');
  String? validationMessage;

  return showDialog<Facility>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Create New Facility'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(controller: name, label: 'Facility Name'),
                  AppTextField(
                    controller: addressLine,
                    label: 'Address',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: postcode,
                          label: 'Postcode',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: city,
                          label: 'City',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: state,
                          label: 'State',
                        ),
                      ),
                    ],
                  ),
                  AppTextField(
                    controller: installment,
                    label: 'Monthly Installment',
                    prefixText: 'RM ',
                  ),
                  AppTextField(
                    controller: maintenance,
                    label: 'Maintenance',
                    prefixText: 'RM ',
                  ),
                  AppTextField(
                    controller: insurance,
                    label: 'Fire Insurance',
                    prefixText: 'RM ',
                  ),
                  if (validationMessage != null)
                    Text(
                      validationMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (name.text.trim().isEmpty ||
                    addressLine.text.trim().isEmpty ||
                    postcode.text.trim().isEmpty ||
                    city.text.trim().isEmpty ||
                    state.text.trim().isEmpty) {
                  setDialogState(() {
                    validationMessage =
                        'Facility name and complete address are required.';
                  });
                  return;
                }
                final facility = store.addFacility(
                  name: name.text.trim(),
                  addressLine: addressLine.text.trim(),
                  postcode: postcode.text.trim(),
                  city: city.text.trim(),
                  state: state.text.trim(),
                  installmentAmount: parseMoney(installment.text),
                  maintenanceFee: parseMoney(maintenance.text),
                  insuranceFee: parseMoney(insurance.text),
                );
                Navigator.pop(dialogContext, facility);
              },
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Create Facility'),
            ),
          ],
        );
      },
    ),
  );
}

void showAddTenantDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  final fullName = TextEditingController(text: 'New Tenant');
  final email = TextEditingController(text: 'tenant@example.com');
  final originAddress = TextEditingController(text: 'Origin address');
  final dateOfBirth = TextEditingController(text: '01/01/1995');
  final sex = TextEditingController(text: 'Male');
  final unitName = TextEditingController(text: 'Room / Unit');
  final monthlyRent = TextEditingController(text: '800');
  final leaseStart = TextEditingController(text: '01/01/2026');
  final leaseEnd = TextEditingController(text: '31/12/2026');
  final carParkDetails = TextEditingController(text: '1 car park bay');
  var electricityIncluded = false;
  var waterIncluded = false;
  var internetIncluded = true;
  var carParkIncluded = false;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text('New Tenant • ${facility.name}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tenant Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter known details now. The tenant can complete or confirm the profile after accepting the email invitation.',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(controller: fullName, label: 'Full Name'),
                  AppTextField(controller: email, label: 'Email'),
                  AppTextField(
                    controller: originAddress,
                    label: 'Origin Address',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: dateOfBirth,
                          label: 'Date of Birth',
                          helperText: 'DD/MM/YYYY',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(controller: sex, label: 'Sex'),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Text(
                    'Contract & Package',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: unitName,
                          label: 'Room / Unit',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: monthlyRent,
                          label: 'Monthly Rent',
                          prefixText: 'RM ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: leaseStart,
                          label: 'Lease Start',
                          helperText: 'DD/MM/YYYY',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: leaseEnd,
                          label: 'Lease End',
                          helperText: 'DD/MM/YYYY',
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Electricity included'),
                    value: electricityIncluded,
                    onChanged: (value) =>
                        setDialogState(() => electricityIncluded = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Water included'),
                    value: waterIncluded,
                    onChanged: (value) =>
                        setDialogState(() => waterIncluded = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Internet included'),
                    value: internetIncluded,
                    onChanged: (value) =>
                        setDialogState(() => internetIncluded = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Car park included'),
                    value: carParkIncluded,
                    onChanged: (value) =>
                        setDialogState(() => carParkIncluded = value),
                  ),
                  if (carParkIncluded)
                    AppTextField(
                      controller: carParkDetails,
                      label: 'Car Park Details',
                      helperText: 'Example: Covered bay A-18',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                store.addTenantToFacility(
                  facility: facility,
                  fullName: fullName.text.trim(),
                  email: email.text.trim(),
                  originAddress: originAddress.text.trim(),
                  dateOfBirth:
                      parseDateInput(dateOfBirth.text) ?? DateTime(1995),
                  sex: sex.text.trim(),
                  unitName: unitName.text.trim(),
                  monthlyRent: parseMoney(monthlyRent.text),
                  leaseStart: parseDateInput(leaseStart.text) ?? DateTime(2026),
                  leaseEnd:
                      parseDateInput(leaseEnd.text) ?? DateTime(2026, 12, 31),
                  electricityPackage: electricityIncluded
                      ? UtilityPackage.included
                      : UtilityPackage.excluded,
                  waterPackage: waterIncluded
                      ? UtilityPackage.included
                      : UtilityPackage.excluded,
                  internetPackage: internetIncluded
                      ? UtilityPackage.included
                      : UtilityPackage.excluded,
                  carParkIncluded: carParkIncluded,
                  carParkDetails: carParkDetails.text.trim(),
                );
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create Tenant'),
            ),
          ],
        );
      },
    ),
  );
}

void showSendInvitationDialog(BuildContext context, AppUser tenant) {
  final store = RentalStoreScope.of(context);

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Send Tenant Invitation'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 48,
              color: Color(0xFF3156A3),
            ),
            const SizedBox(height: 14),
            Text(
              tenant.email,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'The invitation asks ${tenant.name} to log in, create a password, and complete their personal profile.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Prototype mode: this records the invitation in the app. Connect Firebase Authentication and an email service to deliver real invitation emails.',
              ),
            ),
            if (tenant.invitationSentAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last invitation: ${dateTimeLabel(tenant.invitationSentAt!)}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
            if (tenant.accountCreatedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Account created: ${dateTimeLabel(tenant.accountCreatedAt!)}',
                style: const TextStyle(
                  color: Color(0xFF16856B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        if (tenant.invitationSent && !tenant.accountCreated)
          OutlinedButton.icon(
            onPressed: () {
              store.acceptTenantInvitation(tenant);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${tenant.name} accepted the invitation and created an account.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.how_to_reg_rounded),
            label: const Text('Simulate Tenant Acceptance'),
          ),
        FilledButton.icon(
          onPressed: tenant.accountCreated
              ? null
              : () {
                  store.sendTenantInvitation(tenant);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invitation prepared for ${tenant.email}.',
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.send_rounded),
          label: Text(
            tenant.accountCreated
                ? 'Account Created'
                : tenant.invitationSent
                    ? 'Resend Invitation'
                    : 'Send Invitation',
          ),
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
            AppTextField(controller: insurance, label: 'Fire Insurance'),
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
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showFacilitySettingsDialog(BuildContext context, Facility facility) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text('${facility.name} Settings')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileInfoRow(label: 'Facility', value: facility.name),
            ProfileInfoRow(label: 'Address', value: facility.address),
            ProfileInfoRow(
              label: 'Status',
              value: facilityStatusText(facility),
            ),
            const Divider(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Facility Costs'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(dialogContext);
                showEditCostsDialog(context, facility);
              },
            ),
            if (facility.status == FacilityStatus.active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.sell_rounded,
                  color: Color(0xFFD16432),
                ),
                title: const Text('Mark Facility as Sold'),
                subtitle: const Text(
                  'Stops active tenancy tracking but keeps the records.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(dialogContext);
                  showMarkSoldDialog(context, facility);
                },
              ),
            if (facility.status == FacilityStatus.sold)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFC43D4B),
                ),
                title: const Text('Remove Sold Facility'),
                subtitle: const Text(
                  'Available only after the facility is marked sold.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(dialogContext);
                  showRemoveFacilityDialog(context, facility);
                },
              ),
          ],
        ),
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

void showPaymentReviewDialog(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final tenant = store.userFor(bill.tenantId);
  final facility = store.facilityFor(bill.facilityId);
  final rejectReason = TextEditingController(
    text: 'Slip amount or payment reference needs checking.',
  );

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Payment Attachment Review'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6DEEB)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 72,
                      color: Color(0xFF3156A3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      bill.slipFileName ?? 'No attachment supplied',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Prototype attachment preview',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ProfileInfoRow(label: 'Tenant', value: tenant.name),
              ProfileInfoRow(label: 'Facility', value: facility.name),
              ProfileInfoRow(
                  label: 'Bill month', value: monthLabel(bill.month)),
              ProfileInfoRow(
                label: 'Submitted',
                value: bill.submittedAt == null
                    ? 'Not recorded'
                    : dateTimeLabel(bill.submittedAt!),
              ),
              ProfileInfoRow(
                label: 'Amount paid',
                value: money(bill.amountPaid),
              ),
              ProfileInfoRow(
                label: 'Amount due',
                value: money(bill.totalAmount),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: rejectReason,
                label: 'Reason if rejected',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            store.rejectBill(bill, rejectReason.text.trim());
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment rejected and returned to the tenant for resubmission.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject'),
        ),
        FilledButton.icon(
          onPressed: () {
            store.approveBill(bill);
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment approved and moved to Review History.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve'),
        ),
      ],
    ),
  );
}

void showUtilityDialog(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final electricityUsage = TextEditingController(
    text: bill.electricityUsageKwh.toStringAsFixed(1),
  );
  final water =
      TextEditingController(text: bill.waterAmount.toStringAsFixed(0));
  final internet =
      TextEditingController(text: bill.internetAmount.toStringAsFixed(0));
  final evidence = TextEditingController(
    text: bill.utilityEvidenceFileName ??
        'meter_${monthLabel(bill.month).replaceAll(' ', '_')}.jpg',
  );
  double electricityAmount =
      bill.electricityUsageKwh * RentalStore.electricityRatePerKwh;
  double totalUtilities =
      electricityAmount + bill.waterAmount + bill.internetAmount;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        void recalculate() {
          final usage = parseMoney(electricityUsage.text);
          electricityAmount = usage * RentalStore.electricityRatePerKwh;
          totalUtilities = electricityAmount +
              parseMoney(water.text) +
              parseMoney(internet.text);
          setDialogState(() {});
        }

        return AlertDialog(
          title: Text('Utilities for ${monthLabel(bill.month)}'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: electricityUsage,
                    label: 'Electricity Usage',
                    suffixText: 'kWh',
                    helperText:
                        'Automatic rate: RM ${RentalStore.electricityRatePerKwh.toStringAsFixed(3)} per kWh',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => recalculate(),
                  ),
                  AppTextField(
                    controller: water,
                    label: 'Water Charge',
                    prefixText: 'RM ',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => recalculate(),
                  ),
                  AppTextField(
                    controller: internet,
                    label: 'Internet Charge',
                    prefixText: 'RM ',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => recalculate(),
                  ),
                  AppTextField(
                    controller: evidence,
                    label: 'Meter Reading Picture',
                    helperText:
                        'Prototype file reference for tenant bill evidence',
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Charge Summary',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        AmountRow(
                          label: 'Electricity',
                          value: electricityAmount,
                        ),
                        AmountRow(
                          label: 'Water',
                          value: parseMoney(water.text),
                        ),
                        AmountRow(
                          label: 'Internet',
                          value: parseMoney(internet.text),
                        ),
                        const Divider(),
                        AmountRow(
                          label: 'Total Utilities',
                          value: totalUtilities,
                          bold: true,
                        ),
                        AmountRow(
                          label: 'Bill Total with Rent',
                          value: bill.rentAmount + totalUtilities,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                store.updateBillUtilities(
                  bill,
                  electricityUsageKwh: parseMoney(electricityUsage.text),
                  waterAmount: parseMoney(water.text),
                  internetAmount: parseMoney(internet.text),
                  utilityEvidenceFileName: evidence.text,
                );
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Charges'),
            ),
          ],
        );
      },
    ),
  );
}

void showTenantProfileDialog(
  BuildContext context, {
  required AppUser tenant,
  required Tenancy tenancy,
}) {
  final store = RentalStoreScope.of(context);
  final facility = store.facilityFor(tenancy.facilityId);
  final paymentHistory = store
      .billsForTenant(tenant.id)
      .where((bill) => bill.status != PaymentStatus.notSubmitted)
      .toList();

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(tenant.name)),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tenant Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ProfileInfoRow(label: 'Full name', value: tenant.name),
              ProfileInfoRow(label: 'Email', value: tenant.email),
              ProfileInfoRow(
                label: 'Origin address',
                value: tenant.originAddress ?? 'Not provided',
              ),
              ProfileInfoRow(
                label: 'Date of birth',
                value: tenant.dateOfBirth == null
                    ? 'Not provided'
                    : dateLabel(tenant.dateOfBirth!),
              ),
              ProfileInfoRow(label: 'Sex', value: tenant.sex ?? 'Not provided'),
              ProfileInfoRow(
                label: 'Status',
                value: tenant.accountStatus,
              ),
              ProfileInfoRow(
                label: 'Profile setup',
                value: tenant.accountCreated
                    ? tenant.accountCreatedAt == null
                        ? 'Account active'
                        : 'Account created ${dateTimeLabel(tenant.accountCreatedAt!)}'
                    : tenant.invitationSent
                        ? 'Invitation sent; awaiting acceptance'
                        : 'Invitation not sent',
              ),
              if (!tenant.accountCreated)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showSendInvitationDialog(context, tenant),
                    icon: const Icon(Icons.mark_email_unread_rounded),
                    label: Text(
                      tenant.invitationSent
                          ? 'Resend Profile Invitation'
                          : 'Send Profile Invitation',
                    ),
                  ),
                ),
              const Divider(height: 28),
              Text(
                'Contract & Package',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ProfileInfoRow(label: 'Facility', value: facility.name),
              ProfileInfoRow(label: 'Unit', value: tenancy.unitName),
              ProfileInfoRow(
                label: 'Monthly rent',
                value: money(tenancy.monthlyRent),
              ),
              ProfileInfoRow(
                label: 'Lease period',
                value:
                    '${dateLabel(tenancy.leaseStart)} – ${dateLabel(tenancy.leaseEnd)}',
              ),
              ProfileInfoRow(
                label: 'Electricity',
                value: packageText(tenancy.electricityPackage),
              ),
              ProfileInfoRow(
                label: 'Water',
                value: packageText(tenancy.waterPackage),
              ),
              ProfileInfoRow(
                label: 'Internet',
                value: packageText(tenancy.internetPackage),
              ),
              ProfileInfoRow(
                label: 'Car park',
                value: tenancy.carParkIncluded
                    ? tenancy.carParkDetails
                    : 'Not included in agreement',
              ),
              const Divider(height: 28),
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (paymentHistory.isEmpty)
                const Text('No payment records yet.')
              else
                ...paymentHistory.map(
                  (bill) => Card(
                    color: const Color(0xFFF8FAFD),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_rounded),
                      title: Text(
                        '${monthLabel(bill.month)} • ${money(bill.totalAmount)}',
                      ),
                      subtitle: Text(
                        bill.submittedAt == null
                            ? 'No submission date'
                            : 'Submitted ${dateTimeLabel(bill.submittedAt!)}',
                      ),
                      trailing: StatusChip(status: bill.status),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
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

void showAvatarPickerDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final user = store.currentUser!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Choose Profile Picture'),
      content: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: List.generate(6, (index) {
          return InkWell(
            onTap: () {
              store.updateAvatar(index);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(40),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: user.avatarStyle == index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: ProfileAvatar(
                user: user,
                radius: 30,
                overrideStyle: index,
              ),
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

void showReminderSettingsDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final user = store.currentUser!;
  var afterDays = user.paymentReminderAfterDays;
  var frequencyDays = user.paymentReminderFrequencyDays;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Payment Reminder Schedule'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('First reminder: $afterDays days after due date'),
              Slider(
                value: afterDays.toDouble(),
                min: 1,
                max: 14,
                divisions: 13,
                label: '$afterDays days',
                onChanged: (value) {
                  setDialogState(() => afterDays = value.round());
                },
              ),
              const SizedBox(height: 8),
              Text('Repeat reminder: every $frequencyDays days'),
              Slider(
                value: frequencyDays.toDouble(),
                min: 1,
                max: 14,
                divisions: 13,
                label: '$frequencyDays days',
                onChanged: (value) {
                  setDialogState(() => frequencyDays = value.round());
                },
              ),
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
              store.updateReminderSettings(
                afterDays: afterDays,
                frequencyDays: frequencyDays,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void showAccountSettingsDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final user = store.currentUser!;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_rounded),
          SizedBox(width: 10),
          Text('Settings'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tenant Payment Reminder',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Push reminders are sent when a tenant has not submitted payment.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ReminderSettingTile(
                    label: 'First reminder after',
                    value: '${user.paymentReminderAfterDays} days',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReminderSettingTile(
                    label: 'Repeat frequency',
                    value: 'Every ${user.paymentReminderFrequencyDays} days',
                    icon: Icons.repeat_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                showReminderSettingsDialog(context);
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Edit Reminder Schedule'),
            ),
          ],
        ),
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

void showAddIncomeDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final facilities = store.ownerFacilities;
  if (facilities.isEmpty) return;
  Facility selectedFacility = facilities.first;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final category = TextEditingController(text: 'Other income');
  final amount = TextEditingController(text: '0');
  final note = TextEditingController(text: 'One-off monthly collection');

  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Other Monthly Income'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Facility>(
                  value: selectedFacility,
                  decoration: const InputDecoration(labelText: 'Facility'),
                  items: facilities
                      .map(
                        (facility) => DropdownMenuItem(
                          value: facility,
                          child: Text(facility.name),
                        ),
                      )
                      .toList(),
                  onChanged: (facility) {
                    if (facility != null) {
                      setDialogState(() => selectedFacility = facility);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: selectedMonth.month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                          monthLabel(DateTime(selectedMonth.year, index + 1))),
                    ),
                  ),
                  onChanged: (month) {
                    if (month != null) {
                      setDialogState(() {
                        selectedMonth = DateTime(selectedMonth.year, month);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                AppTextField(controller: category, label: 'Income Category'),
                AppTextField(
                  controller: amount,
                  label: 'Amount',
                  prefixText: 'RM ',
                ),
                AppTextField(controller: note, label: 'Note'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              store.addAdditionalIncome(
                facility: selectedFacility,
                month: selectedMonth,
                category: category.text.trim(),
                amount: parseMoney(amount.text),
                note: note.text.trim(),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Income'),
          ),
        ],
      ),
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
            (notification) => ListTile(
              leading: Icon(
                notification.isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: notification.isRead
                    ? const Color(0xFF98A2B3)
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                notification.message,
                style: TextStyle(
                  fontWeight:
                      notification.isRead ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
              subtitle: Text(dateTimeLabel(notification.createdAt)),
              onTap: () {
                store.markNotificationRead(notification);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      );
    },
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.user,
    required this.radius,
    this.overrideStyle,
    super.key,
  });

  final AppUser user;
  final double radius;
  final int? overrideStyle;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF3156A3),
      Color(0xFF16856B),
      Color(0xFFD16432),
      Color(0xFF6B5CB8),
      Color(0xFFC43D4B),
      Color(0xFF247BA0),
    ];
    const icons = [
      Icons.person_rounded,
      Icons.face_rounded,
      Icons.account_circle_rounded,
      Icons.sentiment_satisfied_alt_rounded,
      Icons.person_pin_rounded,
      Icons.manage_accounts_rounded,
    ];
    final style = overrideStyle ?? user.avatarStyle;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors[style % colors.length].withOpacity(0.15),
      foregroundColor: colors[style % colors.length],
      child: Icon(icons[style % icons.length], size: radius),
    );
  }
}

class _ReminderSettingTile extends StatelessWidget {
  const _ReminderSettingTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.helperText,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          helperText: helperText,
          prefixText: prefixText,
          suffixText: suffixText,
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
  return '${sign}RM ${buffer.toString()}';
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

String firstName(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return 'there';
  return trimmed.split(RegExp(r'\s+')).first;
}

String timeGreeting(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 18) return 'Good afternoon';
  return 'Good evening';
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

String dateTimeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${dateLabel(date)} $hour:$minute';
}

double parseMoney(String text) {
  return double.tryParse(
          text.replaceAll(',', '').replaceAll('\$', '').trim()) ??
      0;
}

DateTime? parseDateInput(String text) {
  final parts = text.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}
