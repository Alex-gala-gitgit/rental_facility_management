import 'package:flutter/services.dart';

Future<bool> shareSplitBillLinkImpl({
  required String title,
  required String text,
  required Uri uri,
}) async {
  await Clipboard.setData(ClipboardData(text: '$text\n$uri'));
  return false;
}
