import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as images;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../file_download/file_downloader.dart';
import '../file_upload/image_file_picker.dart';
import '../cloud/meter_reading_service.dart';
import '../local_ocr/local_meter_ocr.dart';
import 'settlement_cloud_persistence.dart';
import '../persistence/persistence_contract.dart';
import 'settlement_model.dart';
import 'settlement_pdf.dart';
import 'settlement_share.dart';
import 'settlement_whatsapp.dart';
import 'money_input.dart';

class MoveOutSettlementPage extends StatefulWidget {
  const MoveOutSettlementPage(
      {super.key,
      required this.tenantName,
      required this.propertyName,
      required this.unitName,
      required this.draftKey,
      required this.initialDate,
      required this.translate,
      required this.calculateElectricityCharge,
      this.bankName = '',
      this.bankAccountNumber = '',
      this.tenantPhone = '',
      this.monthlyRent = 0,
      this.readMeter,
      this.pickImage,
      this.onInvoiceGenerated,
      this.onCompleteRefund,
      this.tenantId,
      this.tenancyId,
      this.facilityId,
      this.persistence});
  final Future<void> Function(MoveOutSettlement settlement)? onCompleteRefund;
  final Future<void> Function(MoveOutSettlement settlement, Uint8List pdf,
      bool isFinal)? onInvoiceGenerated;
  final String tenantName, propertyName, unitName, draftKey;
  final String bankName, bankAccountNumber;
  final String tenantPhone;
  final double monthlyRent;
  final String? tenantId, tenancyId, facilityId;
  final DateTime initialDate;
  final String Function(String) translate;
  final AppPersistence? persistence;
  final double Function(double usageKwh) calculateElectricityCharge;
  final Future<DetectedMeterReading> Function(Uint8List bytes, String name)?
      readMeter;
  final Future<PickedImageData?> Function()? pickImage;
  @override
  State<MoveOutSettlementPage> createState() => _MoveOutSettlementPageState();
}

class _MoveOutSettlementPageState extends State<MoveOutSettlementPage> {
  final _form = GlobalKey<FormState>();
  final _amounts = {
    for (final name in [
      'Deposit held',
      'Electricity',
      'Water bill',
      'Internet',
      'Parking',
      'Other charges'
    ])
      name: TextEditingController(text: '0.00')
  };
  final _description = TextEditingController();
  final _usage = TextEditingController();
  late final TextEditingController _proratedDays;
  String? _readingStatus;
  late DateTime _date;
  AppPersistence? _persistence;
  SettlementAttachment? _meter, _payslip;
  Uint8List? _pdf;
  bool _busy = false, _loading = true;
  String? _error;
  bool _completed = false;
  String t(String key) => widget.translate(key);
  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _proratedDays = TextEditingController(text: '${widget.initialDate.day}');
    _load();
  }

  Future<void> _load() async {
    AppPersistence? persistence;
    try {
      persistence = widget.persistence ??
          await createSettlementPersistence(widget.draftKey,
              tenantId: widget.tenantId,
              tenancyId: widget.tenancyId,
              facilityId: widget.facilityId);
      final saved = await persistence.readSnapshot();
      if (!mounted) {
        return;
      }
      _persistence = persistence;
      if (saved != null) {
        final savedJson = Map<String, dynamic>.from(jsonDecode(saved));
        final value = MoveOutSettlement.fromJson(savedJson);
        _date = value.moveOutDate;
        _meter = value.meter;
        _payslip = value.payslip;
        final values = [
          value.deposit,
          value.electricity,
          value.water,
          value.internet,
          value.parking,
          value.other
        ];
        var i = 0;
        for (final controller in _amounts.values) {
          controller.text = (values[i++] / 100).toStringAsFixed(2);
        }
        _description.text = value.otherDescription;
        _usage.text = value.electricityUsageKwh?.toStringAsFixed(2) ?? '';
        _proratedDays.text = savedJson.containsKey('proratedStayDays')
            ? '${value.proratedStayDays}'
            : '${value.moveOutDate.day}';
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _error = t('Unable to load cloud settlement. Tap to retry.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    _description.dispose();
    _usage.dispose();
    _proratedDays.dispose();
    // Native persistence uses the app's shared SQLite connection. Closing it
    // from a child route would also close the main store's database.
    super.dispose();
  }

  void _changed() => setState(() {
        _pdf = null;
        _error = null;
      });
  MoveOutSettlement get _value => MoveOutSettlement(
        tenantName: widget.tenantName,
        propertyName: widget.propertyName,
        unitName: widget.unitName,
        moveOutDate: _date,
        deposit: settlementCents(_amounts['Deposit held']!.text) ?? 0,
        electricity: settlementCents(_amounts['Electricity']!.text) ?? 0,
        water: settlementCents(_amounts['Water bill']!.text) ?? 0,
        internet: settlementCents(_amounts['Internet']!.text) ?? 0,
        parking: settlementCents(_amounts['Parking']!.text) ?? 0,
        other: settlementCents(_amounts['Other charges']!.text) ?? 0,
        otherDescription: _description.text.trim(),
        bankName: widget.bankName,
        bankAccountNumber: widget.bankAccountNumber,
        monthlyRent: (widget.monthlyRent * 100).round(),
        proratedStayDays: int.tryParse(_proratedDays.text) ?? 0,
        meter: _meter,
        payslip: _payslip,
        electricityUsageKwh: double.tryParse(_usage.text),
      );
  String get _filename =>
      'move-out-settlement-${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}.pdf';

  Future<void> _upload(bool meter) async {
    if (!meter && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await (widget.pickImage ?? pickImageForUpload)();
      if (!mounted || picked == null) return;
      if (picked.bytes.length > 12 * 1024 * 1024)
        throw StateError('Image too large');
      final image = images.decodeImage(Uint8List.fromList(picked.bytes));
      if (image == null) throw StateError('Unreadable image');
      final scaled = image.width > 2000 || image.height > 2000
          ? images.copyResize(image,
              width: image.width >= image.height ? 2000 : null,
              height: image.height > image.width ? 2000 : null)
          : image;
      final attachment = SettlementAttachment(picked.name,
          Uint8List.fromList(images.encodeJpg(scaled, quality: 85)));
      setState(() {
        if (meter) {
          _meter = attachment;
          _usage.clear();
          _amounts['Electricity']!.clear();
          _readingStatus = t('Reading meter attachment...');
        } else {
          _payslip = attachment;
        }
        _pdf = null;
      });
      if (!meter) {
        try {
          final persistence = _persistence;
          if (persistence == null)
            throw StateError('Draft storage unavailable');
          await persistence.writeSnapshot(jsonEncode(_value.toJson()));
        } catch (_) {
          if (mounted)
            setState(() => _error =
                t('Could not save refund confirmation. Please retry.'));
          return;
        }
      }
      if (meter) {
        try {
          final bytes = Uint8List.fromList(picked.bytes);
          final reading = widget.readMeter == null
              ? await LocalMeterOcr().read(bytes: bytes, fileName: picked.name)
              : await widget.readMeter!(bytes, picked.name);
          if (!mounted) return;
          if (!reading.usageKwh.isFinite || reading.usageKwh < 0)
            throw StateError('Invalid reading');
          _usage.text = reading.usageKwh.toStringAsFixed(2);
          _recalculateUsage();
          setState(() => _readingStatus = t(
              'Detected automatically. Review and correct the usage if needed.'));
        } catch (_) {
          if (mounted)
            setState(() => _readingStatus = t(
                'Could not read the meter. Enter the usage or electricity amount manually.'));
        }
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = t('Choose a readable image under 12 MB.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _recalculateUsage() {
    final usage = double.tryParse(_usage.text);
    if (usage == null || !usage.isFinite || usage < 0) {
      _amounts['Electricity']!.clear();
    } else {
      final charge = widget.calculateElectricityCharge(usage);
      if (!charge.isFinite || charge < 0)
        throw StateError('Invalid tariff charge');
      _amounts['Electricity']!.text = charge.toStringAsFixed(2);
    }
    _changed();
  }

  Future<void> _generate() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _pdf = null;
      _error = null;
    });
    late final MoveOutSettlement settlement;
    late final Uint8List bytes;
    try {
      settlement = _value;
      bytes = await buildSettlementPdf(settlement);
      if (mounted) setState(() => _pdf = bytes);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'move-out settlement',
        context: ErrorDescription('while creating an invoice PDF'),
      ));
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t(
              'Could not create the PDF on this device. Please refresh and retry.');
        });
      }
      return;
    }

    try {
      await _savePreparedSettlement(settlement, bytes);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'move-out settlement',
        context: ErrorDescription('while saving an invoice to the cloud'),
      ));
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t(
              'PDF ready on this device, but cloud saving failed. Sign in again, then tap Generate PDF invoice to retry.');
        });
      }
      return;
    }

    try {
      await widget.onInvoiceGenerated?.call(settlement, bytes, false);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'move-out settlement',
        context: ErrorDescription('while updating the move-out request'),
      ));
      if (mounted) {
        setState(() => _error = t(
            'PDF saved, but the request status could not be updated. Tap Generate PDF invoice to retry.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePreparedSettlement(
      MoveOutSettlement settlement, Uint8List bytes) async {
    final persistence = await _ensurePersistenceReady();
    final snapshot = jsonEncode(settlement.toJson());
    if (persistence is SettlementCloudPersistence) {
      await persistence.writePreparedSnapshot(snapshot, bytes);
    } else {
      await persistence.writeSnapshot(snapshot);
    }
  }

  Future<AppPersistence> _ensurePersistenceReady() async {
    final ready = _persistence;
    if (ready != null) return ready;

    final persistence = widget.persistence ??
        await createSettlementPersistence(widget.draftKey,
            tenantId: widget.tenantId,
            tenancyId: widget.tenancyId,
            facilityId: widget.facilityId);
    // A failed initial read leaves cloud persistence without its revision state.
    // Retry it at the moment the owner generates the invoice rather than making
    // the page permanently unsaveable until it is reopened.
    await persistence.readSnapshot();
    _persistence = persistence;
    return persistence;
  }

  Future<void> _completeRefund() async {
    if (_busy ||
        _completed ||
        _payslip == null ||
        !_form.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(t('Complete refund?')),
              content: Text(t(
                  'This completes the move-out request and ends the tenancy on the move-out date. Reactivation is available for one month after inactivation.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t('Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t('Complete refund'))),
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settlement = _value.asFinalInvoice();
      final bytes = await buildSettlementPdf(settlement);
      await _savePreparedSettlement(settlement, bytes);
      await widget.onInvoiceGenerated?.call(settlement, bytes, true);
      await widget.onCompleteRefund!(settlement);
      if (mounted) setState(() => _completed = true);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            t('Unable to complete refund. Please refresh and try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final bytes = _pdf;
    if (bytes == null) return;
    try {
      if (kIsWeb) {
        await downloadBytesFile(
            fileName: _filename,
            mimeType: 'application/pdf',
            bytes: bytes,
            openInNewTab: true);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: _filename);
      }
    } catch (_) {
      if (mounted) setState(() => _error = t('Download failed. Please retry.'));
    }
  }

  Future<void> _share() async {
    final bytes = _pdf;
    if (bytes == null) return;
    if (hasTenantWhatsAppNumber(widget.tenantPhone)) {
      try {
        final uri = tenantSettlementWhatsAppUri(
          tenantName: widget.tenantName,
          tenantPhone: widget.tenantPhone,
        );
        final opened = await launchUrl(
          uri,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
          webOnlyWindowName: kIsWeb ? '_blank' : null,
        );
        if (!opened) throw StateError('WhatsApp could not be opened.');
        return;
      } catch (_) {
        if (mounted) {
          setState(() => _error = t(
              'Could not open the registered tenant WhatsApp chat. Please retry.'));
        }
        return;
      }
    }
    var supported = false;
    try {
      supported = await shareSettlementPdf(bytes, _filename);
    } catch (_) {
      // Keep the PDF available for download when the platform share fails.
    }
    if (!mounted) return;
    if (!supported) {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(t('Send via WhatsApp')),
                content: Text(t(
                    'Direct file sharing is unavailable. Download the PDF, open WhatsApp, and attach it to the tenant chat.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('Close'))),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _download();
                      },
                      child: Text(t('Download PDF')))
                ],
              ));
    }
  }

  Widget _amount(String label) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Focus(
          onFocusChange: (focused) {
            if (!mounted) return;
            final controller = _amounts[label]!;
            if (focused) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !controller.selection.isValid) return;
                controller.selection = TextSelection(
                    baseOffset: 0, extentOffset: controller.text.length);
              });
            } else {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount.isFinite && amount >= 0) {
                controller.text = amount.toStringAsFixed(2);
              }
            }
          },
          child: TextFormField(
            key: ValueKey('settlement-$label'),
            controller: _amounts[label],
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: appMoneyInputFormatters(),
            decoration: InputDecoration(
                labelText: '${t(label)} · RM',
                border: const OutlineInputBorder()),
            onChanged: (_) => _changed(),
            validator: (value) => settlementCents(value ?? '') == null
                ? t('Enter a non-negative amount with up to 2 decimal places.')
                : null,
          )));
  Widget _panel(String title, List<Widget> children, {Color? color}) => Card(
      color: color,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t(title),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            ...children,
          ])));
  Widget _attachment(bool meter) {
    final file = meter ? _meter : _payslip;
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title:
                  Text(t(meter ? 'Final meter reading' : 'Payslip attachment')),
              subtitle: Text(file?.name ?? t('Optional image attachment')),
              trailing: OutlinedButton(
                  onPressed: _busy ? null : () => _upload(meter),
                  child: Text(t(file == null ? 'Upload' : 'Replace')))),
          if (file != null) ...[
            Image.memory(file.bytes, height: 120, fit: BoxFit.contain),
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          if (meter) {
                            _meter = null;
                            _usage.clear();
                            _readingStatus = null;
                          } else {
                            _payslip = null;
                          }
                          _pdf = null;
                        }),
                child: Text(t('Remove'))),
          ],
        ]));
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        const SizedBox(width: 12),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      ]));

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return Scaffold(
      appBar: AppBar(title: Text(t('Move-out settlement'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                    key: _form,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              '${widget.tenantName} · ${widget.propertyName} · ${widget.unitName}'),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final date = await showDatePicker(
                                          context: context,
                                          initialDate: _date,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100));
                                      if (date != null && mounted) {
                                        _date = date;
                                        _proratedDays.text = '${date.day}';
                                        _changed();
                                      }
                                    },
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                  '${t('Move-out date')}: ${value.dateLabel}')),
                          _panel('Deposit to be refunded',
                              [_amount('Deposit held')]),
                          _panel('Refund bank details', [
                            const SizedBox(height: 10),
                            _row(t('Bank'), widget.bankName.isEmpty ? '-' : widget.bankName),
                            _row(t('Bank account number'),
                                widget.bankAccountNumber.isEmpty ? '-' : widget.bankAccountNumber),
                          ]),
                          _panel('Prorated stay', [
                            const SizedBox(height: 10),
                            _row(t('Monthly rent'),
                                settlementMoney((widget.monthlyRent * 100).round())),
                            _row(t('Daily rent (monthly rent / 30)'),
                                settlementMoney((widget.monthlyRent * 100 / 30).round())),
                            const SizedBox(height: 10),
                            TextFormField(
                              key: const ValueKey('settlement-prorated-days'),
                              controller: _proratedDays,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: t('Prorated stay days'),
                                helperText: t('Calculated as monthly rent / 30 x days stayed.'),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => _changed(),
                              validator: (text) {
                                final days = int.tryParse(text ?? '');
                                return days == null || days < 0 || days > 30
                                    ? t('Enter a day count from 0 to 30.')
                                    : null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _row(t('Prorated stay deduction'),
                                settlementMoney(value.proratedStay), bold: true),
                          ]),
                          _panel('Final charges', [
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TextFormField(
                                  key: const ValueKey(
                                      'settlement-electricity-usage'),
                                  controller: _usage,
                                  enabled: !_busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                      labelText:
                                          '${t('Electricity usage')} · kWh',
                                      border: const OutlineInputBorder()),
                                  onChanged: (_) => _recalculateUsage(),
                                  validator: (text) => (text ?? '').isEmpty ||
                                          settlementCents(text!) != null
                                      ? null
                                      : t('Enter a non-negative amount with up to 2 decimal places.'),
                                )),
                            _amount('Electricity'),
                            _attachment(true),
                            if (_readingStatus != null) Text(_readingStatus!),
                            _amount('Water bill'),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _amount('Internet')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _amount('Parking'))
                                ]),
                            _amount('Other charges'),
                            const SizedBox(height: 12),
                            TextFormField(
                                key: const ValueKey(
                                    'settlement-other-description'),
                                controller: _description,
                                enabled: !_busy,
                                maxLength: 120,
                                maxLines: 2,
                                decoration: InputDecoration(
                                    labelText: t('Other charges description'),
                                    hintText: t('For example: Cleaning fee'),
                                    border: const OutlineInputBorder()),
                                onChanged: (_) => _changed(),
                                validator: (text) => _value.other > 0 &&
                                        (text ?? '').trim().isEmpty
                                    ? t('Describe the other charges.')
                                    : null),
                          ]),
                          _panel(
                              'Settlement summary',
                              [
                                _row(t('Deposit held'),
                                    settlementMoney(value.deposit)),
                                for (final charge in value.charges)
                                  _row(
                                      charge.$1 == value.otherLabel
                                          ? '${t('Other charges')}${value.otherDescription.isEmpty ? '' : ' - ${value.otherDescription}'}'
                                          : t(charge.$1),
                                      '${charge.$2 == 0 ? '' : '- '}${settlementMoney(charge.$2)}'),
                                const Divider(),
                                _row(t('Total deductions'),
                                    settlementMoney(value.deductions),
                                    bold: true),
                                const Divider(),
                                Text(t(value.balance >= 0
                                    ? (_payslip == null
                                        ? 'Balance to refund'
                                        : 'Amount refunded')
                                    : 'Additional amount due')),
                                Text(settlementMoney(value.balance.abs()),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                              ],
                              color: const Color(0xFFEAF7F0)),
                          _panel(
                              'Refund payslip',
                              [
                                _attachment(false),
                                if (widget.onCompleteRefund != null) ...[
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed:
                                        _busy || _completed || _payslip == null
                                            ? null
                                            : _completeRefund,
                                    icon: const Icon(Icons.task_alt),
                                    label: Text(t(_completed
                                        ? 'Refund completed'
                                        : 'Complete refund')),
                                  ),
                                ],
                              ],
                              color: Colors.white),
                          _panel('PDF invoice', [
                            const SizedBox(height: 12),
                            FilledButton.icon(
                                onPressed: _busy ? null : _generate,
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: Text(t('Generate PDF invoice'))),
                            const SizedBox(height: 10),
                            Wrap(spacing: 10, runSpacing: 8, children: [
                              OutlinedButton.icon(
                                  onPressed:
                                      _pdf == null || _busy ? null : _download,
                                  icon: const Icon(Icons.download),
                                  label: Text(t('Download PDF'))),
                              OutlinedButton.icon(
                                  onPressed:
                                      _pdf == null || _busy ? null : _share,
                                  icon: const Icon(Icons.send_outlined),
                                  label: Text(t('Send via WhatsApp'))),
                            ]),
                            const SizedBox(height: 12),
                            Text(t(_pdf == null
                                ? 'Generate the invoice first to download or share it.'
                                : hasTenantWhatsAppNumber(widget.tenantPhone)
                                    ? 'PDF ready. Send via WhatsApp opens the registered tenant chat.'
                                    : 'PDF ready. Choose WhatsApp in the share menu.')),
                            if (_pdf != null) ...[
                              const SizedBox(height: 8),
                              Text(t(
                                  'On iPhone, close the PDF tab or return to Safari after sharing. This settlement page stays open.')),
                            ],
                            const SizedBox(height: 8),
                            Text(t(
                                'Saved securely in the cloud. Uploading a refund payslip confirms the refund. Complete refund records the tenancy ending.')),
                          ]),
                          if (_busy)
                            const Padding(
                                padding: EdgeInsets.all(16),
                                child: LinearProgressIndicator()),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])),
              ),
            )),
    );
  }
}
