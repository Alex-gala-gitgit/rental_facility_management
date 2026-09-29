// ignore: deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:js_util' as js_util;

Future<bool> shareSplitBillLinkImpl({
  required String title,
  required String text,
  required Uri uri,
}) async {
  final navigator = html.window.navigator;
  if (js_util.hasProperty(navigator, 'share')) {
    try {
      final promise = js_util.callMethod<Object>(navigator, 'share', [
        js_util.jsify({'title': title, 'text': text, 'url': uri.toString()}),
      ]);
      await js_util.promiseToFuture<Object?>(promise);
      return true;
    } catch (_) {
      return false;
    }
  }
  await html.window.navigator.clipboard?.writeText('$text\n$uri');
  return false;
}
