import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../file_download/file_downloader.dart';
import 'settlement_cloud_persistence.dart';
import '../persistence/persistence_contract.dart';
import 'settlement_opener.dart';
import 'settlement_model.dart';
import 'settlement_pdf.dart';

class SavedSettlementInvoice extends StatefulWidget {
  const SavedSettlementInvoice(
      {super.key,
      required this.draftKey,
      required this.translate,
      this.tenantId,
      this.tenancyId,
      this.facilityId,
      this.persistence});
  final String draftKey;
  final String? tenantId, tenancyId, facilityId;
  final String Function(String) translate;
  final AppPersistence? persistence;
  @override
  State<SavedSettlementInvoice> createState() => _SavedSettlementInvoiceState();
}

class _SavedSettlementInvoiceState extends State<SavedSettlementInvoice> {
  MoveOutSettlement? _settlement;
  Uint8List? _pdf;
  bool _failed = false;
  String t(String value) => widget.translate(value);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final persistence = widget.persistence ??
          await createSettlementPersistence(widget.draftKey,
              tenantId: widget.tenantId,
              tenancyId: widget.tenancyId,
              facilityId: widget.facilityId);
      final raw = await persistence.readSnapshot();
      if (raw == null || !mounted) return;
      final settlement = MoveOutSettlement.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw)));
      setState(() {
        _settlement = settlement;
        _failed = false;
        _pdf = null;
      });
      // Prepare before the click to preserve Safari user activation.
      final bytes = await (persistence is SettlementCloudPersistence
              ? persistence.readPdf()
              : buildSettlementPdf(settlement))
          .timeout(const Duration(seconds: 30));
      if (mounted) setState(() => _pdf = bytes);
      // Do not close the native app's shared SQLite connection.
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _view() async {
    final bytes = _pdf;
    if (bytes == null) return;
    try {
      await openSettlementPdf(bytes);
    } catch (_) {
      _error('Unable to open settlement invoice. Please try again.');
    }
  }

  Future<void> _download() async {
    final bytes = _pdf;
    if (bytes == null) return;
    try {
      if (kIsWeb) {
        await downloadBytesFile(
            fileName: 'move-out-settlement.pdf',
            bytes: bytes,
            mimeType: 'application/pdf');
      } else {
        await Printing.sharePdf(
            bytes: bytes, filename: 'move-out-settlement.pdf');
      }
    } catch (_) {
      _error('Download failed. Please retry.');
    }
  }

  void _error(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t(message))));
  }

  @override
  Widget build(BuildContext context) {
    final settlement = _settlement;
    if (settlement == null)
      return _failed
          ? TextButton(
              onPressed: _load,
              child: Text(t('Unable to load cloud settlement. Tap to retry.')))
          : const SizedBox.shrink();
    return Card(
        color: Colors.white,
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.picture_as_pdf_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(t('Move-out settlement invoice')),
                        Text(
                            '${settlement.dateLabel} · ${t(settlement.isRefunded ? 'Refunded' : 'Refund pending')}'),
                      ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12)),
                          onPressed: _pdf == null ? null : _download,
                          icon: const Icon(Icons.download, size: 20),
                          label: Text(t('Download PDF'),
                              textAlign: TextAlign.center))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12)),
                          onPressed: _pdf == null ? null : _view,
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: Text(t('View PDF'),
                              textAlign: TextAlign.center))),
                ]),
                if (_pdf == null && !_failed) Text(t('Preparing PDF...')),
                if (_failed)
                  TextButton(
                      onPressed: _load,
                      child: Text(t(
                          'Unable to open settlement invoice. Please try again.'))),
              ],
            )));
  }
}
