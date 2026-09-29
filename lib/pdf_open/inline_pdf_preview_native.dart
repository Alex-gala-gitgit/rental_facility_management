import 'dart:typed_data';

import 'package:flutter/material.dart';

class PdfBrowserTab {
  const PdfBrowserTab();
}

PdfBrowserTab preparePdfBrowserTab() => const PdfBrowserTab();

Future<void> showPdfInBrowserTab(
  PdfBrowserTab tab,
  Uint8List bytes,
  String fileName,
) async {}

void closePdfBrowserTab(PdfBrowserTab tab) {}

class InlinePdfPreview extends StatelessWidget {
  const InlinePdfPreview({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Inline PDF preview is available in web browsers.'),
      );
}
