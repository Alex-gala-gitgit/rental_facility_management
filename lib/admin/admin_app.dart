import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_service.dart';
import '../subscription/diamond_crown.dart';
import '../subscription/premium_key.dart';

const _adminNavy = Color(0xFF10213D);
const _adminBlue = Color(0xFF2675DB);
const _adminCanvas = Color(0xFFF3F6FA);
const _adminGreen = Color(0xFF0E8A6B);
const _adminOrange = Color(0xFFD17A19);
const _adminRed = Color(0xFFC83C52);
const _adminMuted = Color(0xFF6C7B92);

bool _isOtpRateLimitError(Object error) {
  final description = error.toString().toLowerCase();
  return description.contains('rate limit') ||
      description.contains('statuscode: 429') ||
      description.contains('statuscode:429') ||
      description.contains('over_email_send_rate_limit');
}

String _otpRequestErrorMessage(Object error) {
  if (_isOtpRateLimitError(error)) {
    return 'Too many codes were requested. Please wait 60 seconds, then try once.';
  }
  return 'The verification email could not be sent. Please try again shortly.';
}

class HomeOpsAdminApp extends StatelessWidget {
  const HomeOpsAdminApp({required this.client, super.key});

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HomeOps360 Administration',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _adminBlue,
          primary: _adminBlue,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _adminCanvas,
        fontFamily: 'Manrope',
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E0EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E0EC)),
          ),
        ),
      ),
      home: _AdminGate(service: AdminPortalService(client)),
    );
  }
}

class _AdminGate extends StatefulWidget {
  const _AdminGate({required this.service});
  final AdminPortalService service;

  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  Map<String, dynamic>? data;
  Object? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.service.currentSession != null) unawaited(_load());
  }

  Future<void> _load({String action = 'bootstrap', DateTime? month}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next =
          await widget.service.loadConsole(action: action, month: month);
      if (!mounted) return;
      setState(() => data = next);
    } catch (caught) {
      if (!mounted) return;
      await widget.service.signOut();
      setState(() {
        data = null;
        error = caught;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data != null) {
      return AdminPortalShell(
        service: widget.service,
        initialData: data!,
        onSignedOut: () => setState(() => data = null),
      );
    }
    return AdminOtpLogin(
      service: widget.service,
      loadingConsole: loading,
      initialError: error?.toString(),
      onVerified: () => _load(),
    );
  }
}

class AdminOtpLogin extends StatefulWidget {
  const AdminOtpLogin({
    required this.service,
    required this.loadingConsole,
    required this.onVerified,
    this.initialError,
    super.key,
  });

  final AdminPortalService service;
  final bool loadingConsole;
  final String? initialError;
  final Future<void> Function() onVerified;

  @override
  State<AdminOtpLogin> createState() => _AdminOtpLoginState();
}

class _AdminOtpLoginState extends State<AdminOtpLogin> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  bool codeSent = false;
  bool busy = false;
  String? message;
  bool messageIsError = false;
  int resendSeconds = 0;
  Timer? resendTimer;

  @override
  void dispose() {
    resendTimer?.cancel();
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  void startResendCooldown() {
    resendTimer?.cancel();
    setState(() => resendSeconds = 60);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (resendSeconds <= 1) {
        timer.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds -= 1);
      }
    });
  }

  Future<void> resendCode() async {
    if (busy || resendSeconds > 0) return;
    setState(() {
      busy = true;
      message = null;
      messageIsError = false;
    });
    try {
      await widget.service.requestEmailOtp(emailController.text);
      if (!mounted) return;
      codeController.clear();
      setState(() {
        message = 'A new code was sent. Check Inbox, Spam and Junk folders.';
        messageIsError = false;
      });
      startResendCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        message = _otpRequestErrorMessage(error);
        messageIsError = true;
      });
      startResendCooldown();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy) return;
    final email = emailController.text.trim();
    if (!codeSent &&
        (!email.contains('@') ||
            email.startsWith('@') ||
            email.endsWith('@'))) {
      setState(() {
        message = 'Enter a valid approved administrator email.';
        messageIsError = true;
      });
      return;
    }
    if (codeSent && !RegExp(r'^\d{6}$').hasMatch(codeController.text.trim())) {
      setState(() {
        message = 'Enter the complete 6-digit code from your email.';
        messageIsError = true;
      });
      return;
    }
    setState(() {
      busy = true;
      message = null;
      messageIsError = false;
    });
    try {
      if (!codeSent) {
        await widget.service.requestEmailOtp(emailController.text);
        if (!mounted) return;
        setState(() {
          codeSent = true;
          message = 'Code sent. Check Inbox, Spam and Junk folders.';
          messageIsError = false;
        });
        startResendCooldown();
      } else {
        await widget.service.verifyEmailOtp(
          email: emailController.text,
          code: codeController.text,
        );
        await widget.onVerified();
      }
    } catch (error) {
      if (mounted) {
        final requestWasRateLimited = !codeSent && _isOtpRateLimitError(error);
        setState(() {
          message = codeSent
              ? 'The code is invalid or expired. Request a new code and try again.'
              : _otpRequestErrorMessage(error);
          messageIsError = true;
        });
        if (requestWasRateLimited) startResendCooldown();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessage = message ?? widget.initialError;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final introduction = Container(
                    width: wide ? 430 : null,
                    padding: const EdgeInsets.all(38),
                    color: _adminNavy,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminLogo(light: true),
                        SizedBox(height: 34),
                        Text('Secure administration',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 31,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 10),
                        Text(
                            'Monitor application usage, manage owner access and review platform activity from one protected workspace.',
                            style: TextStyle(
                                color: Color(0xFFC7D4E7), height: 1.5)),
                        SizedBox(height: 28),
                        _LoginPoint(
                            icon: Icons.verified_user_outlined,
                            text: 'Allowlisted administrators only'),
                        _LoginPoint(
                            icon: Icons.mark_email_read_outlined,
                            text: 'Email verification on every new session'),
                        _LoginPoint(
                            icon: Icons.history_rounded,
                            text: 'Sensitive actions recorded permanently'),
                      ],
                    ),
                  );
                  final form = Padding(
                    padding: const EdgeInsets.all(38),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Administrator sign in',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: _adminNavy)),
                        const SizedBox(height: 7),
                        const Text(
                            'Use an approved administrator email. Access is checked again after the code is verified.',
                            style: TextStyle(color: _adminMuted, height: 1.45)),
                        const SizedBox(height: 24),
                        TextField(
                          controller: emailController,
                          enabled: !codeSent,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                              labelText: 'Administrator email',
                              prefixIcon: Icon(Icons.alternate_email_rounded)),
                        ),
                        if (codeSent) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: codeController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6)
                            ],
                            decoration: const InputDecoration(
                                labelText: '6-digit email code',
                                prefixIcon: Icon(Icons.password_rounded)),
                            onChanged: (_) => setState(() {
                              if (messageIsError) message = null;
                              messageIsError = false;
                            }),
                            onSubmitted: (_) => submit(),
                          ),
                        ],
                        if (visibleMessage != null) ...[
                          const SizedBox(height: 13),
                          Text(visibleMessage,
                              style: TextStyle(
                                  color: messageIsError ||
                                          (message == null &&
                                              widget.initialError != null)
                                      ? _adminRed
                                      : _adminGreen)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: busy ||
                                  widget.loadingConsole ||
                                  (!codeSent && resendSeconds > 0) ||
                                  (codeSent &&
                                      codeController.text.trim().length != 6)
                              ? null
                              : submit,
                          icon: busy || widget.loadingConsole
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(codeSent
                                  ? Icons.lock_open_rounded
                                  : Icons.send_rounded),
                          label: Text(codeSent
                              ? 'Verify and open portal'
                              : resendSeconds > 0
                                  ? 'Try again in ${resendSeconds}s'
                                  : 'Send 6-digit code'),
                          style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16)),
                        ),
                        if (codeSent)
                          Column(
                            children: [
                              TextButton.icon(
                                onPressed: busy || resendSeconds > 0
                                    ? null
                                    : resendCode,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(resendSeconds > 0
                                    ? 'Resend code in ${resendSeconds}s'
                                    : 'Resend email code'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          codeSent = false;
                                          codeController.clear();
                                          message = null;
                                          messageIsError = false;
                                          resendTimer?.cancel();
                                          resendSeconds = 0;
                                        }),
                                child: const Text('Use a different email'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                  return wide
                      ? Row(children: [introduction, Expanded(child: form)])
                      : Column(children: [introduction, form]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginPoint extends StatelessWidget {
  const _LoginPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF65D6BB), size: 20),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(text, style: const TextStyle(color: Color(0xFFD9E5F5))))
        ]),
      );
}

class _AdminLogo extends StatelessWidget {
  const _AdminLogo({this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF48A4EE), Color(0xFF19C0A9)]),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.home_rounded, color: Colors.white)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HomeOps360',
                style: TextStyle(
                    color: light ? Colors.white : _adminNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
            Text('Administration',
                style: TextStyle(
                    color: light ? const Color(0xFFBFD0E7) : _adminMuted,
                    fontSize: 11))
          ]),
        ],
      );
}

enum AdminSection {
  overview,
  usage,
  owners,
  accounts,
  admins,
  subscriptions,
  requests,
  issues,
  reports,
  api,
  audit,
}

class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({
    required this.service,
    required this.initialData,
    required this.onSignedOut,
    super.key,
  });

  final AdminPortalService service;
  final Map<String, dynamic> initialData;
  final VoidCallback onSignedOut;

  @override
  State<AdminPortalShell> createState() => _AdminPortalShellState();
}

class _AdminPortalShellState extends State<AdminPortalShell> {
  late Map<String, dynamic> data;
  AdminSection section = AdminSection.overview;
  Map<String, dynamic>? selectedOwner;
  bool refreshing = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    data = widget.initialData;
  }

  Future<void> refresh({DateTime? month}) async {
    if (refreshing) return;
    setState(() {
      refreshing = true;
      notice = null;
    });
    try {
      final next =
          await widget.service.loadConsole(action: 'refresh', month: month);
      if (!mounted) return;
      setState(() {
        data = {...data, ...next};
        if (selectedOwner != null) {
          final ownerId = selectedOwner!['id'];
          final refreshedOwners = adminMapList(data['owners']);
          final matches =
              refreshedOwners.where((owner) => owner['id'] == ownerId);
          if (matches.isNotEmpty) selectedOwner = matches.first;
        }
      });
    } catch (error) {
      if (mounted) setState(() => notice = error.toString());
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void openOwner(Map<String, dynamic> owner) {
    if (adminMap(data['permissions'])['canViewOwnerDetails'] != true) return;
    setState(() {
      selectedOwner = owner;
      section = AdminSection.owners;
    });
  }

  Future<void> signOut() async {
    await widget.service.signOut();
    widget.onSignedOut();
  }

  Widget page() {
    final permissions = adminMap(data['permissions']);
    final canViewOwnerDetails = permissions['canViewOwnerDetails'] == true;
    final canViewMonthlyReports = permissions['canViewMonthlyReports'] == true;
    final canManageAdmins = permissions['canManageAdmins'] == true;
    final canManageAccounts = permissions['canManageAccounts'] == true;
    if ((!canViewOwnerDetails && section == AdminSection.owners) ||
        (!canViewMonthlyReports && section == AdminSection.reports)) {
      section = AdminSection.overview;
      selectedOwner = null;
    }
    if (section == AdminSection.owners && selectedOwner != null) {
      return AdminOwnerDetailPage(
        key: ValueKey(selectedOwner!['id']),
        service: widget.service,
        owner: selectedOwner!,
        onBack: () => setState(() => selectedOwner = null),
        onRecordsChanged: refresh,
        onSaved: (config) {
          final owners = adminMapList(data['owners']);
          final index =
              owners.indexWhere((owner) => owner['id'] == selectedOwner!['id']);
          if (index >= 0) owners[index] = {...owners[index], 'config': config};
          setState(() {
            data['owners'] = owners;
            selectedOwner = {...selectedOwner!, 'config': config};
          });
        },
      );
    }
    return switch (section) {
      AdminSection.overview => AdminOverviewPage(data: data),
      AdminSection.usage =>
        AdminSupabaseUsagePage(usage: adminMap(data['supabaseUsage'])),
      AdminSection.owners => AdminOwnersPage(
          owners: adminMapList(data['owners']),
          onOpenOwner: openOwner,
        ),
      AdminSection.accounts => AdminAccountsPage(
          accounts: adminMapList(data['accounts']),
          canManage: canManageAccounts,
          onSetMembership: (account, tier, billingPeriod) async {
            await widget.service.setMembership(
              userId: '${account['id']}',
              tier: tier,
              billingPeriod: billingPeriod,
            );
            await refresh();
          },
          onEditAccount: (account) async {
            final result = await widget.service.updateAccount(
              userId: '${account['id']}',
              name: '${account['name']}',
              email: '${account['email']}',
              status: '${account['status']}',
            );
            await refresh();
            return adminMap(result['saved']);
          },
          onResetPassword: (account) async {
            await widget.service.sendPasswordReset('${account['id']}');
            if (mounted)
              setState(() =>
                  notice = 'Password-reset email sent to ${account['email']}.');
          },
          onDeleteAccount: (account) async {
            await widget.service.deleteAccount('${account['id']}');
            await refresh();
          },
        ),
      AdminSection.admins => AdminMembersPage(
          members: adminMapList(data['adminMembers']),
          canManage: canManageAdmins,
          onGrant: (name, email) async {
            final result = await widget.service
                .grantAdmin(displayName: name, email: email);
            await refresh();
            return result['invited'] == true;
          },
          onSetAccess: (member, enabled) async {
            await widget.service.setAdminAccess(
              userId: '${member['user_id']}',
              enabled: enabled,
            );
            await refresh();
          },
        ),
      AdminSection.subscriptions => AdminSubscriptionsPage(
          requests: adminMapList(data['subscriptionRequests']),
          onViewSlip: widget.service.subscriptionPaymentUrl,
          onReview: (requestId, decision, notes) async {
            await widget.service.reviewSubscription(
              requestId: requestId,
              decision: decision,
              notes: notes,
            );
            await refresh();
          },
        ),
      AdminSection.requests => AdminRequestsPage(
          requests: adminMapList(data['customizeRequests']),
          onSaved: (requestId, status, notes) async {
            await widget.service.updateCustomizeRequest(
                requestId: requestId, status: status, notes: notes);
            await refresh();
          },
        ),
      AdminSection.issues => AdminIssuesPage(
          issues: adminMapList(data['issueReports']),
          onSaved: (reportId, status, notes) async {
            await widget.service.updateIssueReport(
              reportId: reportId,
              status: status,
              notes: notes,
            );
            await refresh();
          },
        ),
      AdminSection.reports => AdminReportsPage(
          data: data,
          onMonthChanged: (month) => refresh(month: month),
        ),
      AdminSection.api =>
        AdminApiMonitorPage(monitor: adminMap(data['apiMonitor'])),
      AdminSection.audit =>
        AdminAuditPage(logs: adminMapList(data['activityLogs'])),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 920;
      final permissions = adminMap(data['permissions']);
      final canViewOwnerDetails = permissions['canViewOwnerDetails'] == true;
      final canViewMonthlyReports =
          permissions['canViewMonthlyReports'] == true;
      final content = Column(
        children: [
          if (notice != null)
            MaterialBanner(
              content: Text(notice!),
              actions: [
                TextButton(
                    onPressed: () => setState(() => notice = null),
                    child: const Text('Dismiss'))
              ],
            ),
          Expanded(
            child: refreshing
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        desktop ? 28 : 16, 20, desktop ? 28 : 16, 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: page()),
                    ),
                  ),
          ),
        ],
      );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const _AdminLogo(),
          actions: [
            IconButton(
                tooltip: 'Refresh',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Chip(
                  avatar: Icon(Icons.verified_user_outlined,
                      size: 17, color: _adminGreen),
                  label: Text('OTP verified')),
            ),
            IconButton(
                tooltip: 'Sign out',
                onPressed: signOut,
                icon: const Icon(Icons.logout_rounded)),
            const SizedBox(width: 8),
          ],
        ),
        drawer: desktop
            ? null
            : Drawer(
                child: SafeArea(
                    child: _AdminNavigation(
                        section: section,
                        newIssueCount: adminMapList(data['issueReports'])
                            .where((issue) => issue['status'] == 'new')
                            .length,
                        pendingSubscriptionCount:
                            adminMapList(data['subscriptionRequests'])
                                .where((item) =>
                                    item['status'] == 'pending_verification')
                                .length,
                        canViewOwnerDetails: canViewOwnerDetails,
                        canViewMonthlyReports: canViewMonthlyReports,
                        onSelected: (next) {
                          setState(() {
                            section = next;
                            selectedOwner = null;
                          });
                          Navigator.pop(context);
                        }))),
        body: desktop
            ? Row(children: [
                SizedBox(
                    width: 230,
                    child: _AdminNavigation(
                        section: section,
                        newIssueCount: adminMapList(data['issueReports'])
                            .where((issue) => issue['status'] == 'new')
                            .length,
                        pendingSubscriptionCount:
                            adminMapList(data['subscriptionRequests'])
                                .where((item) =>
                                    item['status'] == 'pending_verification')
                                .length,
                        canViewOwnerDetails: canViewOwnerDetails,
                        canViewMonthlyReports: canViewMonthlyReports,
                        onSelected: (next) => setState(() {
                              section = next;
                              selectedOwner = null;
                            }))),
                Expanded(child: content)
              ])
            : content,
      );
    });
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.section,
    required this.newIssueCount,
    required this.pendingSubscriptionCount,
    required this.canViewOwnerDetails,
    required this.canViewMonthlyReports,
    required this.onSelected,
  });
  final AdminSection section;
  final int newIssueCount;
  final int pendingSubscriptionCount;
  final bool canViewOwnerDetails;
  final bool canViewMonthlyReports;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AdminSection.overview, Icons.dashboard_outlined, 'Overview'),
      (AdminSection.usage, Icons.storage_rounded, 'Supabase usage'),
      if (canViewOwnerDetails)
        (AdminSection.owners, Icons.apartment_rounded, 'Owners'),
      (AdminSection.accounts, Icons.groups_2_outlined, 'Accounts'),
      (
        AdminSection.subscriptions,
        Icons.workspace_premium_outlined,
        'Subscriptions'
      ),
      (AdminSection.requests, Icons.inbox_outlined, 'Requests'),
      (AdminSection.issues, Icons.bug_report_outlined, 'App issues'),
      if (canViewMonthlyReports)
        (AdminSection.reports, Icons.analytics_outlined, 'Monthly reports'),
      (AdminSection.api, Icons.monitor_heart_outlined, 'API monitor'),
      (AdminSection.audit, Icons.policy_outlined, 'Access & audit'),
      (
        AdminSection.admins,
        Icons.admin_panel_settings_outlined,
        'Admin members'
      ),
    ];
    return ColoredBox(
      color: _adminNavy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
        children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Text('ADMIN WORKSPACE',
                  style: TextStyle(
                      color: Color(0xFF7F95B3),
                      fontSize: 11,
                      letterSpacing: .8))),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                selected: section == item.$1,
                selectedTileColor: _adminBlue,
                selectedColor: Colors.white,
                textColor: const Color(0xFFC4D2E6),
                iconColor: const Color(0xFF9FB2CB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(item.$2),
                title: Text(item.$3),
                trailing:
                    ((item.$1 == AdminSection.issues && newIssueCount > 0) ||
                            (item.$1 == AdminSection.subscriptions &&
                                pendingSubscriptionCount > 0))
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _adminRed,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${item.$1 == AdminSection.issues ? newIssueCount : pendingSubscriptionCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : null,
                onTap: () => onSelected(item.$1),
              ),
            ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF31435E)),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF65D6BB), size: 18),
              SizedBox(width: 9),
              Expanded(
                  child: Text('Past-month financial records are read-only.',
                      style: TextStyle(
                          color: Color(0xFFAABBD1), fontSize: 12, height: 1.4)))
            ]),
          ),
        ],
      ),
    );
  }
}

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({required this.data, super.key});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final overview = adminMap(data['overview']);
    final roles = adminMap(overview['roleCounts']);
    final registered = adminNumber(overview['registeredUsers']).toInt();
    final roleRows = [
      ('Tenants', adminNumber(roles['tenant']).toInt(), _adminGreen),
      ('Owners', adminNumber(roles['owner']).toInt(), _adminBlue),
      ('Agents', adminNumber(roles['property_agent']).toInt(), _adminOrange),
      (
        'Technicians',
        adminNumber(roles['technician']).toInt(),
        const Color(0xFF7658D6)
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PageHeader(
          title: 'Application overview',
          subtitle: 'Users, visitors, access activity and platform health.'),
      _ResponsiveGrid(minWidth: 230, children: [
        _MetricTile(
            label: 'Registered users',
            value: '$registered',
            detail:
                '${adminNumber(roles['owner']).toInt()} owners · ${adminNumber(roles['tenant']).toInt()} tenants',
            icon: Icons.groups_2_outlined),
        _MetricTile(
            label: 'Unique visitors today',
            value: '${adminNumber(overview['visitorsToday']).toInt()}',
            detail:
                '${adminNumber(overview['pageViewsToday']).toInt()} page views',
            icon: Icons.language_rounded),
        _MetricTile(
            label: 'Active users today',
            value: '${adminNumber(overview['activeUsersToday']).toInt()}',
            detail:
                '${adminNumber(overview['appOpensToday']).toInt()} app opens recorded',
            icon: Icons.online_prediction_rounded),
      ]),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 360, children: [
        _AdminPanel(
            title: 'Users by role',
            trailing: '$registered total',
            child: Column(children: [
              for (final row in roleRows)
                _RoleProgress(
                    label: row.$1,
                    value: row.$2,
                    total: registered,
                    color: row.$3)
            ])),
        _AdminPanel(
            title: 'Traffic collection',
            trailing: 'Today',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${adminNumber(overview['pageViewsToday']).toInt()}',
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _adminNavy)),
              const Text('recorded page views',
                  style: TextStyle(color: _adminMuted)),
              const SizedBox(height: 18),
              const _InfoRow(label: 'Public website', value: 'homeops360.app'),
              _InfoRow(
                  label: 'Last event received',
                  value: _shortDate(overview['lastEventAt'])),
              const _InfoRow(label: 'Source', value: 'HomeOps event collector'),
              const SizedBox(height: 10),
              _TrafficBars(hours: adminMapList(overview['trafficByHour'])),
            ]))
      ]),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 300, children: const [
        _AdminPanel(
            title: 'Authentication & access',
            child: Column(children: [
              _InfoRow(
                  label: 'Admin protection', value: 'Allowlist + email OTP'),
              _InfoRow(label: 'Privileged API', value: 'Server-side only'),
              _InfoRow(label: 'Password resets', value: 'Audited'),
              _InfoRow(label: 'Historical data', value: 'Read-only')
            ])),
        _AdminPanel(
            title: 'Platform health',
            child: Column(children: [
              _InfoRow(
                  label: 'Database',
                  value: 'Supabase connected',
                  positive: true),
              _InfoRow(
                  label: 'Authentication',
                  value: 'Operational',
                  positive: true),
              _InfoRow(
                  label: 'Audit logging', value: 'Enabled', positive: true),
              _InfoRow(
                  label: 'Traffic events', value: 'Enabled', positive: true),
              _InfoRow(label: 'API telemetry', value: 'Enabled', positive: true)
            ])),
      ]),
    ]);
  }
}

class AdminSupabaseUsagePage extends StatelessWidget {
  const AdminSupabaseUsagePage({required this.usage, super.key});

  final Map<String, dynamic> usage;

  @override
  Widget build(BuildContext context) {
    final databaseBytes = adminNumber(usage['databaseBytes']);
    final databaseLimit = adminNumber(usage['databaseLimitBytes']);
    final storageBytes = adminNumber(usage['storageBytes']);
    final storageLimit = adminNumber(usage['storageLimitBytes']);
    final activeUsers = adminNumber(usage['monthlyActiveUsers']);
    final activeUsersLimit = adminNumber(usage['monthlyActiveUsersLimit']);
    final storageObjects = adminNumber(usage['storageObjects']).toInt();
    final projectRef = '${usage['projectRef'] ?? ''}'.trim();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _PageHeader(
        title: 'Supabase usage',
        subtitle:
            'Live project footprint with early warnings before Free Plan limits are reached.',
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBCD6F5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_outlined, color: _adminBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Read-only monitor · ${projectRef.isEmpty ? 'Current Supabase project' : projectRef}. '
              'Warnings appear at 70%, 85% and 95%. No data is deleted automatically.',
              style: const TextStyle(color: _adminNavy, height: 1.45),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 300, children: [
        _UsageMeter(
          title: 'Database size',
          value: _formatBytes(databaseBytes),
          limit: _formatBytes(databaseLimit),
          detail: 'Per-project Free Plan limit',
          icon: Icons.dns_outlined,
          used: databaseBytes,
          capacity: databaseLimit,
        ),
        _UsageMeter(
          title: 'Storage files',
          value: _formatBytes(storageBytes),
          limit: _formatBytes(storageLimit),
          detail: '$storageObjects uploaded objects · organisation-wide limit',
          icon: Icons.folder_copy_outlined,
          used: storageBytes,
          capacity: storageLimit,
        ),
        _UsageMeter(
          title: 'Monthly active users',
          value: activeUsers.toInt().toString(),
          limit: activeUsersLimit.toInt().toString(),
          detail: 'Signed in this month · organisation-wide limit',
          icon: Icons.people_alt_outlined,
          used: activeUsers,
          capacity: activeUsersLimit,
        ),
      ]),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 360, children: [
        _AdminPanel(
          title: 'How to read this monitor',
          child: Column(children: const [
            _InfoRow(label: '0–69%', value: 'Safe', positive: true),
            _InfoRow(label: '70–84%', value: 'Watch closely'),
            _InfoRow(label: '85–94%', value: 'Action required'),
            _InfoRow(label: '95%+', value: 'Critical'),
          ]),
        ),
        _AdminPanel(
          title: 'Billing-scope reminder',
          child: const Text(
            'Database size is measured per project. Storage, monthly active users, egress and Edge Function invocations are billed across the whole Supabase organisation. This page shows the current project only; use the Supabase organisation Usage page for the combined production and development totals.',
            style: TextStyle(color: _adminMuted, height: 1.55),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      _AdminPanel(
        title: 'Not estimated inside the app',
        child: const Text(
          'Egress and Edge Function invocation billing totals are intentionally not estimated from application logs because that can under-count real Supabase usage. Their authoritative values remain in Supabase Dashboard → Organisation → Usage.',
          style: TextStyle(color: _adminMuted, height: 1.55),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Last measured ${_shortDate(usage['measuredAt'])}',
        style: const TextStyle(color: _adminMuted, fontSize: 12),
      ),
    ]);
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({
    required this.title,
    required this.value,
    required this.limit,
    required this.detail,
    required this.icon,
    required this.used,
    required this.capacity,
  });

  final String title;
  final String value;
  final String limit;
  final String detail;
  final IconData icon;
  final num used;
  final num capacity;

  @override
  Widget build(BuildContext context) {
    final ratio = capacity <= 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0);
    final percent = capacity <= 0 ? 0.0 : used / capacity * 100;
    final color = percent >= 95
        ? _adminRed
        : percent >= 85
            ? _adminOrange
            : percent >= 70
                ? const Color(0xFFD6A414)
                : _adminGreen;
    final status = percent >= 95
        ? 'Critical'
        : percent >= 85
            ? 'Action required'
            : percent >= 70
                ? 'Watch'
                : 'Safe';
    return _AdminPanel(
      title: title,
      trailing: status,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _adminNavy)),
              Text('of $limit',
                  style: const TextStyle(color: _adminMuted, fontSize: 12)),
            ]),
          ),
          Text('${percent.toStringAsFixed(percent < 1 ? 2 : 1)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 15),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 9,
          borderRadius: BorderRadius.circular(20),
          color: color,
          backgroundColor: const Color(0xFFE4EAF2),
        ),
        const SizedBox(height: 10),
        Text(detail,
            style:
                const TextStyle(color: _adminMuted, fontSize: 12, height: 1.4)),
      ]),
    );
  }
}

String _formatBytes(num bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${bytes.toInt()} B';
}

class AdminOwnersPage extends StatefulWidget {
  const AdminOwnersPage(
      {required this.owners, required this.onOpenOwner, super.key});
  final List<Map<String, dynamic>> owners;
  final ValueChanged<Map<String, dynamic>> onOpenOwner;
  @override
  State<AdminOwnersPage> createState() => _AdminOwnersPageState();
}

class _AdminOwnersPageState extends State<AdminOwnersPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final owners = widget.owners
        .where((owner) => '${owner['name']} ${owner['email']}'
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PageHeader(
          title: 'Owner workspace',
          subtitle:
              '${widget.owners.length} owner accounts. Select one to manage limits, feature access and account security.'),
      ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search owner or email'),
              onChanged: (value) => setState(() => query = value))),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 320, children: [
        for (final owner in owners)
          _OwnerCard(owner: owner, onOpen: () => widget.onOpenOwner(owner))
      ]),
      if (owners.isEmpty)
        const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: Text('No owners match this search.'))),
    ]);
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner, required this.onOpen});
  final Map<String, dynamic> owner;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final config = adminMap(owner['config']);
    final invoices = adminNumber(owner['invoices']).toInt();
    final complete = adminNumber(owner['completeBills']).toInt();
    final progress = invoices == 0 ? 0.0 : complete / invoices;
    final rate = owner['collectionRate'];
    final membership =
        '${owner['membership'] ?? config['membership_tier'] ?? 'free'}';
    final unlimited =
        membership == 'diamond' || config['unlimited_access'] == true;
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDDE5EF))),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                backgroundColor: const Color(0xFFDDEEFF),
                foregroundColor: _adminBlue,
                child: Text(_initials('${owner['name']}'))),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${owner['name']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: _adminNavy)),
                  Text('${owner['email']}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _adminMuted, fontSize: 12))
                ])),
            _MembershipBadge(tier: membership),
            const SizedBox(width: 7),
            const _StatusBadge(label: 'Active', color: _adminGreen)
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _MiniValue(
                    value: unlimited
                        ? '${owner['properties']} / Unlimited'
                        : '${owner['properties']} / ${config['property_limit'] ?? 1}',
                    label: 'Properties')),
            const SizedBox(width: 7),
            Expanded(
                child: _MiniValue(
                    value: unlimited
                        ? '${owner['tenants']} / Unlimited'
                        : '${owner['tenants']} / ${config['tenant_limit'] ?? 2}',
                    label: 'Tenants')),
            const SizedBox(width: 7),
            Expanded(
                child: _MiniValue(
                    value: unlimited
                        ? 'Unlimited'
                        : '${config['explore_listing_limit'] ?? 0}',
                    label: 'Listings limit'))
          ]),
          const SizedBox(height: 15),
          Row(children: [
            const Text('Monthly bills', style: TextStyle(color: _adminMuted)),
            const Spacer(),
            Text('$complete of $invoices approved',
                style: const TextStyle(fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 7),
          LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: const Color(0xFFE8EDF4),
              color: owner['reviewBills'] == 0 ? _adminGreen : _adminOrange),
          const SizedBox(height: 9),
          Text(
              rate == null
                  ? 'No invoices this month'
                  : '${adminNumber(rate).toStringAsFixed(1)}% collected · ${owner['reviewBills']} awaiting review',
              style: const TextStyle(color: _adminMuted, fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Text('Last login ${_shortDate(owner['lastLoginAt'])}',
                    style: const TextStyle(color: _adminMuted, fontSize: 12))),
            OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('View owner'))
          ]),
        ]),
      ),
    );
  }
}

class AdminOwnerDetailPage extends StatefulWidget {
  const AdminOwnerDetailPage(
      {required this.service,
      required this.owner,
      required this.onBack,
      required this.onRecordsChanged,
      required this.onSaved,
      super.key});
  final AdminPortalService service;
  final Map<String, dynamic> owner;
  final VoidCallback onBack;
  final Future<void> Function({DateTime? month}) onRecordsChanged;
  final ValueChanged<Map<String, dynamic>> onSaved;
  @override
  State<AdminOwnerDetailPage> createState() => _AdminOwnerDetailPageState();
}

class _AdminOwnerDetailPageState extends State<AdminOwnerDetailPage> {
  late final TextEditingController propertyLimit;
  late final TextEditingController tenantLimit;
  late final TextEditingController listingLimit;
  late bool tariff;
  late bool promotion;
  late bool export;
  late bool hardware;
  bool saving = false;
  String? message;

  bool get isDiamond => widget.owner['membership'] == 'diamond';

  @override
  void initState() {
    super.initState();
    final config = adminMap(widget.owner['config']);
    propertyLimit =
        TextEditingController(text: '${config['property_limit'] ?? 5}');
    tenantLimit =
        TextEditingController(text: '${config['tenant_limit'] ?? 15}');
    listingLimit =
        TextEditingController(text: '${config['explore_listing_limit'] ?? 10}');
    tariff = config['electricity_tariff_enabled'] != false;
    promotion = config['explore_promotion_enabled'] != false;
    export = config['advanced_export_enabled'] == true;
    hardware = config['meter_hardware_enabled'] == true;
  }

  @override
  void dispose() {
    propertyLimit.dispose();
    tenantLimit.dispose();
    listingLimit.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final values = [
      int.tryParse(propertyLimit.text),
      int.tryParse(tenantLimit.text),
      int.tryParse(listingLimit.text)
    ];
    if (values.any((value) => value == null || value < 0)) {
      setState(() => message = 'Enter valid non-negative limits.');
      return;
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      final result = await widget.service.updateOwnerConfig(
          ownerId: '${widget.owner['id']}',
          propertyLimit: values[0]!,
          tenantLimit: values[1]!,
          exploreListingLimit: values[2]!,
          electricityTariffEnabled: tariff,
          explorePromotionEnabled: promotion,
          advancedExportEnabled: export,
          meterHardwareEnabled: hardware);
      final config = adminMap(result['config']);
      widget.onSaved(config);
      if (mounted)
        setState(() => message = 'Current and future access settings saved.');
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> resetPassword() async {
    try {
      await widget.service.sendPasswordReset('${widget.owner['id']}');
      if (mounted)
        setState(() =>
            message = 'Password-reset email sent to ${widget.owner['email']}.');
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('All owners')),
      _PageHeader(
          title: '${widget.owner['name']}',
          subtitle:
              '${widget.owner['email']} · last login ${_shortDate(widget.owner['lastLoginAt'])}',
          actions: [
            OutlinedButton.icon(
                onPressed: resetPassword,
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Send password reset')),
            FilledButton.icon(
                onPressed: saving || isDiamond ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save settings'))
          ]),
      if (message != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message!,
                style: TextStyle(
                    color:
                        message!.contains('saved') || message!.contains('sent')
                            ? _adminGreen
                            : _adminRed))),
      _ResponsiveGrid(minWidth: 215, children: [
        _MetricTile(
            label: 'Properties',
            value: '${widget.owner['properties']}',
            detail:
                isDiamond ? 'Unlimited' : 'of ${propertyLimit.text} allowed',
            icon: Icons.apartment_rounded),
        _MetricTile(
            label: 'Tenants',
            value: '${widget.owner['tenants']}',
            detail: isDiamond ? 'Unlimited' : 'of ${tenantLimit.text} allowed',
            icon: Icons.groups_rounded),
        _MetricTile(
            label: 'Collection rate',
            value: widget.owner['collectionRate'] == null
                ? '—'
                : '${adminNumber(widget.owner['collectionRate']).toStringAsFixed(1)}%',
            detail: '${widget.owner['completeBills']} approved invoices',
            icon: Icons.payments_outlined)
      ]),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 370, children: [
        _AdminPanel(
            title: 'Account limits',
            trailing: 'Effective this month',
            child: Column(children: [
              _LimitField(
                  label: 'Property creation limit',
                  controller: propertyLimit,
                  enabled: !isDiamond),
              _LimitField(
                  label: 'Tenant registration limit',
                  controller: tenantLimit,
                  enabled: !isDiamond),
              _LimitField(
                  label: 'Explore listing limit',
                  controller: listingLimit,
                  enabled: !isDiamond)
            ])),
        _AdminPanel(
            title: 'Owner feature access',
            child: Column(children: [
              _FeatureSwitch(
                  title: 'Electricity tariff configuration',
                  subtitle: 'Owner may change tariff tiers',
                  value: tariff,
                  onChanged: isDiamond
                      ? null
                      : (value) => setState(() => tariff = value)),
              _FeatureSwitch(
                  title: 'Explore property promotion',
                  subtitle: 'Publish and promote available rooms',
                  value: promotion,
                  onChanged: isDiamond
                      ? null
                      : (value) => setState(() => promotion = value)),
              _FeatureSwitch(
                  title: 'Advanced Excel / SQLite export',
                  subtitle: 'Export owner portfolio records',
                  value: export,
                  onChanged: isDiamond
                      ? null
                      : (value) => setState(() => export = value))
            ])),
      ]),
      const SizedBox(height: 14),
      _OwnerOperationalRecords(
        owner: widget.owner,
        service: widget.service,
        onChanged: () => widget.onRecordsChanged(),
      ),
      const SizedBox(height: 14),
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF0F3F7),
              borderRadius: BorderRadius.circular(14)),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_clock_outlined, color: _adminMuted),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Historical lock: past-month bills, payments, tariffs and financial values can be viewed and reported but are not editable from this portal. Configuration changes apply from the current month onward.',
                        style: TextStyle(color: _adminMuted, height: 1.45)))
              ])),
    ]);
  }
}

class _OwnerOperationalRecords extends StatefulWidget {
  const _OwnerOperationalRecords(
      {required this.owner, required this.service, required this.onChanged});

  final Map<String, dynamic> owner;
  final AdminPortalService service;
  final Future<void> Function() onChanged;

  @override
  State<_OwnerOperationalRecords> createState() =>
      _OwnerOperationalRecordsState();
}

class _OwnerOperationalRecordsState extends State<_OwnerOperationalRecords> {
  String? busyId;

  Future<void> editRecord(String type, Map<String, dynamic> record) async {
    final fields = <String, TextEditingController>{};
    TextEditingController field(String key) => fields.putIfAbsent(
        key, () => TextEditingController(text: '${record[key] ?? ''}'));
    var propertyStatus = '${record['status'] ?? 'ready'}';
    var tenantActive = record['status'] != 'inactive';
    var billStatus = '${record['status'] ?? 'pending'}';
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final controls = <Widget>[];
        if (type == 'property') {
          controls.addAll([
            TextField(
                controller: field('name'),
                decoration: const InputDecoration(labelText: 'Property name')),
            TextField(
                controller: field('addressLine'),
                decoration: const InputDecoration(labelText: 'Address')),
            TextField(
                controller: field('postcode'),
                decoration: const InputDecoration(labelText: 'Postcode')),
            TextField(
                controller: field('city'),
                decoration: const InputDecoration(labelText: 'City')),
            TextField(
                controller: field('state'),
                decoration: const InputDecoration(labelText: 'State')),
            DropdownButtonFormField<String>(
              value: propertyStatus,
              decoration: const InputDecoration(labelText: 'Property status'),
              items: const [
                DropdownMenuItem(value: 'ready', child: Text('Ready')),
                DropdownMenuItem(
                    value: 'developing', child: Text('Developing')),
                DropdownMenuItem(value: 'sold', child: Text('Sold')),
              ],
              onChanged: (value) => setDialogState(
                  () => propertyStatus = value ?? propertyStatus),
            ),
          ]);
        } else if (type == 'tenant') {
          controls.addAll([
            TextField(
                controller: field('name'),
                decoration: const InputDecoration(labelText: 'Tenant name')),
            TextField(
                controller: field('email'),
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: field('phoneNumber'),
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: field('unit'),
                decoration: const InputDecoration(labelText: 'Unit')),
            TextField(
                controller: field('rent'),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly rent')),
            TextField(
                controller: field('leaseStart'),
                decoration: const InputDecoration(
                    labelText: 'Lease start (YYYY-MM-DD)')),
            TextField(
                controller: field('leaseEnd'),
                decoration:
                    const InputDecoration(labelText: 'Lease end (YYYY-MM-DD)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active tenancy'),
              value: tenantActive,
              onChanged: (value) => setDialogState(() => tenantActive = value),
            ),
          ]);
        } else {
          for (final item in const [
            ('rentAmount', 'Rent'),
            ('electricityAmount', 'Electricity'),
            ('generalElectricAmount', 'General electricity'),
            ('waterAmount', 'Water'),
            ('internetAmount', 'Internet'),
            ('parkingRentalAmount', 'Parking'),
            ('paid', 'Amount paid'),
          ]) {
            controls.add(TextField(
              controller: field(item.$1),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: item.$2),
            ));
          }
          controls.addAll([
            TextField(
                controller: field('paymentReference'),
                decoration:
                    const InputDecoration(labelText: 'Payment reference')),
            DropdownButtonFormField<String>(
              value: billStatus,
              decoration: const InputDecoration(labelText: 'Payment status'),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(
                    value: 'pendingApproval', child: Text('Pending approval')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) =>
                  setDialogState(() => billStatus = value ?? billStatus),
            ),
          ]);
        }
        return AlertDialog(
          title: Text(
              'Edit current ${type == 'tenant' ? 'tenant agreement' : type}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (type == 'bill')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                        'Only the current month can be edited. Previous months remain locked.',
                        style: TextStyle(color: _adminMuted)),
                  ),
                for (var index = 0; index < controls.length; index++) ...[
                  controls[index],
                  if (index < controls.length - 1) const SizedBox(height: 11),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Map<String, dynamic> output;
                if (type == 'property') {
                  output = {
                    for (final entry in fields.entries)
                      entry.key: entry.value.text.trim(),
                    'status': propertyStatus
                  };
                } else if (type == 'tenant') {
                  output = {
                    'name': field('name').text.trim(),
                    'email': field('email').text.trim(),
                    'phoneNumber': field('phoneNumber').text.trim(),
                    'unitName': field('unit').text.trim(),
                    'monthlyRent': field('rent').text.trim(),
                    'leaseStart': field('leaseStart').text.trim(),
                    'leaseEnd': field('leaseEnd').text.trim(),
                    'active': tenantActive,
                  };
                } else {
                  output = {
                    for (final entry in fields.entries)
                      (entry.key == 'paid' ? 'amountPaid' : entry.key):
                          entry.value.text.trim(),
                    'status': billStatus,
                  };
                }
                Navigator.pop(context, output);
              },
              child: const Text('Save current record'),
            ),
          ],
        );
      }),
    );
    for (final controller in fields.values) {
      controller.dispose();
    }
    if (saved == null) return;
    setState(() => busyId = '${record['id']}');
    try {
      await widget.service.updateWorkspaceRecord(
        ownerId: '${widget.owner['id']}',
        recordType: type,
        recordId: '${record['id']}',
        fields: saved,
      );
      await widget.onChanged();
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = adminMapList(widget.owner['propertyRecords']);
    final tenants = adminMapList(widget.owner['tenantRecords']);
    final bills = adminMapList(widget.owner['billRecords']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _AdminPanel(
        title: 'Property performance',
        trailing: '${properties.length} properties',
        child: properties.isEmpty
            ? const Text('No property records are available.',
                style: TextStyle(color: _adminMuted))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(columns: const [
                  DataColumn(label: Text('Property')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Invoices')),
                  DataColumn(label: Text('Billed')),
                  DataColumn(label: Text('Collected')),
                  DataColumn(label: Text('Action')),
                ], rows: [
                  for (final property in properties)
                    DataRow(cells: [
                      DataCell(SizedBox(
                          width: 290,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${property['name']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text('${property['address']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _adminMuted, fontSize: 12)),
                              ]))),
                      DataCell(Text('${property['status']}')),
                      DataCell(Text('${property['invoices']}')),
                      DataCell(Text(_money(property['billed']))),
                      DataCell(Text(_money(property['collected']))),
                      DataCell(IconButton(
                        tooltip: 'Edit current property details',
                        onPressed: busyId == property['id']
                            ? null
                            : () => editRecord('property', property),
                        icon: const Icon(Icons.edit_outlined),
                      )),
                    ]),
                ]),
              ),
      ),
      const SizedBox(height: 14),
      _ResponsiveGrid(minWidth: 480, children: [
        _AdminPanel(
          title: 'Tenant agreements',
          trailing: '${tenants.length} records',
          child: tenants.isEmpty
              ? const Text('No active tenant agreements.',
                  style: TextStyle(color: _adminMuted))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(columns: const [
                    DataColumn(label: Text('Tenant')),
                    DataColumn(label: Text('Property / unit')),
                    DataColumn(label: Text('Rent')),
                    DataColumn(label: Text('Lease ends')),
                    DataColumn(label: Text('Action')),
                  ], rows: [
                    for (final tenant in tenants)
                      DataRow(cells: [
                        DataCell(SizedBox(
                            width: 170,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${tenant['name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text('${tenant['email']}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _adminMuted, fontSize: 12)),
                                ]))),
                        DataCell(
                            Text('${tenant['property']} · ${tenant['unit']}')),
                        DataCell(Text(_money(tenant['rent']))),
                        DataCell(Text(_shortDate(tenant['leaseEnd']))),
                        DataCell(IconButton(
                          tooltip: 'Edit current tenant agreement',
                          onPressed: busyId == tenant['id']
                              ? null
                              : () => editRecord('tenant', tenant),
                          icon: const Icon(Icons.edit_outlined),
                        )),
                      ]),
                  ]),
                ),
        ),
        _AdminPanel(
          title: 'Payment records',
          trailing: '${bills.length} this month',
          child: bills.isEmpty
              ? const Text('No bills exist for the selected month.',
                  style: TextStyle(color: _adminMuted))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(columns: const [
                    DataColumn(label: Text('Tenant / property')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Paid')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ], rows: [
                    for (final bill in bills)
                      DataRow(cells: [
                        DataCell(SizedBox(
                            width: 190,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${bill['tenant']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text('${bill['property']}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _adminMuted, fontSize: 12)),
                                ]))),
                        DataCell(Text(_money(bill['total']))),
                        DataCell(Text(_money(bill['paid']))),
                        DataCell(Text('${bill['status']}')),
                        DataCell(IconButton(
                          tooltip: bill['editable'] == true
                              ? 'Edit current-month payment record'
                              : 'Past-month records are locked',
                          onPressed:
                              bill['editable'] == true && busyId != bill['id']
                                  ? () => editRecord('bill', bill)
                                  : null,
                          icon: Icon(bill['editable'] == true
                              ? Icons.edit_outlined
                              : Icons.lock_outline_rounded),
                        )),
                      ]),
                  ]),
                ),
        ),
      ]),
    ]);
  }
}

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage(
      {required this.accounts,
      required this.canManage,
      required this.onResetPassword,
      required this.onEditAccount,
      required this.onSetMembership,
      required this.onDeleteAccount,
      super.key});
  final List<Map<String, dynamic>> accounts;
  final bool canManage;
  final Future<void> Function(Map<String, dynamic>) onResetPassword;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
      onEditAccount;
  final Future<void> Function(
      Map<String, dynamic>, String tier, String billingPeriod) onSetMembership;
  final Future<void> Function(Map<String, dynamic>) onDeleteAccount;
  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  String query = '';
  String role = 'all';
  String? busyId;
  final ScrollController horizontalScrollController = ScrollController();

  @override
  void dispose() {
    horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> editAccount(Map<String, dynamic> account) async {
    final protected = account['membership'] == 'diamond';
    final name = TextEditingController(text: '${account['name']}');
    final email = TextEditingController(text: '${account['email']}');
    var status = '${account['status']}';
    var membership = '${account['membership'] ?? ''}';
    var billingPeriod = 'monthly';
    final membershipApplicable = account['membership'] != null;
    final changed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Edit account'),
          content: SizedBox(
            width: 430,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(
                  controller: email,
                  decoration:
                      const InputDecoration(labelText: 'Email address')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Account status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                      value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: protected
                    ? null
                    : (value) => setDialogState(() => status = value ?? status),
              ),
              if (protected) ...[
                const SizedBox(height: 12),
                const Text(
                  'Diamond founder access is permanent. This account cannot be suspended, removed or downgraded.',
                  style: TextStyle(color: Color(0xFF6D28D9)),
                ),
              ],
              if (membershipApplicable && !protected) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: membership,
                  decoration: const InputDecoration(labelText: 'Membership'),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'premium', child: Text('Premium')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => membership = value ?? membership),
                ),
                if (membership == 'premium') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: billingPeriod,
                    decoration:
                        const InputDecoration(labelText: 'Premium period'),
                    items: const [
                      DropdownMenuItem(
                          value: 'monthly', child: Text('1 month')),
                      DropdownMenuItem(
                          value: 'annual', child: Text('12 months')),
                    ],
                    onChanged: (value) => setDialogState(
                        () => billingPeriod = value ?? billingPeriod),
                  ),
                ],
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                ...account,
                'name': name.text.trim(),
                'email': email.text.trim(),
                'status': status,
                'membership': membership,
                'billingPeriod': billingPeriod,
              }),
              child: const Text('Save current details'),
            ),
          ],
        );
      }),
    );
    name.dispose();
    email.dispose();
    if (changed == null) return;
    setState(() => busyId = '${account['id']}');
    try {
      await widget.onEditAccount(changed);
      if (membershipApplicable &&
          !protected &&
          changed['membership'] != account['membership']) {
        await widget.onSetMembership(
          account,
          '${changed['membership']}',
          '${changed['billingPeriod']}',
        );
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> deleteAccount(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove_rounded, color: _adminRed),
        title: Text('Delete ${account['name']}?'),
        content: const Text(
          'This permanently removes login access and hides the account from the directory. Historical property, billing, payment and audit records will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _adminRed),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busyId = '${account['id']}');
    try {
      await widget.onDeleteAccount(account);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${account['name']} account deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts.where((account) {
      final matchesQuery = '${account['name']} ${account['email']}'
          .toLowerCase()
          .contains(query.toLowerCase());
      return matchesQuery && (role == 'all' || account['role'] == role);
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PageHeader(
          title: 'Accounts & access',
          subtitle:
              '${widget.accounts.length} owners, tenants, agents and technicians.'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
            width: 360,
            child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search name or email'),
                onChanged: (value) => setState(() => query = value))),
        SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
                value: role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All roles')),
                  DropdownMenuItem(value: 'owner', child: Text('Owners')),
                  DropdownMenuItem(value: 'tenant', child: Text('Tenants')),
                  DropdownMenuItem(
                      value: 'property_agent', child: Text('Agents')),
                  DropdownMenuItem(
                      value: 'technician', child: Text('Technicians'))
                ],
                onChanged: (value) => setState(() => role = value ?? 'all')))
      ]),
      const SizedBox(height: 14),
      _AdminPanel(
          title: 'User directory',
          child: Scrollbar(
              controller: horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                  controller: horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DataTable(columns: const [
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Membership')),
                    DataColumn(label: Text('Subscription status')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Last login')),
                    DataColumn(label: Text('Email verified')),
                    DataColumn(label: Text('Action'))
                  ], rows: [
                    for (final account in accounts)
                      DataRow(cells: [
                        DataCell(SizedBox(
                            width: 220,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${account['name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text('${account['email']}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _adminMuted, fontSize: 12))
                                ]))),
                        DataCell(Text(_roleLabel('${account['role']}'))),
                        DataCell(account['membership'] == null
                            ? const Text('—')
                            : _MembershipBadge(
                                tier: '${account['membership']}')),
                        DataCell(Text(account['subscriptionStatus'] == null
                            ? 'Not applicable'
                            : _subscriptionStatusLabel(
                                '${account['subscriptionStatus']}'))),
                        DataCell(_StatusBadge(
                            label: '${account['status']}',
                            color: account['status'] == 'active'
                                ? _adminGreen
                                : _adminRed)),
                        DataCell(Text(_shortDate(account['lastLoginAt']))),
                        DataCell(Icon(
                            account['emailConfirmedAt'] == null
                                ? Icons.error_outline_rounded
                                : Icons.verified_rounded,
                            color: account['emailConfirmedAt'] == null
                                ? _adminOrange
                                : _adminGreen)),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!widget.canManage)
                            const Text('Founder only',
                                style: TextStyle(
                                    color: _adminMuted, fontSize: 12)),
                          if (widget.canManage) ...[
                            TextButton.icon(
                                onPressed: busyId == account['id']
                                    ? null
                                    : () => editAccount(account),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit')),
                            TextButton.icon(
                                onPressed: busyId == account['id']
                                    ? null
                                    : () async {
                                        setState(
                                            () => busyId = '${account['id']}');
                                        try {
                                          await widget.onResetPassword(account);
                                        } finally {
                                          if (mounted) {
                                            setState(() => busyId = null);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.lock_reset_rounded,
                                    size: 18),
                                label: const Text('Reset')),
                            if (account['membership'] != 'diamond')
                              TextButton.icon(
                                  style: TextButton.styleFrom(
                                      foregroundColor: _adminRed),
                                  onPressed: busyId == account['id']
                                      ? null
                                      : () => deleteAccount(account),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18),
                                  label: const Text('Delete')),
                          ],
                        ]))
                      ]),
                  ])))),
    ]);
  }
}

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({
    required this.requests,
    required this.onViewSlip,
    required this.onReview,
    super.key,
  });

  final List<Map<String, dynamic>> requests;
  final Future<String> Function(String requestId) onViewSlip;
  final Future<void> Function(String requestId, String decision, String notes)
      onReview;

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  String filter = 'all';
  String query = '';
  String? busyId;

  Future<void> viewSlip(Map<String, dynamic> request) async {
    setState(() => busyId = '${request['id']}');
    try {
      final url = await widget.onViewSlip('${request['id']}');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> review(Map<String, dynamic> request, String decision) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision == 'approved'
            ? 'Approve Premium subscription?'
            : 'Reject subscription request?'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '${request['userName']} · ${request['userEmail']}\n'
              '${request['billing_period'] == 'annual' ? '12 months' : '1 month'} · RM ${adminNumber(request['amount']).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Admin notes'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: decision == 'rejected'
                ? FilledButton.styleFrom(backgroundColor: _adminRed)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(decision == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      notes.dispose();
      return;
    }
    setState(() => busyId = '${request['id']}');
    try {
      await widget.onReview('${request['id']}', decision, notes.text.trim());
    } finally {
      notes.dispose();
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.requests.where((item) {
      final statusMatches = filter == 'all' || item['status'] == filter;
      final text =
          '${item['userName']} ${item['userEmail']} ${item['userRole']}'
              .toLowerCase();
      return statusMatches && text.contains(query.toLowerCase());
    }).toList();
    final pending = widget.requests
        .where((item) => item['status'] == 'pending_verification')
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PageHeader(
        title: 'Subscriptions',
        subtitle:
            '$pending pending verification · Manual payment review for owners, agents and technicians.',
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
          width: 360,
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search name or email',
            ),
            onChanged: (value) => setState(() => query = value),
          ),
        ),
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            value: filter,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All statuses')),
              DropdownMenuItem(
                  value: 'pending_verification',
                  child: Text('Pending verification')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (value) => setState(() => filter = value ?? 'all'),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      _AdminPanel(
        title: 'Payment verification records',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Subscriber')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Submitted')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final request in visible)
                DataRow(cells: [
                  DataCell(SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${request['userName']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${request['userEmail']}',
                            style: const TextStyle(
                                color: _adminMuted, fontSize: 12)),
                      ],
                    ),
                  )),
                  DataCell(Text(_roleLabel('${request['userRole']}'))),
                  DataCell(Text(request['billing_period'] == 'annual'
                      ? 'Premium · 12 months'
                      : 'Premium · 1 month')),
                  DataCell(Text(
                      'RM ${adminNumber(request['amount']).toStringAsFixed(2)}')),
                  DataCell(_StatusBadge(
                    label: '${request['status']}'.replaceAll('_', ' '),
                    color: request['status'] == 'approved'
                        ? _adminGreen
                        : request['status'] == 'rejected'
                            ? _adminRed
                            : _adminOrange,
                  )),
                  DataCell(Text(_shortDate(request['submitted_at']))),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton.icon(
                      onPressed: busyId == request['id']
                          ? null
                          : () => viewSlip(request),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('View slip'),
                    ),
                    if (request['status'] == 'pending_verification') ...[
                      TextButton(
                        onPressed: busyId == request['id']
                            ? null
                            : () => review(request, 'approved'),
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed: busyId == request['id']
                            ? null
                            : () => review(request, 'rejected'),
                        child: const Text('Reject',
                            style: TextStyle(color: _adminRed)),
                      ),
                    ],
                  ])),
                ]),
            ],
          ),
        ),
      ),
    ]);
  }
}

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage(
      {required this.requests, required this.onSaved, super.key});
  final List<Map<String, dynamic>> requests;
  final Future<void> Function(String requestId, String status, String notes)
      onSaved;
  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  String filter = 'all';
  String query = '';
  String? busyId;

  Future<void> manage(Map<String, dynamic> request) async {
    var status = '${request['status'] ?? 'new'}';
    final notes =
        TextEditingController(text: '${request['admin_notes'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: Text('${request['name']}'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              '${request['phone']} · ${request['company'] ?? ''}',
                              style: const TextStyle(color: _adminMuted)),
                          const SizedBox(height: 12),
                          Text('${request['message']}',
                              style: const TextStyle(height: 1.45)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(
                                labelText: 'Request status'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'new', child: Text('New')),
                              DropdownMenuItem(
                                  value: 'contacted', child: Text('Contacted')),
                              DropdownMenuItem(
                                  value: 'closed', child: Text('Closed')),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => status = value ?? status),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                              controller: notes,
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                  labelText: 'Admin notes')),
                        ]),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save')),
                ],
              )),
    );
    if (save != true) {
      notes.dispose();
      return;
    }
    setState(() => busyId = '${request['id']}');
    try {
      await widget.onSaved('${request['id']}', status, notes.text.trim());
    } finally {
      notes.dispose();
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.requests.where((request) {
      final matchesStatus = filter == 'all' || request['status'] == filter;
      final haystack =
          '${request['name']} ${request['company']} ${request['phone']} ${request['message']}'
              .toLowerCase();
      return matchesStatus && haystack.contains(query.toLowerCase());
    }).toList();
    final newCount =
        widget.requests.where((request) => request['status'] == 'new').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PageHeader(
          title: 'Customization requests',
          subtitle:
              '$newCount new · ${widget.requests.length} total inquiries submitted from /customize/.'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search requester, phone or requirement'),
              onChanged: (value) => setState(() => query = value),
            )),
        SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: filter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All requests')),
                DropdownMenuItem(value: 'new', child: Text('New')),
                DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) => setState(() => filter = value ?? 'all'),
            )),
      ]),
      const SizedBox(height: 14),
      if (visible.isEmpty)
        const _AdminPanel(
            title: 'Inquiry inbox',
            child: Text('No matching customization requests.',
                style: TextStyle(color: _adminMuted)))
      else
        _ResponsiveGrid(minWidth: 360, children: [
          for (final request in visible)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: const BorderSide(color: Color(0xFFDDE5EF))),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('${request['name']}',
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800))),
                        _StatusBadge(
                          label: '${request['status']}',
                          color: request['status'] == 'new'
                              ? _adminBlue
                              : request['status'] == 'contacted'
                                  ? _adminOrange
                                  : _adminGreen,
                        ),
                      ]),
                      const SizedBox(height: 7),
                      Text(
                          '${request['phone']} · ${request['property_count']} properties',
                          style: const TextStyle(color: _adminMuted)),
                      Text('${request['interest']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text('${request['message']}',
                          maxLines: 4, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: Text(_shortDate(request['created_at']),
                                style: const TextStyle(
                                    color: _adminMuted, fontSize: 12))),
                        FilledButton.icon(
                          onPressed: busyId == request['id']
                              ? null
                              : () => manage(request),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Manage'),
                        ),
                      ]),
                    ]),
              ),
            ),
        ]),
    ]);
  }
}

class AdminIssuesPage extends StatefulWidget {
  const AdminIssuesPage({
    required this.issues,
    required this.onSaved,
    super.key,
  });

  final List<Map<String, dynamic>> issues;
  final Future<void> Function(String reportId, String status, String notes)
      onSaved;

  @override
  State<AdminIssuesPage> createState() => _AdminIssuesPageState();
}

class _AdminIssuesPageState extends State<AdminIssuesPage> {
  String filter = 'all';
  String query = '';
  String? busyId;

  Color issueColor(String value) => switch (value) {
        'critical' => _adminRed,
        'high' => _adminOrange,
        'resolved' || 'closed' => _adminGreen,
        _ => _adminBlue,
      };

  String readable(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> manage(Map<String, dynamic> issue) async {
    var status = '${issue['status'] ?? 'new'}';
    final notes = TextEditingController(text: '${issue['admin_notes'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${issue['title']}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${issue['reporter_name']} · ${issue['reporter_email']}',
                    style: const TextStyle(color: _adminMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${readable('${issue['reporter_role']}')} · ${readable('${issue['category']}')} · ${readable('${issue['severity']}')}',
                    style: const TextStyle(
                      color: _adminMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '${issue['description']}',
                    style: const TextStyle(height: 1.45),
                  ),
                  if ('${issue['attachment_name'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${issue['attachment_name']}')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration:
                        const InputDecoration(labelText: 'Issue status'),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(
                          value: 'investigating', child: Text('Investigating')),
                      DropdownMenuItem(
                          value: 'resolved', child: Text('Resolved')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? status),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    minLines: 3,
                    maxLines: 7,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Reply / admin notes',
                      helperText:
                          'This reply is visible to the reporting user.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save & notify user'),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      notes.dispose();
      return;
    }
    setState(() => busyId = '${issue['id']}');
    try {
      await widget.onSaved('${issue['id']}', status, notes.text.trim());
    } finally {
      notes.dispose();
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.issues.where((issue) {
      final statusMatches = filter == 'all' || issue['status'] == filter;
      final haystack =
          '${issue['title']} ${issue['description']} ${issue['reporter_name']} ${issue['reporter_email']} ${issue['category']}'
              .toLowerCase();
      return statusMatches && haystack.contains(query.toLowerCase());
    }).toList();
    final newCount =
        widget.issues.where((issue) => issue['status'] == 'new').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Application issue inbox',
          subtitle:
              '$newCount new · ${widget.issues.length} total reports from owners, agents and tenants.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 380,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search reporter, title or description',
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                value: filter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All issues')),
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(
                      value: 'investigating', child: Text('Investigating')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (value) => setState(() => filter = value ?? 'all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const _AdminPanel(
            title: 'Issue reports',
            child: Text(
              'No matching application issues.',
              style: TextStyle(color: _adminMuted),
            ),
          )
        else
          _ResponsiveGrid(
            minWidth: 370,
            children: [
              for (final issue in visible)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                    side: const BorderSide(color: Color(0xFFDDE5EF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${issue['title']}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StatusBadge(
                              label: readable('${issue['status']}'),
                              color: issueColor('${issue['status']}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${issue['reporter_name']} · ${readable('${issue['reporter_role']}')}',
                          style: const TextStyle(color: _adminMuted),
                        ),
                        Text(
                          '${readable('${issue['category']}')} · ${readable('${issue['severity']}')}',
                          style: TextStyle(
                            color: issueColor('${issue['severity']}'),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${issue['description']}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _shortDate(issue['created_at']),
                                style: const TextStyle(
                                  color: _adminMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: busyId == issue['id']
                                  ? null
                                  : () => manage(issue),
                              icon:
                                  const Icon(Icons.edit_note_rounded, size: 18),
                              label: const Text('Manage'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage(
      {required this.data, required this.onMonthChanged, super.key});
  final Map<String, dynamic> data;
  final ValueChanged<DateTime> onMonthChanged;
  @override
  Widget build(BuildContext context) {
    final owners = adminMapList(data['owners']);
    final selected =
        DateTime.tryParse('${data['reportMonth']}-01') ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(
          title: 'Monthly performance report',
          subtitle:
              'Billing and collection performance. Historical months remain read-only.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<int>(
                value: selected.month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem(
                        value: month, child: Text(_monthName(month))),
                ],
                onChanged: (value) {
                  if (value != null)
                    onMonthChanged(DateTime(selected.year, value));
                },
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<int>(
                value: selected.year,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [
                  for (var year = DateTime.now().year; year >= 2026; year--)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (value) {
                  if (value != null)
                    onMonthChanged(DateTime(value, selected.month));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _AdminPanel(
          title: 'Performance by owner',
          trailing: '${_monthName(selected.month)} ${selected.year}',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Owner')),
                DataColumn(label: Text('Properties')),
                DataColumn(label: Text('Invoices')),
                DataColumn(label: Text('Billed')),
                DataColumn(label: Text('Collected')),
                DataColumn(label: Text('Expenses')),
                DataColumn(label: Text('Net cash flow')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final owner in owners)
                  DataRow(cells: [
                    DataCell(Text('${owner['name']}')),
                    DataCell(Text('${owner['properties']}')),
                    DataCell(Text(
                        '${owner['completeBills']} / ${owner['invoices']}')),
                    DataCell(Text(_money(owner['billed']))),
                    DataCell(Text(_money(owner['collected']))),
                    DataCell(Text(_money(owner['expenses']))),
                    DataCell(Text(
                      _money(owner['netCashFlow']),
                      style: TextStyle(
                        color: adminNumber(owner['netCashFlow']) < 0
                            ? _adminRed
                            : _adminGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    )),
                    DataCell(Text(owner['collectionRate'] == null
                        ? '—'
                        : '${adminNumber(owner['collectionRate']).toStringAsFixed(1)}%')),
                    DataCell(_StatusBadge(
                      label: adminNumber(owner['reviewBills']).toInt() > 0
                          ? 'Attention'
                          : 'Clear',
                      color: adminNumber(owner['reviewBills']).toInt() > 0
                          ? _adminOrange
                          : _adminGreen,
                    )),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AdminApiMonitorPage extends StatelessWidget {
  const AdminApiMonitorPage({required this.monitor, super.key});

  final Map<String, dynamic> monitor;

  @override
  Widget build(BuildContext context) {
    final total = adminNumber(monitor['totalRequests']).toInt();
    final failures = adminNumber(monitor['failedRequests']).toInt();
    final errorRate = adminNumber(monitor['errorRate']);
    final averageLatency = adminNumber(monitor['averageLatencyMs']).toInt();
    final p95Latency = adminNumber(monitor['p95LatencyMs']).toInt();
    final sampleSize = adminNumber(monitor['sampleSize']).toInt();
    final truncated = monitor['truncated'] == true;
    final endpoints = adminMapList(monitor['endpoints']);
    final recent = adminMapList(monitor['recentRequests']);
    final windowHours = adminNumber(monitor['windowHours']).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PageHeader(
          title: 'API monitor',
          subtitle:
              'Edge Function request volume, failures and server execution latency over the last $windowHours hours.'),
      _ResponsiveGrid(minWidth: 230, children: [
        _MetricTile(
            label: 'API requests',
            value: '$total',
            detail:
                '${adminNumber(monitor['successfulRequests']).toInt()} successful',
            icon: Icons.swap_calls_rounded),
        _MetricTile(
            label: 'Failed requests',
            value: '$failures',
            detail: '${errorRate.toStringAsFixed(1)}% error rate',
            icon: Icons.error_outline_rounded,
            valueColor: failures > 0 ? _adminRed : _adminGreen),
        _MetricTile(
            label: 'Average latency',
            value: '$averageLatency ms',
            detail:
                '${adminNumber(monitor['slowRequests']).toInt()} requests at or above 1 second',
            icon: Icons.speed_rounded,
            valueColor: averageLatency >= 1000 ? _adminOrange : _adminNavy),
        _MetricTile(
            label: 'P95 latency',
            value: '$p95Latency ms',
            detail: '95% of sampled calls completed within this time',
            icon: Icons.timeline_rounded,
            valueColor: p95Latency >= 1000 ? _adminOrange : _adminNavy),
      ]),
      const SizedBox(height: 14),
      _AdminPanel(
          title: 'Functions',
          trailing: truncated
              ? 'Latest $sampleSize calls sampled'
              : '$sampleSize calls measured',
          child: endpoints.isEmpty
              ? const Text('No API calls recorded yet.',
                  style: TextStyle(color: _adminMuted))
              : Column(children: [
                  for (final endpoint in endpoints)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFE7F1FF),
                            foregroundColor: _adminBlue,
                            child: Icon(Icons.cloud_outlined, size: 18)),
                        const SizedBox(width: 11),
                        Expanded(
                            flex: 3,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${endpoint['functionName']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _adminNavy)),
                                  Text(
                                      'Last call ${_shortDate(endpoint['lastRequestAt'])}',
                                      style: const TextStyle(
                                          color: _adminMuted, fontSize: 12)),
                                ])),
                        Expanded(
                            child: _MiniValue(
                                value:
                                    '${adminNumber(endpoint['requests']).toInt()}',
                                label: 'Requests')),
                        Expanded(
                            child: _MiniValue(
                                value:
                                    '${adminNumber(endpoint['averageLatencyMs']).toInt()} ms',
                                label: 'Average')),
                        Expanded(
                            child: _MiniValue(
                                value:
                                    '${adminNumber(endpoint['errorRate']).toStringAsFixed(1)}%',
                                label: 'Errors')),
                      ]),
                    ),
                ])),
      const SizedBox(height: 14),
      _AdminPanel(
          title: 'Recent API calls',
          trailing: _shortDate(monitor['lastRequestAt']),
          child: recent.isEmpty
              ? const Text('No API calls recorded yet.',
                  style: TextStyle(color: _adminMuted))
              : Column(children: [
                  for (final request in recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          backgroundColor: _apiStatusColor(
                                  adminNumber(request['status_code']).toInt())
                              .withOpacity(.12),
                          foregroundColor: _apiStatusColor(
                              adminNumber(request['status_code']).toInt()),
                          child: Text('${request['status_code']}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800))),
                      title: Text(
                          '${request['function_name']} · ${request['method']}'),
                      subtitle: Text(
                          '${request['method']} · ${request['duration_ms']} ms · ${request['error_code'] ?? 'completed'}'),
                      trailing: Text(_shortDate(request['created_at']),
                          style: const TextStyle(
                              color: _adminMuted, fontSize: 12)),
                    ),
                ])),
    ]);
  }
}

Color _apiStatusColor(int status) {
  if (status >= 500) return _adminRed;
  if (status >= 400) return _adminOrange;
  return _adminGreen;
}

class AdminMembersPage extends StatefulWidget {
  const AdminMembersPage({
    required this.members,
    required this.canManage,
    required this.onGrant,
    required this.onSetAccess,
    super.key,
  });

  final List<Map<String, dynamic>> members;
  final bool canManage;
  final Future<bool> Function(String name, String email) onGrant;
  final Future<void> Function(Map<String, dynamic> member, bool enabled)
      onSetAccess;

  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
  String? busyId;

  Future<void> grantAdmin() async {
    final name = TextEditingController();
    final email = TextEditingController();
    String? validation;
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Grant administrator access'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'The account will receive restricted Super admin access. '
                  'Owner workspaces and monthly reports remain unavailable.',
                  style: TextStyle(color: _adminMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Administrator name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Administrator email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              if (validation != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(validation!,
                      style: const TextStyle(color: _adminRed)),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Grant access'),
              onPressed: () {
                final cleanName = name.text.trim();
                final cleanEmail = email.text.trim().toLowerCase();
                if (cleanName.isEmpty ||
                    !RegExp(r'^\S+@\S+\.\S+$').hasMatch(cleanEmail)) {
                  setDialogState(() => validation =
                      'Enter the administrator name and a valid email.');
                  return;
                }
                Navigator.pop(
                    context, {'name': cleanName, 'email': cleanEmail});
              },
            ),
          ],
        ),
      ),
    );
    name.dispose();
    email.dispose();
    if (input == null || !mounted) return;
    setState(() => busyId = 'grant');
    try {
      final invited = await widget.onGrant(input['name']!, input['email']!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(invited
            ? 'Super admin granted. An invitation email was sent.'
            : 'Super admin access granted to the existing account.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> setAccess(Map<String, dynamic> member, bool enabled) async {
    final id = '${member['user_id']}';
    setState(() => busyId = id);
    try {
      await widget.onSetAccess(member, enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final founders =
        widget.members.where((member) => member['level'] == 'founder').length;
    final active =
        widget.members.where((member) => member['enabled'] == true).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PageHeader(
        title: 'Admin members',
        subtitle:
            'Monitor portal access levels and administrator verification activity.',
        actions: [
          if (widget.canManage)
            FilledButton.icon(
              onPressed: busyId == null ? grantAdmin : null,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Grant admin access'),
            ),
        ],
      ),
      _ResponsiveGrid(minWidth: 230, children: [
        _MetricTile(
          label: 'Admin members',
          value: '${widget.members.length}',
          detail: '$active currently active',
          icon: Icons.admin_panel_settings_outlined,
        ),
        _MetricTile(
          label: 'Founders',
          value: '$founders',
          detail: 'Permanent unrestricted access',
          icon: Icons.workspace_premium_rounded,
          valueColor: const Color(0xFF6D28D9),
        ),
        _MetricTile(
          label: 'Super admins',
          value: '${widget.members.length - founders}',
          detail: 'Restricted owner and report access',
          icon: Icons.shield_outlined,
        ),
      ]),
      const SizedBox(height: 14),
      _AdminPanel(
        title: 'Access levels',
        child: _ResponsiveGrid(minWidth: 330, children: const [
          _InfoRow(
              label: 'Founder',
              value: 'Full portal + grant access',
              positive: true),
          _InfoRow(
              label: 'Super admin',
              value: 'No owner details or monthly reports'),
        ]),
      ),
      const SizedBox(height: 14),
      _AdminPanel(
        title: 'Administrator directory',
        child: widget.members.isEmpty
            ? const Text('No administrator accounts found.',
                style: TextStyle(color: _adminMuted))
            : Column(children: [
                for (final member in widget.members)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDDE5EF)),
                    ),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final founder = member['level'] == 'founder';
                      final details = Row(children: [
                        founder
                            ? const DiamondCrownIcon(size: 42)
                            : const CircleAvatar(
                                radius: 21,
                                backgroundColor: Color(0xFFE7F1FF),
                                foregroundColor: _adminBlue,
                                child:
                                    Icon(Icons.admin_panel_settings_outlined)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${member['display_name']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _adminNavy)),
                                Text('${member['email']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _adminMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  'Last login: ${_shortDate(member['lastLoginAt'])} · OTP verified: ${_shortDate(member['last_verified_at'])}',
                                  style: const TextStyle(
                                      color: _adminMuted, fontSize: 11),
                                ),
                              ]),
                        ),
                      ]);
                      final controls = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusBadge(
                            label: founder ? 'Founder' : 'Super admin',
                            color:
                                founder ? const Color(0xFF6D28D9) : _adminBlue,
                          ),
                          _StatusBadge(
                            label: member['enabled'] == true
                                ? 'Active'
                                : 'Revoked',
                            color: member['enabled'] == true
                                ? _adminGreen
                                : _adminRed,
                          ),
                          if (founder)
                            const Text('Permanent',
                                style: TextStyle(
                                    color: Color(0xFF6D28D9),
                                    fontWeight: FontWeight.w700))
                          else if (widget.canManage)
                            OutlinedButton.icon(
                              onPressed: busyId == member['user_id']
                                  ? null
                                  : () => setAccess(
                                      member, member['enabled'] != true),
                              icon: Icon(member['enabled'] == true
                                  ? Icons.person_off_outlined
                                  : Icons.person_add_alt_1_rounded),
                              label: Text(member['enabled'] == true
                                  ? 'Revoke access'
                                  : 'Restore access'),
                            ),
                        ],
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              details,
                              const SizedBox(height: 12),
                              controls,
                            ]);
                      }
                      return Row(children: [
                        Expanded(child: details),
                        const SizedBox(width: 14),
                        controls,
                      ]);
                    }),
                  ),
              ]),
      ),
    ]);
  }
}

class AdminAuditPage extends StatelessWidget {
  const AdminAuditPage({required this.logs, super.key});
  final List<Map<String, dynamic>> logs;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PageHeader(
            title: 'Activity logs',
            subtitle:
                'Owner workspace activity and sensitive administrator changes in one timeline.'),
        _ResponsiveGrid(minWidth: 300, children: const [
          _AdminPanel(
              title: 'Access policy',
              child: Column(children: [
                _InfoRow(label: 'Authorization', value: 'Admin allowlist'),
                _InfoRow(label: 'Session verification', value: 'Email OTP'),
                _InfoRow(label: 'Privileged credentials', value: 'Server only'),
                _InfoRow(
                    label: 'Audit records', value: 'Immutable', positive: true)
              ])),
          _AdminPanel(
              title: 'Data protection',
              child: Column(children: [
                _InfoRow(label: 'Past-month finances', value: 'Read-only'),
                _InfoRow(
                    label: 'Configuration changes',
                    value: 'Current month onward'),
                _InfoRow(label: 'Owner separation', value: 'Supabase RLS'),
                _InfoRow(label: 'Reset actions', value: 'Logged')
              ]))
        ]),
        const SizedBox(height: 14),
        _AdminPanel(
            title: 'Recent activity',
            child: logs.isEmpty
                ? const Text(
                    'No business or administrator activity recorded yet.',
                    style: TextStyle(color: _adminMuted))
                : Column(children: [
                    for (final log in logs)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              backgroundColor: (log['source'] == 'owner'
                                      ? _adminGreen
                                      : _adminBlue)
                                  .withOpacity(.12),
                              foregroundColor: log['source'] == 'owner'
                                  ? _adminGreen
                                  : _adminBlue,
                              child: Icon(
                                  log['source'] == 'owner'
                                      ? Icons.history_rounded
                                      : Icons.admin_panel_settings_outlined,
                                  size: 19)),
                          title: Text('${log['action']}'.replaceAll('.', ' ')),
                          subtitle: Text(
                              '${log['actor'] ?? 'System'} · ${log['target_type']}'),
                          trailing: Text(_shortDate(log['created_at']),
                              style: const TextStyle(
                                  color: _adminMuted, fontSize: 12)))
                  ])),
      ]);
}

class _PageHeader extends StatelessWidget {
  const _PageHeader(
      {required this.title, required this.subtitle, this.actions = const []});
  final String title;
  final String subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            children: [
              SizedBox(
                  width: 600,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                color: _adminNavy)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                color: _adminMuted, height: 1.4))
                      ])),
              if (actions.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: actions)
            ]),
      );
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.minWidth, required this.children});
  final double minWidth;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = (constraints.maxWidth / minWidth)
            .floor()
            .clamp(1, children.length)
            .toInt();
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final child in children) SizedBox(width: width, child: child)
        ]);
      });
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label,
      required this.value,
      required this.detail,
      required this.icon,
      this.valueColor});
  final String label, value, detail;
  final IconData icon;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xFFDDE5EF))),
      child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: const Color(0xFFE7F1FF),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: _adminBlue)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label, style: const TextStyle(color: _adminMuted)),
                  const SizedBox(height: 5),
                  Text(value,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: valueColor ?? _adminNavy)),
                  const SizedBox(height: 3),
                  Text(detail,
                      style: const TextStyle(color: _adminMuted, fontSize: 12))
                ]))
          ])));
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xFFDDE5EF))),
      child: Padding(
          padding: const EdgeInsets.all(17),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: _adminNavy))),
              if (trailing != null)
                Text(trailing!,
                    style: const TextStyle(color: _adminMuted, fontSize: 12))
            ]),
            const SizedBox(height: 16),
            child
          ])));
}

class _TrafficBars extends StatelessWidget {
  const _TrafficBars({required this.hours});

  final List<Map<String, dynamic>> hours;

  @override
  Widget build(BuildContext context) {
    final maxViews = hours.fold<int>(
      1,
      (highest, hour) => highest > adminNumber(hour['views']).toInt()
          ? highest
          : adminNumber(hour['views']).toInt(),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Page views by hour (MYT)',
          style: TextStyle(
              color: _adminMuted, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SizedBox(
        height: 72,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final hour in hours)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Tooltip(
                  message:
                      '${hour['hour']}:00 · ${adminNumber(hour['views']).toInt()} views',
                  child: Container(
                    height: 4 +
                        (60 * adminNumber(hour['views']).toInt() / maxViews),
                    decoration: const BoxDecoration(
                      color: _adminBlue,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('00', style: TextStyle(color: _adminMuted, fontSize: 10)),
        Text('06', style: TextStyle(color: _adminMuted, fontSize: 10)),
        Text('12', style: TextStyle(color: _adminMuted, fontSize: 10)),
        Text('18', style: TextStyle(color: _adminMuted, fontSize: 10)),
        Text('23', style: TextStyle(color: _adminMuted, fontSize: 10)),
      ]),
    ]);
  }
}

class _RoleProgress extends StatelessWidget {
  const _RoleProgress(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});
  final String label;
  final int value, total;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;
    return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(label, style: const TextStyle(color: _adminMuted))),
            Text('$value · ${(ratio * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 7),
          LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: const Color(0xFFE8EDF4),
              color: color)
        ]));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, this.positive = false});
  final String label, value;
  final bool positive;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(
            child: Text(label, style: const TextStyle(color: _adminMuted))),
        const SizedBox(width: 10),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: positive ? _adminGreen : _adminNavy))
      ]));
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(11)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: _adminNavy)),
        Text(label, style: const TextStyle(color: _adminMuted, fontSize: 11))
      ]));
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(30)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)));
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    if (tier == 'diamond') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4C1D66),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          DiamondCrownIcon(size: 18, showPurpleTile: false),
          SizedBox(width: 5),
          Text('Founder · Diamond',
              style: TextStyle(
                  color: Color(0xFFFFD86B), fontWeight: FontWeight.w800)),
        ]),
      );
    }
    final premium = tier == 'premium';
    if (premium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF5A1533),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          PremiumKeyIcon(size: 18, showBurgundyTile: false),
          SizedBox(width: 5),
          Text(
            'Premium',
            style: TextStyle(
              color: Color(0xFFFFD86B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      );
    }
    return _StatusBadge(
      label: 'Free',
      color: _adminBlue,
    );
  }
}

String _subscriptionStatusLabel(String value) => switch (value) {
      'pending_verification' => 'Pending verification',
      'expired' => 'Expired',
      _ => 'Active',
    };

class _LimitField extends StatelessWidget {
  const _LimitField(
      {required this.label, required this.controller, this.enabled = true});
  final String label;
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label)));
}

class _FeatureSwitch extends StatelessWidget {
  const _FeatureSwitch(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style:
              const TextStyle(fontWeight: FontWeight.w700, color: _adminNavy)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: _adminMuted, fontSize: 12)));
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _roleLabel(String role) => switch (role) {
      'owner' => 'Owner',
      'tenant' => 'Tenant',
      'property_agent' => 'Agent',
      'technician' => 'Technician',
      _ => role
    };
String _shortDate(Object? value) {
  if (value == null || '$value'.isEmpty) return 'Never';
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '$value';
  final minute = date.minute.toString().padLeft(2, '0');
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '${date.day}/${date.month}/${date.year} $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

String _money(Object? value) {
  final amount = adminNumber(value).toDouble();
  final parts = amount.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i;
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return 'RM ${buffer.toString()}.${parts.last}';
}

String _monthName(int month) => const [
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
      'Dec'
    ][(month - 1).clamp(0, 11)];
