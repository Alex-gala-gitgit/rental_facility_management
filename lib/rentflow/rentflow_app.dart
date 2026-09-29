import 'dart:math' as math;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/homeops_brand.dart';
import '../cloud/invoice_portal_service.dart';
import '../cloud/supabase_config.dart';
import '../file_upload/payment_proof_picker.dart';
import '../environment_banner.dart';
import '../pdf_open/inline_pdf_preview.dart';

const _blue = Color(0xFF2563EB);
const _sky = Color(0xFF38BDF8);
const _portalSky = Color(0xFF4EA8EC);
const _portalBlue = Color(0xFF2E86E0);
const _portalDeep = Color(0xFF1C67CF);

const _tenantPortalChinese = <String, String>{
  'Amount due': '应付金额',
  'Due': '到期日',
  'Unit': '单位',
  'Monthly rent': '每月租金',
  'Water': '水费',
  'Internet': '网络费',
  'General electricity': '普通电费',
  'Air-con electricity': '空调电费',
  'Electricity': '电费',
  'Parking rental': '停车位租金',
  'Download invoice PDF': '下载发票 PDF',
  'Settle your invoice': '支付您的账单',
  'Two quick steps — transfer, then attach your slip.': '只需两步：转账，然后上传付款凭证。',
  'STEP 1 — TRANSFER TO OWNER': '步骤 1 — 转账给业主',
  'STEP 2 — ATTACH PAY SLIP': '步骤 2 — 上传付款凭证',
  'Tap to attach your receipt': '点击上传付款凭证',
  'JPG, PNG or PDF · maximum 2 MB': 'JPG、PNG 或 PDF · 最大 2 MB',
  'Amount paid': '付款金额',
  'Date paid': '付款日期',
  'Payment reference (optional)': '付款参考编号（可选）',
  'Sending…': '发送中…',
  'Send payment proof': '发送付款凭证',
  'Payment QR': '付款二维码',
  'Tap QR to enlarge': '点击二维码放大',
  'Not configured': '尚未设置',
  'Bank': '银行',
  'Account no.': '银行账号',
  'Beneficiary': '收款人',
  'Bank account copied.': '银行账号已复制。',
  'Attach your payment proof before submitting.': '请先上传付款凭证。',
  'Enter a valid amount paid.': '请输入有效的付款金额。',
  'Enter the payment date as DD/MM/YYYY.': '请以 DD/MM/YYYY 格式输入付款日期。',
  'Upload failed': '上传失败',
  'Your payment has been confirmed.': '您的付款已确认。',
  'Payment confirmed': '付款已确认',
  'Awaiting owner confirmation': '等待业主确认',
  'Download receipt': '下载收据',
  'The invoice PDF is unavailable.': '发票 PDF 暂时无法使用。',
  'The invoice PDF could not be opened.': '无法打开此发票 PDF。',
  'Payment proof PDF must be smaller than 2 MB.': '付款凭证 PDF 必须小于 2 MB。',
  'This picture is still above 2 MB after compression. Choose a smaller photo.':
      '压缩后图片仍超过 2 MB，请选择较小的图片。',
  'The payment proof could not be read.': '无法读取付款凭证。',
  'Secure payment guide': '安全付款指南',
  'This private page brings your invoice, owner payment details and receipt upload together in one place.':
      '此私人页面将您的账单、业主付款资料和凭证上传集中在一个地方。',
  'Check': '核对',
  'Confirm the invoice amount and owner bank details.': '确认账单金额和业主银行资料。',
  'Transfer': '转账',
  'Pay using your banking app and keep the receipt.': '使用银行应用付款并保留收据。',
  'Submit': '提交',
  'Attach the receipt here for the owner to review.': '在此上传凭证供业主审核。',
  'Payment help & common questions': '付款帮助与常见问题',
  'Why is this link secure?': '为什么此链接是安全的？',
  'It is a private, time-limited link issued for this invoice. Do not forward it to anyone else.':
      '这是专为此账单签发的私人限时链接，请勿转发给其他人。',
  'What should I upload?': '我应该上传什么？',
  'Upload a clear bank-transfer receipt in JPG, PNG or PDF format below 2 MB.':
      '请上传清晰的银行转账凭证，格式为 JPG、PNG 或 PDF，文件小于 2 MB。',
  'What happens after submission?': '提交后会发生什么？',
  'The owner receives a notification and reviews your proof. Your payment is only confirmed after owner approval.':
      '业主会收到通知并审核您的凭证。只有业主批准后，付款才会被确认。',
  'What if my proof is rejected?': '如果我的凭证被拒绝怎么办？',
  'The owner will provide a reason and send a fresh link so you can upload a corrected proof.':
      '业主会说明原因并发送新链接，让您重新上传正确的凭证。',
  'Need assistance?': '需要协助？',
  'Contact your property owner before submitting if the amount or bank details do not look correct.':
      '如果金额或银行资料看起来不正确，请在提交前联系您的业主。',
  'One tap into your connected home.': '一键连接您的智慧家居。',
  'Secure one-time access — no account, no download. Manage everything from one connected hub.':
      '安全的一次性访问——无需账户，无需下载。一个平台即可完成所有操作。',
  'Digital tenancy': '数码租赁',
  'Paperless & instant': '无纸化并即时处理',
  'Smart home': '智慧家居',
  'One-time': '一次性访问',
  'Secure access': '安全访问',
  "Verify it's you": '验证您的身份',
  'Please key in the last 4 digits of your mobile phone number.':
      '请输入您手机号码的最后 4 位数字。',
  'Verify & continue': '验证并继续',
};

String tenantPortalText(bool chinese, String english) =>
    chinese ? (_tenantPortalChinese[english] ?? english) : english;

String tenantPortalErrorText(bool chinese, Object error) {
  final message = error.toString().replaceFirst('Bad state: ', '');
  return tenantPortalText(chinese, message);
}

String tenantPortalPeriod(bool chinese, String period) {
  if (!chinese) return period;
  const months = <String, String>{
    'Jan': '1月',
    'Feb': '2月',
    'Mar': '3月',
    'Apr': '4月',
    'May': '5月',
    'Jun': '6月',
    'Jul': '7月',
    'Aug': '8月',
    'Sep': '9月',
    'Oct': '10月',
    'Nov': '11月',
    'Dec': '12月',
  };
  final parts = period.trim().split(RegExp(r'\s+'));
  if (parts.length != 2 || !months.containsKey(parts.first)) return period;
  return '${parts.last}年${months[parts.first]}';
}

class _TenantPortalLanguageScope extends InheritedWidget {
  const _TenantPortalLanguageScope({
    required this.chinese,
    required this.onToggle,
    required super.child,
  });

  final bool chinese;
  final VoidCallback onToggle;

  static _TenantPortalLanguageScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TenantPortalLanguageScope>()!;

  @override
  bool updateShouldNotify(_TenantPortalLanguageScope oldWidget) =>
      chinese != oldWidget.chinese;
}

String _portalText(BuildContext context, String english) =>
    tenantPortalText(_TenantPortalLanguageScope.of(context).chinese, english);

class _TenantPortalLanguageSwitch extends StatelessWidget {
  const _TenantPortalLanguageSwitch({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final language = _TenantPortalLanguageScope.of(context);
    return Semantics(
      button: true,
      label: language.chinese ? 'Switch tenant portal to English' : '切换租户页面为中文',
      child: Material(
        color: onDark ? const Color(0x2AFFFFFF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const Key('tenant_portal_language_switch'),
          onTap: language.onToggle,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Text(
              language.chinese ? '中文 / EN' : 'EN / 中文',
              style: TextStyle(
                color: onDark ? Colors.white : _portalDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _canvas = Color(0xFFF4F7FB);
const _label = Color(0xFF0F172A);
const _secondary = Color(0xFF64748B);
const _combinedElectricityMarker = '__HOMEOPS_COMBINED__';
const tenantPortalRelease = '20260721-7';

String tenantPortalBaseUrlForHost([String? host]) =>
    SupabaseConfig.isUatHost(host)
        ? 'https://facility-billing-management.pages.dev/'
        : 'https://homeops360.app/';

Uri tenantInvoiceLink(String invoiceId, String portalToken) =>
    Uri.parse(tenantPortalBaseUrlForHost()).replace(
      queryParameters: {
        // The random token is both the short lookup key and the bearer secret.
        // The server stores only its SHA-256 hash and expires it after 72 hours.
        'pay': portalToken,
      },
    );

String? tenantPortalTokenFromUri(Uri uri) {
  final shortToken = uri.queryParameters['pay'];
  if (shortToken != null && shortToken.isNotEmpty) return shortToken;
  final legacyToken = uri.queryParameters['token'];
  if (legacyToken != null && legacyToken.isNotEmpty) return legacyToken;
  if (uri.fragment.isEmpty) return null;
  try {
    return Uri.splitQueryString(uri.fragment)['token'];
  } on FormatException {
    return null;
  }
}

String? _signedInTenantEmail() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  final role = user.userMetadata?['role']?.toString().toLowerCase();
  if (role != 'tenant') return null;
  return user.email;
}

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
              SecurePortalBanner(),
              Expanded(child: BillingPage()),
            ],
          ),
        ),
      );
}

class _RentFlowAppState extends State<RentFlowApp> {
  late final RentFlowStore store;

  @override
  void initState() {
    super.initState();
    store = RentFlowStore(
      portalInvoiceId: Uri.base.queryParameters['invoice'],
      portalToken: tenantPortalTokenFromUri(Uri.base),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceId = Uri.base.queryParameters['invoice'];
    final isTenantPortal = tenantPortalTokenFromUri(Uri.base) != null;
    return RentFlowScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HomeOps360',
          builder: (context, child) => EnvironmentBanner(
            child: child ?? const SizedBox.shrink(),
          ),
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
          home: isTenantPortal
              ? TenantInvoicePage(
                  invoiceId: invoiceId,
                  authenticatedTenantEmail: _signedInTenantEmail(),
                )
              : const OwnerShell(),
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
    this.evidenceRequired = true,
    this.evidencePath,
    this.evidenceBytes,
    this.generalElectricAmount = 0,
    this.parkingRentalAmount = 0,
    this.electricityTariffName = 'TNB default tariff',
    this.electricityRatePerKwh = 0.516,
    this.electricityAmountOverride,
    this.electricityTariffSummary,
    this.electricityLabel = 'Air-con electricity',
    required this.dueDate,
    this.status = InvoiceStatus.sent,
    this.pdfPath,
    this.pdfUrl,
    this.portalToken,
    this.slipName,
    this.slipPath,
    this.amountPaid,
    this.paymentDate,
    this.paymentReference,
    this.slipSubmittedAt,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankBeneficiary = '',
    this.paymentQrName,
    this.paymentQrBase64,
  });
  final String id;
  final TenantAccount tenant;
  final String period;
  final String usagePeriod;
  final double previousReading;
  final double currentReading;
  final String evidenceName;
  final bool evidenceRequired;
  final String? evidencePath;
  final Uint8List? evidenceBytes;
  final double generalElectricAmount;
  final double parkingRentalAmount;
  final String electricityTariffName;
  final double electricityRatePerKwh;
  final double? electricityAmountOverride;
  final String? electricityTariffSummary;
  final String electricityLabel;
  DateTime dueDate;
  InvoiceStatus status;
  final String? pdfPath;
  Uri? pdfUrl;
  String? portalToken;
  String? slipName;
  String? slipPath;
  double? amountPaid;
  DateTime? paymentDate;
  String? paymentReference;
  DateTime? slipSubmittedAt;
  final String bankName;
  final String bankAccountNumber;
  final String bankBeneficiary;
  final String? paymentQrName;
  final String? paymentQrBase64;

  double get usage => math.max(0, currentReading - previousReading);
  double get electricity =>
      electricityAmountOverride ??
      (usage * electricityRatePerKwh * 100).round() / 100;
  bool get usesCombinedElectricity => electricityLabel == 'Electricity';
  double get displayedElectricity =>
      electricity + (usesCombinedElectricity ? generalElectricAmount : 0);
  double get total =>
      tenant.rent +
      tenant.water +
      tenant.internet +
      generalElectricAmount +
      electricity +
      parkingRentalAmount;
}

Map<String, dynamic> invoiceCloudRecord(
  RentalInvoice invoice, {
  String? pdfPath,
}) =>
    {
      'id': invoice.id,
      'tenant_id': invoice.tenant.id,
      'tenant_name': invoice.tenant.name,
      'tenant_email': invoice.tenant.email,
      'tenant_phone': invoice.tenant.phone,
      'property_name': invoice.tenant.property,
      'unit_name': invoice.tenant.unit,
      'rent': invoice.tenant.rent,
      'water': invoice.tenant.water,
      'internet': invoice.tenant.internet,
      'period': invoice.period,
      'usage_period': invoice.usagePeriod,
      'previous_reading': invoice.previousReading,
      'current_reading': invoice.currentReading,
      'electricity_tariff_name': invoice.electricityTariffName,
      'electricity_rate_per_kwh': invoice.electricityRatePerKwh,
      'electricity_amount': invoice.electricity,
      'electricity_tariff_summary': invoice.usesCombinedElectricity
          ? '$_combinedElectricityMarker${invoice.electricityTariffSummary ?? ''}'
          : invoice.electricityTariffSummary,
      'electricity_label': invoice.electricityLabel,
      'general_electric': invoice.generalElectricAmount,
      'parking_rental': invoice.parkingRentalAmount,
      'evidence_name': invoice.evidenceName,
      'evidence_path': invoice.evidencePath,
      'pdf_path': pdfPath ?? invoice.pdfPath,
      'due_date': invoice.dueDate.toIso8601String(),
      'status': invoice.status.name,
      'bank_name': invoice.bankName,
      'bank_account_number': invoice.bankAccountNumber,
      'bank_beneficiary': invoice.bankBeneficiary,
      'payment_qr_name': invoice.paymentQrName,
      'payment_qr_base64': invoice.paymentQrBase64,
    };

String? _cleanElectricityTariffSummary(Map<String, dynamic> row) {
  final value = row['electricity_tariff_summary'] as String?;
  if (value == null) return null;
  return value.startsWith(_combinedElectricityMarker)
      ? value.substring(_combinedElectricityMarker.length)
      : value;
}

String _electricityLabelFromRow(Map<String, dynamic> row) {
  final summary = row['electricity_tariff_summary'] as String? ?? '';
  if (summary.startsWith(_combinedElectricityMarker)) return 'Electricity';
  return row['electricity_label'] as String? ?? 'Air-con electricity';
}

class RentFlowStore extends ChangeNotifier {
  static const bucket = 'rentflow-test-files';
  final SupabaseClient _cloud = Supabase.instance.client;
  late final InvoicePortalService _portalService = InvoicePortalService(_cloud);
  final String? portalInvoiceId;
  final String? portalToken;
  bool loading = true;
  String? error;

  final tenants = const [
    TenantAccount(
      id: 'tenant_1',
      name: 'Nur Aisyah Binti Rahman',
      email: 'tenant1a@example.com',
      phone: '+60120000001',
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

  RentFlowStore({this.portalInvoiceId, this.portalToken}) {
    if (portalInvoiceId != null || portalToken != null) {
      loadPortalInvoice();
      return;
    }
    loadInvoices();
    _cloud
        .channel('rentflow-owner-invoices')
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

  RentalInvoice _invoiceFromRow(Map<String, dynamic> row) => RentalInvoice(
        id: row['id'] as String,
        tenant: _tenantFromRow(row),
        period: row['period'] as String,
        usagePeriod: row['usage_period'] as String,
        previousReading: (row['previous_reading'] as num).toDouble(),
        currentReading: (row['current_reading'] as num).toDouble(),
        evidenceName: row['evidence_name'] as String,
        evidencePath: row['evidence_path'] as String?,
        generalElectricAmount:
            (row['general_electric'] as num?)?.toDouble() ?? 0,
        parkingRentalAmount: (row['parking_rental'] as num?)?.toDouble() ?? 0,
        electricityTariffName:
            row['electricity_tariff_name'] as String? ?? 'Owner tariff',
        electricityRatePerKwh:
            (row['electricity_rate_per_kwh'] as num?)?.toDouble() ?? 0.516,
        electricityAmountOverride:
            (row['electricity_amount'] as num?)?.toDouble(),
        electricityTariffSummary: _cleanElectricityTariffSummary(row),
        electricityLabel: _electricityLabelFromRow(row),
        dueDate: DateTime.parse(row['due_date'] as String),
        status: InvoiceStatus.values.byName(row['status'] as String),
        pdfPath: row['pdf_path'] as String?,
        pdfUrl: row['pdf_url'] == null
            ? null
            : Uri.tryParse(row['pdf_url'].toString()),
        portalToken: portalToken,
        slipName: row['slip_name'] as String?,
        slipPath: row['slip_path'] as String?,
        amountPaid: (row['amount_paid'] as num?)?.toDouble(),
        paymentDate: row['payment_date'] == null
            ? null
            : DateTime.tryParse(row['payment_date'] as String),
        paymentReference: row['payment_reference'] as String?,
        slipSubmittedAt: row['slip_submitted_at'] == null
            ? null
            : DateTime.tryParse(row['slip_submitted_at'] as String),
        bankName: row['bank_name'] as String? ?? '',
        bankAccountNumber: row['bank_account_number'] as String? ?? '',
        bankBeneficiary: row['bank_beneficiary'] as String? ?? '',
        paymentQrName: row['payment_qr_name'] as String?,
        paymentQrBase64: row['payment_qr_base64'] as String?,
      );

  Future<void> loadPortalInvoice() async {
    try {
      final token = portalToken?.trim() ?? '';
      if (token.isEmpty) {
        throw const AuthException('This secure invoice link is incomplete.');
      }
      final row = await _portalService.load(
        invoiceId: portalInvoiceId,
        token: token,
      );
      invoices
        ..clear()
        ..add(_invoiceFromRow(row));
      error = null;
    } catch (exception) {
      error = exception.toString();
      invoices.clear();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadInvoices() async {
    try {
      final rows = await _cloud
          .from('rentflow_test_invoices')
          .select()
          .order('created_at', ascending: false);
      invoices
        ..clear()
        ..addAll(rows.map((row) => _invoiceFromRow(row)));
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
    final owner = _cloud.auth.currentUser;
    if (owner == null) throw const AuthException('Owner sign-in is required.');
    final id = 'RF-${DateTime.now().millisecondsSinceEpoch}';
    final evidencePath = '${owner.id}/meter/$id/${_safeName(evidence)}';
    final pdfPath = '${owner.id}/invoices/$id.pdf';
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
      pdfPath: pdfPath,
      dueDate: DateTime.now().add(const Duration(days: 3)),
    );
    await _cloud.storage.from(bucket).uploadBinary(
          pdfPath,
          await invoicePdf(item),
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
          ),
        );
    final access = await _portalService.publish(invoiceCloudRecord(item));
    item
      ..portalToken = access.portalToken
      ..pdfUrl = access.pdfUrl;
    invoices.insert(0, item);
    notifications.insert(0, 'Invoice ${item.id} sent to ${tenant.name}.');
    notifyListeners();
    return item;
  }

  Future<void> submitSlip(
    RentalInvoice invoice,
    String name,
    Uint8List bytes, {
    required double amountPaid,
    required DateTime paymentDate,
    String? paymentReference,
  }) async {
    final token = invoice.portalToken ?? portalToken;
    if (token != null && token.isNotEmpty) {
      await _portalService.submitPayment(
        invoiceId: invoice.id,
        token: token,
        fileName: name,
        bytes: bytes,
        amountPaid: amountPaid,
        paymentDate: paymentDate,
        paymentReference: paymentReference,
      );
      invoice
        ..slipName = name
        ..amountPaid = amountPaid
        ..paymentDate = paymentDate
        ..paymentReference = paymentReference?.trim()
        ..slipSubmittedAt = DateTime.now()
        ..status = InvoiceStatus.slipSubmitted;
      notifyListeners();
      return;
    }
    final owner = _cloud.auth.currentUser;
    if (owner == null) throw const AuthException('Owner sign-in is required.');
    final path = '${owner.id}/slips/${invoice.id}/'
        '${DateTime.now().millisecondsSinceEpoch}-${_safeName(name)}';
    await _cloud.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    invoice.slipName = name;
    invoice.slipPath = path;
    invoice.amountPaid = amountPaid;
    invoice.paymentDate = paymentDate;
    invoice.paymentReference = paymentReference?.trim();
    invoice.slipSubmittedAt = DateTime.now();
    invoice.status = InvoiceStatus.slipSubmitted;
    await _cloud.from('rentflow_test_invoices').update({
      'slip_name': name,
      'slip_path': path,
      'amount_paid': amountPaid,
      'payment_date': paymentDate.toIso8601String(),
      'payment_reference': invoice.paymentReference,
      'slip_submitted_at': invoice.slipSubmittedAt!.toIso8601String(),
      'status': invoice.status.name,
    }).eq('id', invoice.id);
    notifications.insert(
      0,
      '${invoice.tenant.name} uploaded a payment slip for ${invoice.period}.',
    );
    notifyListeners();
  }

  Future<PublishedInvoiceAccess> publishInvoice(RentalInvoice invoice) async {
    if (invoice.status == InvoiceStatus.paid) {
      throw StateError(
          'An approved invoice is locked and cannot be sent again.');
    }
    final owner = _cloud.auth.currentUser;
    if (owner == null) throw const AuthException('Owner sign-in is required.');
    final pdfPath = invoice.pdfPath ?? '${owner.id}/invoices/${invoice.id}.pdf';
    await _cloud.storage.from(bucket).uploadBinary(
          pdfPath,
          await invoicePdf(invoice),
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
          ),
        );
    final access = await _portalService.publish(
      invoiceCloudRecord(invoice, pdfPath: pdfPath),
    );
    invoice
      ..portalToken = access.portalToken
      ..pdfUrl = access.pdfUrl;
    notifyListeners();
    return access;
  }

  Future<void> approve(RentalInvoice invoice) async {
    invoice.status = InvoiceStatus.paid;
    await _cloud.from('rentflow_test_invoices').update({
      'status': invoice.status.name,
    }).eq('id', invoice.id);
    notifications.insert(0, 'Payment ${invoice.id} approved.');
    notifyListeners();
  }

  Future<Uri> signedFileUrl(String path) async {
    final result = await _cloud.storage.from(bucket).createSignedUrl(path, 600);
    return Uri.parse(result);
  }

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
            const SecurePortalBanner(),
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
            const HomeOpsLockup(markSize: 38, fontSize: 21),
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

class SecurePortalBanner extends StatelessWidget {
  const SecurePortalBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFEAF8EF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: const Text(
          'SECURE INVOICE PORTAL · Private files and expiring tenant access links',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF15803D),
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
  const TenantInvoicePage({
    required this.invoiceId,
    this.authenticatedTenantEmail,
    super.key,
  });
  final String? invoiceId;
  final String? authenticatedTenantEmail;

  @override
  State<TenantInvoicePage> createState() => _TenantInvoicePageState();
}

class _TenantInvoicePageState extends State<TenantInvoicePage> {
  final verificationCode = TextEditingController();
  final verificationFocus = FocusNode();
  final amount = TextEditingController();
  final paymentDate = TextEditingController();
  final reference = TextEditingController();
  PickedImageData? proof;
  bool verified = false;
  bool submitting = false;
  bool chinese = false;
  bool authenticatedAccessChecked = false;
  String? error;

  void applyAuthenticatedAccess(RentalInvoice invoice) {
    if (authenticatedAccessChecked) return;
    authenticatedAccessChecked = true;
    final signedInEmail =
        widget.authenticatedTenantEmail?.trim().toLowerCase() ?? '';
    if (signedInEmail.isEmpty ||
        signedInEmail != invoice.tenant.email.trim().toLowerCase()) {
      return;
    }
    verified = true;
    amount.text = invoice.total.toStringAsFixed(2);
    paymentDate.text = shortDate(DateTime.now());
  }

  @override
  void dispose() {
    verificationCode.dispose();
    verificationFocus.dispose();
    amount.dispose();
    paymentDate.dispose();
    reference.dispose();
    super.dispose();
  }

  void verify(RentalInvoice invoice) {
    final entered = verificationCode.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!tenantPhoneVerificationMatches(invoice.tenant.phone, entered)) {
      setState(
        () => error = 'The last 4 digits do not match our records.',
      );
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
      final prepared = _preparePaymentProof(selected);
      setState(() {
        proof = prepared;
        error = null;
      });
    } catch (exception) {
      if (mounted) {
        setState(() => error = tenantPortalErrorText(chinese, exception));
      }
    }
  }

  Future<void> submit(RentFlowStore store, RentalInvoice invoice) async {
    if (proof == null) {
      setState(() {
        error = tenantPortalText(
          chinese,
          'Attach your payment proof before submitting.',
        );
      });
      return;
    }
    final paid = double.tryParse(
      amount.text.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final paidOn = _parseShortDate(paymentDate.text);
    if (paid == null || paid <= 0) {
      setState(() {
        error = tenantPortalText(chinese, 'Enter a valid amount paid.');
      });
      return;
    }
    if (paidOn == null) {
      setState(() {
        error = tenantPortalText(
          chinese,
          'Enter the payment date as DD/MM/YYYY.',
        );
      });
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await store.submitSlip(
        invoice,
        proof!.name,
        Uint8List.fromList(proof!.bytes),
        amountPaid: paid,
        paymentDate: paidOn,
        paymentReference: reference.text,
      );
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = '${tenantPortalText(chinese, 'Upload failed')}: $exception';
        });
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RentFlowScope.of(context);
    final invoice = widget.invoiceId == null
        ? (store.invoices.isEmpty ? null : store.invoices.first)
        : store.invoice(widget.invoiceId!);
    if (store.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (invoice == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEAF0F7),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off_rounded, size: 52, color: _portalDeep),
                  SizedBox(height: 18),
                  Text(
                    'This payment link is unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'It may have expired, been replaced by a newer link, or arrived incomplete. Please ask the property owner to renew and resend the payment link. Your invoice amount remains unchanged.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondary, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    applyAuthenticatedAccess(invoice);
    final completed = invoice.status == InvoiceStatus.slipSubmitted ||
        invoice.status == InvoiceStatus.paid;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0F7),
      resizeToAvoidBottomInset: verified,
      body: SafeArea(
        child: _TenantPortalLanguageScope(
          chinese: chinese,
          onToggle: () => setState(() {
            chinese = !chinese;
            error = null;
          }),
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
                      code: verificationCode,
                      focus: verificationFocus,
                      error: error,
                      onContinue: () => verify(invoice),
                    ),
        ),
      ),
    );
  }
}

bool tenantPhoneVerificationMatches(String phone, String enteredCode) {
  final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final enteredDigits = enteredCode.replaceAll(RegExp(r'[^0-9]'), '');
  if (phoneDigits.length < 4 || enteredDigits.length != 4) return false;
  return enteredDigits == phoneDigits.substring(phoneDigits.length - 4);
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
  final TextEditingController code;
  final FocusNode focus;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _SmartVerificationDesign1b(
        invoice: invoice,
        controller: code,
        focusNode: focus,
        error: error,
        onContinue: onContinue,
      );
}

class _SmartVerificationDesign1b extends StatelessWidget {
  const _SmartVerificationDesign1b({
    required this.invoice,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onContinue,
  });

  final RentalInvoice invoice;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ColoredBox(
              color: const Color(0xFFEEF4FD),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(26, 32, 26, 42),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _portalSky,
                          _portalBlue,
                          _portalDeep,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Expanded(child: _AscentiaHeading()),
                            _TenantPortalLanguageSwitch(onDark: true),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _portalText(
                            context,
                            'One tap into your connected home.',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _portalText(
                            context,
                            'Secure one-time access — no account, no download. Manage everything from one connected hub.',
                          ),
                          style: const TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SmartTile(
                                icon: Icons.description_outlined,
                                title: _portalText(
                                  context,
                                  'Digital tenancy',
                                ),
                                detail: _portalText(
                                  context,
                                  'Paperless & instant',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SmartTile(
                                icon: Icons.home_outlined,
                                title: _portalText(context, 'Smart home'),
                                detail: 'Xiaomi & Tuya',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SmartTile(
                                icon: Icons.lock_outline_rounded,
                                title: _portalText(context, 'One-time'),
                                detail: _portalText(context, 'Secure access'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF4FD),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INVOICE #${invoice.id}',
                            style: const TextStyle(
                              color: Color(0xFF8194AC),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _portalText(context, "Verify it's you"),
                            style: const TextStyle(
                              color: Color(0xFF0C2340),
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _portalText(
                              context,
                              'Please key in the last 4 digits of your mobile phone number.',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF5B7089),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _OtpBoxes1b(
                            controller: controller,
                            focusNode: focusNode,
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              error!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    _portalSky,
                                    _portalDeep,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                onPressed: onContinue,
                                child: Text(
                                  _portalText(context, 'Verify & continue'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),
                          const _SmartSupportRow(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _AscentiaHeading extends StatelessWidget {
  const _AscentiaHeading();

  @override
  Widget build(BuildContext context) => const HomeOpsLockup(
        markSize: 42,
        fontSize: 17,
        onDark: true,
        tagline: 'DIGITAL TENANCY',
      );
}

class _SmartTile extends StatelessWidget {
  const _SmartTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 126),
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33081937),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE5EEFC),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: const Color(0xFF8B9DB8), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0C2340),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                color: Color(0xFF5B7089),
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
}

class _OtpBoxes1b extends StatelessWidget {
  const _OtpBoxes1b({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([controller, focusNode]),
        builder: (context, _) {
          final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: focusNode.requestFocus,
            child: Stack(
              children: [
                Row(
                  children: List.generate(4, (index) {
                    final active = focusNode.hasFocus &&
                        index == math.min(digits.length, 3);
                    return Expanded(
                      child: Container(
                        height: 64,
                        margin: EdgeInsets.only(right: index == 3 ? 0 : 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              active ? Colors.white : const Color(0xFFF5F8FE),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF1668FF)
                                : const Color(0xFFDBE4F2),
                            width: 1.5,
                          ),
                          boxShadow: active
                              ? const [
                                  BoxShadow(
                                    color: Color(0x241668FF),
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          index < digits.length ? digits[index] : '•',
                          style: TextStyle(
                            color: index < digits.length
                                ? const Color(0xFF0C2340)
                                : const Color(0xFFB8C6DD),
                            fontSize: index < digits.length ? 27 : 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.01,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      style: const TextStyle(color: Colors.transparent),
                      cursorColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _SmartSupportRow extends StatelessWidget {
  const _SmartSupportRow();

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: const [
          Text('Supported by',
              style: TextStyle(color: Color(0xFF8194AC), fontSize: 11)),
          _SmartSupportBadge(label: 'Xiaomi Home'),
          _SmartSupportBadge(label: 'Tuya'),
        ],
      );
}

class _SmartSupportBadge extends StatelessWidget {
  const _SmartSupportBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xD9FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD3E0F5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2BB673),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF0C2340),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
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
                    Text(
                      _portalText(context, 'Settle your invoice'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _portalText(
                        context,
                        'Two quick steps — transfer, then attach your slip.',
                      ),
                      style: const TextStyle(color: _secondary),
                    ),
                    const SizedBox(height: 18),
                    _PortalSectionLabel(
                      _portalText(context, 'STEP 1 — TRANSFER TO OWNER'),
                    ),
                    const SizedBox(height: 10),
                    _BankDetailsCard(invoice: invoice),
                    const SizedBox(height: 24),
                    _PortalSectionLabel(
                      _portalText(context, 'STEP 2 — ATTACH PAY SLIP'),
                    ),
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
                                  proof?.name ??
                                      _portalText(
                                        context,
                                        'Tap to attach your receipt',
                                      ),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  _portalText(
                                    context,
                                    'JPG, PNG or PDF · maximum 2 MB',
                                  ),
                                  style: const TextStyle(
                                    color: _secondary,
                                    fontSize: 12,
                                  ),
                                ),
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
                              enabled: false,
                              enableInteractiveSelection: false,
                              decoration: InputDecoration(
                                labelText: _portalText(context, 'Amount paid'),
                                prefixText: 'RM ',
                              ))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: paymentDate,
                              enabled: false,
                              enableInteractiveSelection: false,
                              decoration: InputDecoration(
                                labelText: _portalText(context, 'Date paid'),
                              ))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: reference,
                        decoration: InputDecoration(
                          labelText: _portalText(
                            context,
                            'Payment reference (optional)',
                          ),
                        )),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _portalDeep,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: submitting ? null : onSubmit,
                        child: Text(
                          submitting
                              ? _portalText(context, 'Sending…')
                              : _portalText(context, 'Send payment proof'),
                        ),
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

// Retained temporarily for rollback compatibility; no longer shown in the portal.
// ignore: unused_element
class _SecurePaymentGuide extends StatelessWidget {
  const _SecurePaymentGuide();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFE8F3FF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFDCEEFF),
                  child: Icon(Icons.verified_user_rounded, color: _portalDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _portalText(context, 'Secure payment guide'),
                        style: const TextStyle(
                          color: Color(0xFF0C2340),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _portalText(
                          context,
                          'This private page brings your invoice, owner payment details and receipt upload together in one place.',
                        ),
                        style: const TextStyle(
                          color: _secondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const items = [
                  (
                    Icons.receipt_long_rounded,
                    'Check',
                    'Confirm the invoice amount and owner bank details.',
                  ),
                  (
                    Icons.account_balance_rounded,
                    'Transfer',
                    'Pay using your banking app and keep the receipt.',
                  ),
                  (
                    Icons.cloud_upload_rounded,
                    'Submit',
                    'Attach the receipt here for the owner to review.',
                  ),
                ];
                final cards = items
                    .map(
                      (item) => _PaymentGuideStep(
                        icon: item.$1,
                        title: _portalText(context, item.$2),
                        description: _portalText(context, item.$3),
                      ),
                    )
                    .toList();
                if (constraints.maxWidth < 560) {
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i < cards.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _PaymentGuideStep extends StatelessWidget {
  const _PaymentGuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: _portalDeep),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0C2340),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PaymentHelpPanel extends StatelessWidget {
  const _PaymentHelpPanel();

  static const questions = <(String, String)>[
    (
      'Why is this link secure?',
      'It is a private, time-limited link issued for this invoice. Do not forward it to anyone else.',
    ),
    (
      'What should I upload?',
      'Upload a clear bank-transfer receipt in JPG, PNG or PDF format below 2 MB.',
    ),
    (
      'What happens after submission?',
      'The owner receives a notification and reviews your proof. Your payment is only confirmed after owner approval.',
    ),
    (
      'What if my proof is rejected?',
      'The owner will provide a reason and send a fresh link so you can upload a corrected proof.',
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE7F2FF),
                    child: Icon(Icons.info_outline_rounded, color: _portalDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _portalText(context, 'Payment help & common questions'),
                      style: const TextStyle(
                        color: _label,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _portalText(context, 'Close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < questions.length; i++) ...[
                Text(
                  _portalText(context, questions[i].$1),
                  style: const TextStyle(
                    color: _label,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _portalText(context, questions[i].$2),
                  style: const TextStyle(color: _secondary, height: 1.4),
                ),
                if (i < questions.length - 1)
                  const Divider(height: 22, color: Color(0xFFD7E4F3)),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_portalText(context, 'Need assistance?')} ',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      TextSpan(
                        text: _portalText(
                          context,
                          'Contact your property owner before submitting if the amount or bank details do not look correct.',
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Color(0xFF6B4F00),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PaymentHelpButton extends StatelessWidget {
  const _PaymentHelpButton();

  @override
  Widget build(BuildContext context) {
    final language = _TenantPortalLanguageScope.of(context);
    return Material(
      color: const Color(0x2AFFFFFF),
      borderRadius: BorderRadius.circular(999),
      child: Tooltip(
        message: _portalText(context, 'Payment help & common questions'),
        child: InkWell(
          key: const Key('tenant_payment_help_button'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: false,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _TenantPortalLanguageScope(
              chinese: language.chinese,
              onToggle: language.onToggle,
              child: const FractionallySizedBox(
                heightFactor: .72,
                child: _PaymentHelpPanel(),
              ),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// Kept for the authenticated invoice flow's existing presentation variants.
// ignore: unused_element
class _PortalBrandPanel extends StatelessWidget {
  const _PortalBrandPanel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 340;
          return Container(
            padding: EdgeInsets.all(compact ? 28 : 40),
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
                const HomeOpsLockup(
                  markSize: 40,
                  fontSize: 19,
                  onDark: true,
                  compact: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'PLATINUM VICTORY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: compact ? 28 : 62),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 27 : 30,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: compact ? 10 : 16),
                Text(
                  subtitle,
                  maxLines: compact ? 3 : null,
                  overflow:
                      compact ? TextOverflow.ellipsis : TextOverflow.visible,
                  style: const TextStyle(
                    color: Color(0xDDFFFFFF),
                    height: 1.4,
                  ),
                ),
                if (!compact) ...[
                  const Spacer(),
                  const Text(
                    '© 2026 Platinum Victory',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _InvoicePortalSummary extends StatelessWidget {
  const _InvoicePortalSummary({required this.invoice});
  final RentalInvoice invoice;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_portalSky, _portalBlue, _portalDeep],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Expanded(
                child: HomeOpsLockup(
                  markSize: 40,
                  fontSize: 19,
                  onDark: true,
                  compact: true,
                ),
              ),
              const _TenantPortalLanguageSwitch(onDark: true),
              const SizedBox(width: 7),
              const _PaymentHelpButton(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            invoice.tenant.property,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 44),
          Text(
              '${_portalText(context, 'Amount due').toUpperCase()} · ${tenantPortalPeriod(_TenantPortalLanguageScope.of(context).chinese, invoice.period).toUpperCase()}',
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
              '${_portalText(context, 'Due')} ${shortDate(invoice.dueDate)} · ${_portalText(context, 'Unit')} ${invoice.tenant.unit}',
              style: const TextStyle(color: Color(0xDDFFFFFF))),
          const Divider(height: 42, color: Color(0x55FFFFFF)),
          _PortalCharge(
              _portalText(context, 'Monthly rent'), invoice.tenant.rent),
          _PortalCharge(_portalText(context, 'Water'), invoice.tenant.water),
          _PortalCharge(
              _portalText(context, 'Internet'), invoice.tenant.internet),
          if (!invoice.usesCombinedElectricity)
            _PortalCharge(_portalText(context, 'General electricity'),
                invoice.generalElectricAmount),
          _PortalCharge(
              '${_portalText(context, invoice.electricityLabel)} · ${invoice.usage.toStringAsFixed(2)} kWh',
              invoice.displayedElectricity),
          _PortalCharge(_portalText(context, 'Parking rental'),
              invoice.parkingRentalAmount),
          const Divider(height: 30, color: Color(0x55FFFFFF)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final pdfUrl = invoice.pdfUrl;
                if (pdfUrl != null) {
                  await launchUrl(
                    pdfUrl,
                    mode: LaunchMode.externalApplication,
                  );
                  return;
                }
                if (context.mounted) {
                  await showInvoicePdfPreview(context, invoice);
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(
                _portalText(context, 'Download invoice PDF'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _portalDeep,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
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
  const _BankDetailsCard({required this.invoice});
  final RentalInvoice invoice;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDCE5F0)),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          if (invoice.paymentQrBase64 != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text(
                    _portalText(context, 'Payment QR'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (invoice.paymentQrName?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 3),
                    Text(invoice.paymentQrName!,
                        style:
                            const TextStyle(color: _secondary, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showPaymentQr(context, invoice),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.memory(
                        Uint8List.fromList(
                          base64Decode(invoice.paymentQrBase64!),
                        ),
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _portalText(context, 'Tap QR to enlarge'),
                    style: const TextStyle(color: _secondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ] else ...[
            _BankRow(
              _portalText(context, 'Payment QR'),
              _portalText(context, 'Not configured'),
            ),
            const Divider(height: 1),
          ],
          _BankRow(
            _portalText(context, 'Bank'),
            invoice.bankName.isEmpty
                ? _portalText(context, 'Not configured')
                : invoice.bankName,
          ),
          const Divider(height: 1),
          _BankRow(
              _portalText(context, 'Account no.'),
              invoice.bankAccountNumber.isEmpty
                  ? _portalText(context, 'Not configured')
                  : invoice.bankAccountNumber,
              onTap: invoice.bankAccountNumber.isEmpty
                  ? null
                  : () => _copyBankAccount(context, invoice.bankAccountNumber)),
          const Divider(height: 1),
          _BankRow(
              _portalText(context, 'Beneficiary'),
              invoice.bankBeneficiary.isEmpty
                  ? _portalText(context, 'Not configured')
                  : invoice.bankBeneficiary),
        ]),
      );
}

class _BankRow extends StatelessWidget {
  const _BankRow(this.label, this.value, {this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Expanded(
                child: Text(label, style: const TextStyle(color: _secondary))),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, size: 18, color: _blue),
            ],
          ]),
        ),
      );
}

Future<void> _copyBankAccount(BuildContext context, String account) async {
  await Clipboard.setData(ClipboardData(text: account));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(_portalText(context, 'Bank account copied.')),
      ),
    );
}

Future<void> _showPaymentQr(
  BuildContext context,
  RentalInvoice invoice,
) async {
  final encoded = invoice.paymentQrBase64;
  if (encoded == null || encoded.isEmpty) return;
  final bytes = Uint8List.fromList(base64Decode(encoded));
  final title = _portalText(context, 'Payment QR');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    ),
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
              const Align(
                alignment: Alignment.centerRight,
                child: _TenantPortalLanguageSwitch(),
              ),
              const CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0xFFE7F7EE),
                  child: Icon(Icons.check_rounded,
                      color: Color(0xFF16A34A), size: 38)),
              const SizedBox(height: 22),
              Text(
                  _TenantPortalLanguageScope.of(context).chinese
                      ? '谢谢您，${invoice.tenant.name.split(' ').first}。'
                      : 'Thank you, ${invoice.tenant.name.split(' ').first}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                  invoice.status == InvoiceStatus.paid
                      ? _portalText(
                          context,
                          'Your payment has been confirmed.',
                        )
                      : _TenantPortalLanguageScope.of(context).chinese
                          ? '您为 ${rm(invoice.total)} 上传的付款凭证已发送给业主。'
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
                                ? _portalText(context, 'Payment confirmed')
                                : _portalText(
                                    context,
                                    'Awaiting owner confirmation',
                                  ),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                  onPressed: () => _openTenantInvoicePdf(context, invoice),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_portalText(context, 'Download receipt'))),
            ]),
          ),
        ),
      );
}

Future<void> _openTenantInvoicePdf(
  BuildContext context,
  RentalInvoice invoice,
) async {
  final pdfUrl = invoice.pdfUrl;
  if (pdfUrl == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_portalText(context, 'The invoice PDF is unavailable.')),
      ),
    );
    return;
  }
  final opened = await launchUrl(
    pdfUrl,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: kIsWeb ? '_blank' : null,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_portalText(context, 'The invoice PDF could not be opened.')),
      ),
    );
  }
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
                    HomeOpsLockup(
                      markSize: 38,
                      fontSize: 22,
                      compact: true,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'RENTAL PAYMENT NOTICE',
                      style: TextStyle(
                        fontSize: 12,
                        color: _blue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
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
    barrierDismissible: false,
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
                      const Text(
                        'A new expiring secure link is generated when the invoice is sent.',
                        style: TextStyle(color: _secondary, fontSize: 12),
                      ),
                    ])),
            actions: [
              TextButton(
                  onPressed: () => printInvoice(invoice),
                  child: const Text('PDF')),
              TextButton(
                  onPressed: () async {
                    final access = await store.publishInvoice(invoice);
                    await shareEmail(
                      invoice,
                      tenantInvoiceLink(invoice.id, access.portalToken),
                    );
                  },
                  child: const Text('Email')),
              if (invoice.slipPath != null)
                TextButton(
                    onPressed: () async =>
                        launchUrl(await store.signedFileUrl(invoice.slipPath!)),
                    child: const Text('Review slip')),
              if (invoice.status == InvoiceStatus.slipSubmitted)
                TextButton(
                    onPressed: () async {
                      await store.approve(invoice);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Approve payment')),
              FilledButton.icon(
                  onPressed: () async {
                    final access = await store.publishInvoice(invoice);
                    await shareWhatsApp(
                      invoice,
                      tenantInvoiceLink(invoice.id, access.portalToken),
                      pdfLink: access.pdfUrl,
                    );
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send WhatsApp')),
            ],
          ));
}

Future<void> shareEmail(RentalInvoice invoice, Uri link) async {
  final subject = 'HomeOps360 invoice ${invoice.id} – ${invoice.period}';
  final body =
      'Hi ${invoice.tenant.name},\n\nYour rental invoice is ready. Amount due: ${rm(invoice.total)}.\n\nOpen this link to review/download the invoice and upload your payment slip:\n$link';
  await launchUrl(Uri(
    scheme: 'mailto',
    path: invoice.tenant.email,
    queryParameters: {'subject': subject, 'body': body},
  ));
}

String invoiceWhatsAppMessage(
  RentalInvoice invoice,
  Uri link, {
  Uri? pdfLink,
  bool tenantHasAccount = false,
  Uri? invitationLink,
}) {
  final introduction =
      'Hi ${invoice.tenant.name}, your ${invoice.period} rental invoice is ready. Amount due: ${rm(invoice.total)}.';
  if (tenantHasAccount) {
    return '$introduction\n\nLog in to HomeOps360 to view the invoice PDF and submit your payment:\nhttps://homeops360.app';
  }
  final paymentMessage =
      '$introduction\n\nPay or view the invoice PDF using this secure link:\n$link';
  if (invitationLink == null) return paymentMessage;
  return '$paymentMessage\n\nCreate your HomeOps360 account and password using this invitation link. The invitation is valid for 72 hours:\n$invitationLink';
}

bool _whatsAppLaunchInProgress = false;

Future<void> shareWhatsApp(
  RentalInvoice invoice,
  Uri link, {
  Uri? pdfLink,
  bool tenantHasAccount = false,
  Uri? invitationLink,
  String? messageOverride,
}) async {
  if (_whatsAppLaunchInProgress) return;
  _whatsAppLaunchInProgress = true;
  final message = messageOverride ??
      invoiceWhatsAppMessage(
        invoice,
        link,
        pdfLink: pdfLink,
        tenantHasAccount: tenantHasAccount,
        invitationLink: invitationLink,
      );
  final whatsappPhone = invoice.tenant.phone.replaceAll(RegExp(r'\D'), '');
  final uri = Uri.parse(
      'https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(message)}');
  try {
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
  } finally {
    Future<void>.delayed(const Duration(seconds: 2), () {
      _whatsAppLaunchInProgress = false;
    });
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
  final prepared = _preparePaymentProof(
    PickedImageData(name: file.name, bytes: file.bytes!),
  );
  await RentFlowScope.of(context).submitSlip(
    invoice,
    prepared.name,
    Uint8List.fromList(prepared.bytes),
    amountPaid: invoice.total,
    paymentDate: DateTime.now(),
  );
}

const int _paymentProofMaxBytes = 2 * 1024 * 1024;

PickedImageData _preparePaymentProof(PickedImageData selected) {
  if (selected.bytes.length <= _paymentProofMaxBytes) return selected;
  if (selected.name.toLowerCase().endsWith('.pdf')) {
    throw StateError('Payment proof PDF must be smaller than 2 MB.');
  }
  final decoded = img.decodeImage(Uint8List.fromList(selected.bytes));
  if (decoded == null) {
    throw StateError(
      'This picture could not be compressed. Please choose JPG or PNG.',
    );
  }
  var working = decoded;
  const maximumSide = 1800;
  final longest = math.max(working.width, working.height);
  if (longest > maximumSide) {
    working = img.copyResize(
      working,
      width: working.width >= working.height ? maximumSide : null,
      height: working.height > working.width ? maximumSide : null,
      interpolation: img.Interpolation.linear,
    );
  }
  Uint8List output = Uint8List(0);
  for (final quality in <int>[82, 72, 62, 52, 42]) {
    output = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    if (output.length <= _paymentProofMaxBytes) break;
  }
  if (output.length > _paymentProofMaxBytes) {
    throw StateError(
      'This picture is still above 2 MB after compression. Choose a smaller photo.',
    );
  }
  final dot = selected.name.lastIndexOf('.');
  final base = dot > 0 ? selected.name.substring(0, dot) : selected.name;
  return PickedImageData(name: '$base-compressed.jpg', bytes: output);
}

DateTime? _parseShortDate(String input) {
  final parts = input.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  final value = DateTime(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}

Future<Uint8List> invoicePdf(RentalInvoice invoice) async {
  final evidence = _prepareEvidenceForPdf(invoice.evidenceBytes);
  if (invoice.evidenceRequired && invoice.usage > 0 && evidence == null) {
    throw StateError(
      'Meter-reading evidence is required before this invoice PDF can be generated.',
    );
  }
  final fontData = await rootBundle.load('assets/fonts/Manrope-Variable.ttf');
  final font = pw.Font.ttf(fontData);
  final theme = pw.ThemeData.withFont(
    base: font,
    bold: font,
    italic: font,
    boldItalic: font,
  );
  final doc = pw.Document();
  doc.addPage(_noticePage(invoice, theme));
  if (invoice.evidenceRequired) {
    doc.addPage(_evidencePage(invoice, evidence, theme));
  }
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

pw.Page _noticePage(RentalInvoice invoice, pw.ThemeData theme) {
  final navy = PdfColor.fromHex('#17233C');
  final muted = PdfColor.fromHex('#62708A');
  final line = PdfColor.fromHex('#CCD6E5');
  final paleBlue = PdfColor.fromHex('#EEF4FD');
  final paleGreen = PdfColor.fromHex('#E8F7F1');
  final green = PdfColor.fromHex('#167457');
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
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
            if (!invoice.usesCombinedElectricity)
              _pdfChargeRow(
                  'General electricity',
                  'Monthly general electricity charge',
                  rm(invoice.generalElectricAmount),
                  true,
                  line,
                  muted),
            _pdfChargeRow(
                invoice.electricityLabel,
                '${invoice.usagePeriod} usage: ${invoice.usage.toStringAsFixed(2)} kWh\n${invoice.electricityTariffSummary ?? '${invoice.electricityTariffName} RM ${invoice.electricityRatePerKwh.toStringAsFixed(3)} / kWh'}\nRounded to ${rm(invoice.electricity)}',
                rm(invoice.displayedElectricity),
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

pw.Page _evidencePage(
  RentalInvoice invoice,
  Uint8List? evidenceBytes,
  pw.ThemeData theme,
) {
  final navy = PdfColor.fromHex('#17233C');
  final muted = PdfColor.fromHex('#62708A');
  final line = PdfColor.fromHex('#CCD6E5');
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
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

pw.Widget _pdfTopLine(PdfColor muted) => pw.Row(
      children: [
        pw.SvgImage(svg: homeOps360IconSvg, width: 28, height: 28),
        pw.SizedBox(width: 8),
        pw.Text(
          'HomeOps360',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#0E1B33'),
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Spacer(),
        pw.Text(
          'Digital bill generated by HomeOps360',
          style: pw.TextStyle(fontSize: 8, color: muted),
        ),
      ],
    );
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
              child: pw.Row(
                children: [
                  pw.SvgImage(svg: homeOps360IconSvg, width: 42, height: 42),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Text(
                      '${invoice.period.toUpperCase()} RENTAL PAYMENT NOTICE',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#17233C'),
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
                    pw.Text(invoice.tenant.property,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text('HomeOps360',
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
  final browserTab = kIsWeb ? preparePdfBrowserTab() : null;
  try {
    if (kIsWeb) {
      final webPdfBytes = await invoicePdf(invoice);
      await showPdfInBrowserTab(
        browserTab!,
        webPdfBytes,
        '${invoice.id}.pdf',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (previewContext) {
        final compact = MediaQuery.sizeOf(previewContext).width < 700;
        return Dialog(
          insetPadding: compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 0 : 24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: MediaQuery.sizeOf(previewContext).height,
            ),
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Close preview',
                          onPressed: () => Navigator.pop(previewContext),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${invoice.id}.pdf',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close preview',
                          onPressed: () => Navigator.pop(previewContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    build: (_) => invoicePdf(invoice),
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: '${invoice.id}.pdf',
                    useActions: false,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    dynamicLayout: false,
                    maxPageWidth: 760,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    onError: (errorContext, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'The invoice preview could not be displayed. $error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } catch (error) {
    if (browserTab != null) closePdfBrowserTab(browserTab);
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
