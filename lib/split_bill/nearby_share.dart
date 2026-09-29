import 'nearby_share_stub.dart' if (dart.library.html) 'nearby_share_web.dart';

Future<bool> shareSplitBillLink({
  required String title,
  required String text,
  required Uri uri,
}) =>
    shareSplitBillLinkImpl(title: title, text: text, uri: uri);
