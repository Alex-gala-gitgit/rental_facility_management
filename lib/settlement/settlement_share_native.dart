import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<bool> shareSettlementPdf(
        Uint8List bytes, String filename, bool refundIssued) =>
    Printing.sharePdf(bytes: bytes, filename: filename);
