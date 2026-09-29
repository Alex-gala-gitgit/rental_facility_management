import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class PdfBrowserTab {
  PdfBrowserTab(this.window);

  final html.WindowBase? window;
}

PdfBrowserTab preparePdfBrowserTab() =>
    PdfBrowserTab(html.window.open('about:blank', '_blank'));

Future<void> showPdfInBrowserTab(
  PdfBrowserTab tab,
  Uint8List bytes,
  String fileName,
) async {
  final blob = html.Blob(<Object>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final target = tab.window;
  if (target == null) {
    html.Url.revokeObjectUrl(url);
    throw StateError('The browser blocked the invoice PDF tab.');
  }
  target.location.href = '$url#view=FitH';
  Future<void>.delayed(const Duration(minutes: 5), () {
    html.Url.revokeObjectUrl(url);
  });
}

void closePdfBrowserTab(PdfBrowserTab tab) => tab.window?.close();

class InlinePdfPreview extends StatefulWidget {
  const InlinePdfPreview({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  State<InlinePdfPreview> createState() => _InlinePdfPreviewState();
}

class _InlinePdfPreviewState extends State<InlinePdfPreview> {
  late final String viewType;

  @override
  void initState() {
    super.initState();
    viewType = 'invoice-pdf-${identityHashCode(this)}';
    final dataUrl =
        'data:application/pdf;base64,${base64Encode(widget.bytes)}#view=FitH';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
      return html.IFrameElement()
        ..src = dataUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('title', 'Invoice PDF preview');
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: viewType);
}
