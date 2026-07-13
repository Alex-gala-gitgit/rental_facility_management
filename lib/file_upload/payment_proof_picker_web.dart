import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image_data.dart';

Future<PickedImageData?> pickPaymentProof() async {
  final result = Completer<PickedImageData?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,application/pdf,.jpg,.jpeg,.png,.pdf'
    ..multiple = false;
  input.style.display = 'none';
  html.document.body?.append(input);

  late final StreamSubscription<html.Event> subscription;
  void cleanup() {
    subscription.cancel();
    input.remove();
  }

  subscription = input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!result.isCompleted) result.complete(null);
      cleanup();
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final value = reader.result;
      final bytes = value is ByteBuffer
          ? value.asUint8List()
          : value is Uint8List
              ? value
              : Uint8List(0);
      if (!result.isCompleted) {
        result.complete(PickedImageData(name: file.name, bytes: bytes));
      }
      cleanup();
    });
    reader.onError.listen((_) {
      if (!result.isCompleted) {
        result
            .completeError(StateError('The payment proof could not be read.'));
      }
      cleanup();
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return result.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}
